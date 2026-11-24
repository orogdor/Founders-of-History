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
varying float up;

void vertex() {
	ground_pos = overview ? VERTEX.xz * 25.0 : UV + detail_uv_offset;
	tile_pos = UV;
	elevation = overview ? UV.x : UV2.x;
	up = abs(NORMAL.y);
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
	highp vec2 uv = ground_pos * (overview ? 0.042 : 0.45);
	highp vec2 dx = dFdx(uv);
	highp vec2 dy = dFdy(uv);
	float range = length(VERTEX);
	float detail = overview ? 1.0-smoothstep(32.0,78.0,range) : 1.0-smoothstep(70.0,235.0,range);
	float sand = overview ? 1.0-smoothstep(0.8,4.2,elevation) : 1.0-smoothstep(0.35,1.2,elevation);
	float rock = smoothstep(0.15,0.65,1.0-up) * (1.0-sand);
	float snow = overview ? smoothstep(116.0,144.0,elevation)*up : 0.0;
	vec3 col = land.rgb;
	if (surface_textures_ready && detail > 0.0) {
		highp float patches = sin(ground_pos.x*0.12)*sin(ground_pos.y*0.085);
		float soil = clamp(0.20+patches*0.29+rock*0.65,0.0,1.0);
		float forest = land.a*(1.0-soil);
		vec3 coverage = vec3(1.0-soil-forest,soil,forest);
		vec3 heights = textureGrad(ground_height_maps,uv,dx,dy).rgb;
		vec3 weights = height_blend_weights(coverage,heights);
		vec3 photo = textureGrad(grass_color,uv,dx,dy).rgb*weights.x
			+textureGrad(soil_color,uv,dx,dy).rgb*weights.y
			+textureGrad(forest_color,uv,dx,dy).rgb*weights.z;
		float strength = detail*(1.0-sand)*(1.0-snow);
		col = mix(col,photo,strength*(overview ? 0.30 : 0.70));
		col *= 1.0+(dot(heights,weights)-0.5)*strength*0.30;
	}
	col = mix(col,vec3(0.25,0.24,0.22),rock*0.52);
	col = mix(col,vec3(0.58,0.51,0.37),sand*0.72);
	ALBEDO = mix(col,vec3(0.84,0.86,0.90),snow);
	ROUGHNESS = 1.0;
}
