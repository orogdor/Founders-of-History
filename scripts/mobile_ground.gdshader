shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://scripts/surface_relief.gdshaderinc"

uniform bool overview = false;
uniform bool surface_textures_ready = false;
uniform sampler2D grass_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D forest_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_height_maps : filter_linear_mipmap, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.4,0.5,0.3,1.0);
uniform float forest_factor = 0.0;
instance uniform vec2 detail_uv_offset = vec2(0.0);
instance uniform bool blend_neighbours = false;
instance uniform vec4 ground_w : source_color = vec4(0.0);
instance uniform vec4 ground_e : source_color = vec4(0.0);
instance uniform vec4 ground_n : source_color = vec4(0.0);
instance uniform vec4 ground_s : source_color = vec4(0.0);
instance uniform vec4 ground_nw : source_color = vec4(0.0);
instance uniform vec4 ground_ne : source_color = vec4(0.0);
instance uniform vec4 ground_sw : source_color = vec4(0.0);
instance uniform vec4 ground_se : source_color = vec4(0.0);
varying highp vec2 ground_pos;
varying vec2 tile_pos;
varying float elevation;
varying float shoreline;
varying float up;

void vertex() {
	ground_pos = overview ? VERTEX.xz * 25.0 : UV + detail_uv_offset;
	tile_pos = UV;
	elevation = overview ? UV.x : UV2.x;
	shoreline = UV2.y;
	up = abs(NORMAL.y);
}

float ground_hash(vec2 p) {
	p = fract(p * vec2(0.1031,0.1030));
	p += dot(p,p.yx+33.33);
	return fract((p.x+p.y)*p.x);
}

float ground_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ground_hash(cell),ground_hash(cell+vec2(1.0,0.0)),f.x),
		mix(ground_hash(cell+vec2(0.0,1.0)),ground_hash(cell+vec2(1.0)),f.x),f.y);
}

void fragment() {
	vec4 land = overview ? COLOR : vec4(base_color.rgb,forest_factor);
	if (blend_neighbours) {
		vec2 amount = clamp(abs(tile_pos)/vec2(225.0,195.0),vec2(0.0),vec2(0.5));
		vec4 horizontal = tile_pos.x < 0.0 ? ground_w : ground_e;
		vec4 vertical = tile_pos.y < 0.0 ? ground_n : ground_s;
		vec4 diagonal = tile_pos.x < 0.0 ? (tile_pos.y < 0.0 ? ground_nw : ground_sw) :
			(tile_pos.y < 0.0 ? ground_ne : ground_se);
		land = mix(mix(land,horizontal,amount.x),mix(vertical,diagonal,amount.x),amount.y);
	}
	highp vec2 uv = ground_pos * (overview ? 0.042 : 0.55);
	if (!overview) {
		uv = mat2(vec2(0.85,0.53),vec2(-0.53,0.85))*uv;
		uv += vec2(ground_noise(ground_pos*0.18),ground_noise(ground_pos*0.18+vec2(39.0,13.0)))*0.84;
	}
	highp vec2 dx = dFdx(uv);
	highp vec2 dy = dFdy(uv);
	float range = length(VERTEX);
	float detail = overview ? 1.0-smoothstep(32.0,78.0,range) : 1.0-smoothstep(82.0,375.0,range);
	float sand = overview ? 1.0-smoothstep(0.8,4.2,elevation) : 1.0-smoothstep(0.12+shoreline,0.83+shoreline,elevation);
	float rock = smoothstep(0.15,0.65,1.0-up) * (1.0-sand);
	float snow = overview ? smoothstep(116.0,144.0,elevation)*up : 0.0;
	vec3 col = land.rgb;
	vec3 beach = vec3(0.49,0.37,0.23);
	if (!overview) {
		float patches = ground_noise(ground_pos*0.052)*0.72 + ground_noise(ground_pos*0.158+6.4)*0.28;
		col = mix(col*vec3(0.67,0.84,0.66),col*vec3(1.11,0.99,0.78),smoothstep(0.28,0.73,patches));
		beach *= mix(0.84,1.19,patches);
	}
	if (surface_textures_ready && detail > 0.0) {
		float patches = overview ? sin(ground_pos.x*0.12)*sin(ground_pos.y*0.085)
			: 2.0*ground_noise(ground_pos*0.12+vec2(10.0,19.0))-1.0;
		float soil = clamp(0.20+patches*0.29+rock*0.65,0.0,1.0);
		if (!overview) { soil = mix(soil,1.0,sand); }
		float forest = land.a*(1.0-soil);
		vec3 coverage = vec3(1.0-soil-forest,soil,forest);
		vec3 heights = textureGrad(ground_height_maps,uv,dx,dy).rgb;
		vec3 weights = height_blend_weights(coverage,heights);
		vec3 soil_sample = textureGrad(soil_color,uv,dx,dy).rgb;
		vec3 photo = textureGrad(grass_color,uv,dx,dy).rgb*weights.x
			+soil_sample*weights.y+textureGrad(forest_color,uv,dx,dy).rgb*weights.z;
		float strength = detail*(1.0-snow)*(overview ? 1.0-sand : 1.0);
		float relief = dot(heights,weights);
		col = mix(col,photo,strength*(overview ? 0.30 : 0.80));
		col *= 1.0+(relief-0.5)*strength*0.34;
		if (!overview) {
			float grains = dot(soil_sample,vec3(0.31,0.57,0.12));
			beach *= mix(1.0,0.58+0.95*grains+0.24*relief,strength);
			if (range < 29.0) {
				float right = dot(textureGrad(ground_height_maps,uv+vec2(0.007,0.0),dx,dy).rgb,weights);
				float forward = dot(textureGrad(ground_height_maps,uv+vec2(0.0,0.007),dx,dy).rgb,weights);
				vec2 slope = mat2(vec2(0.85,-0.53),vec2(0.53,0.85))*vec2(relief-right,relief-forward);
				NORMAL_MAP = normalize(vec3(slope*0.82,1.0))*0.5+0.5;
				NORMAL_MAP_DEPTH = 0.72*(1.0-smoothstep(7.0,29.0,range));
			}
		}
	}
	col = mix(col,vec3(0.25,0.24,0.22),rock*0.52);
	col = mix(col,overview ? vec3(0.58,0.51,0.37) : beach,sand*(overview ? 0.72 : 0.92));
	ALBEDO = mix(col,vec3(0.84,0.86,0.90),snow);
	ROUGHNESS = 1.0;
}
