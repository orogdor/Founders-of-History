shader_type spatial;
render_mode cull_disabled, specular_disabled;

#include "res://scripts/surface_relief.gdshaderinc"
#include "res://scripts/detail_map_fog.gdshaderinc"
#include "res://scripts/detail_surface_sampling.gdshaderinc"

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
instance uniform vec4 undiscovered_edges = vec4(0.0);
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
	highp vec2 uv = overview ? ground_pos*0.042 : terrain_primary_uv(ground_pos);
	highp vec2 dx = dFdx(uv);
	highp vec2 dy = dFdy(uv);
	highp vec2 world_dx = dFdx(ground_pos);
	highp vec2 world_dy = dFdy(ground_pos);
	float range = length(VERTEX);
	float detail = overview ? 1.0-smoothstep(32.0,78.0,range) : 1.0-smoothstep(82.0,375.0,range);
	float sand = overview ? 1.0-smoothstep(0.8,4.2,elevation) : 1.0-smoothstep(0.12+shoreline,0.83+shoreline,elevation);
	float rock = smoothstep(0.15,0.65,1.0-up) * (1.0-sand);
	float snow = overview ? smoothstep(116.0,144.0,elevation)*up : 0.0;
	vec3 col = land.rgb;
	vec3 beach = vec3(0.49,0.37,0.23);
	if (!overview) {
		vec2 skew = TERRAIN_ROTATION*ground_pos;
		float patches = ground_noise(skew*0.057)*0.59 + ground_noise(ground_pos*0.246+6.4)*0.29
			+ ground_noise(skew*0.93+vec2(25.0,16.0))*0.12;
		float ground_cover = smoothstep(0.33,0.72,patches);
		vec3 damp = col*vec3(0.62,0.79,0.63);
		vec3 dry = col*vec3(0.96,0.87,0.68)+vec3(0.042,0.022,0.006);
		float grain = ground_noise((TERRAIN_SECONDARY_ROTATION*ground_pos)*1.8+16.5);
		float resolvable = 1.0-smoothstep(0.12,0.65,max(length(world_dx),length(world_dy)));
		col = mix(damp,dry,ground_cover)*(0.93+(grain-0.5)*0.20*resolvable);
		beach *= mix(0.80,1.14,patches)+(grain-0.5)*0.12*resolvable;
	}
	if (surface_textures_ready && detail > 0.0) {
		float patches = overview ? sin(ground_pos.x*0.12)*sin(ground_pos.y*0.085)
			: 2.0*ground_noise(ground_pos*0.12+vec2(10.0,19.0))-1.0;
		float soil = clamp(0.20+patches*0.29+rock*0.65,0.0,1.0);
		if (!overview) { soil = mix(soil,1.0,sand); }
		float forest = land.a*(1.0-soil);
		vec3 coverage = vec3(1.0-soil-forest,soil,forest);
		vec3 primary_heights = textureGrad(ground_height_maps,uv,dx,dy).rgb;
		vec3 soil_sample = textureGrad(soil_color,uv,dx,dy).rgb;
		vec3 grass_sample = textureGrad(grass_color,uv,dx,dy).rgb;
		vec3 forest_sample = textureGrad(forest_color,uv,dx,dy).rgb;
		vec3 heights = primary_heights;
		if (!overview && range < 164.0) {
			highp vec2 wide_uv = terrain_secondary_uv(ground_pos);
			highp vec2 wide_dx = TERRAIN_SECONDARY_ROTATION*world_dx*TERRAIN_SECONDARY_SCALE;
			highp vec2 wide_dy = TERRAIN_SECONDARY_ROTATION*world_dy*TERRAIN_SECONDARY_SCALE;
			float depth_mix = terrain_layer_mix(ground_pos)*(1.0-smoothstep(100.0,164.0,range));
			heights = mix(heights,textureGrad(ground_height_maps,wide_uv,wide_dx,wide_dy).rgb,depth_mix);
			soil_sample = mix(soil_sample,textureGrad(soil_color,wide_uv,wide_dx,wide_dy).rgb,depth_mix);
			grass_sample = mix(grass_sample,textureGrad(grass_color,wide_uv,wide_dx,wide_dy).rgb,depth_mix);
			forest_sample = mix(forest_sample,textureGrad(forest_color,wide_uv,wide_dx,wide_dy).rgb,depth_mix);
		}
		vec3 weights = height_blend_weights(coverage,heights);
		vec3 photo = grass_sample*weights.x+soil_sample*weights.y+forest_sample*weights.z;
		float strength = detail*(1.0-snow)*(overview ? 1.0-sand : 1.0);
		float relief = dot(heights,weights);
		float photo_weight = overview ? 0.30 : mix(0.22,0.63,1.0-smoothstep(9.0,38.0,range));
		col = mix(col,photo,strength*photo_weight);
		col *= 1.0+(relief-0.5)*strength*(overview ? 0.34 : photo_weight*0.43);
		if (!overview) {
			float grains = dot(soil_sample,vec3(0.31,0.57,0.12));
			beach *= mix(1.0,0.58+0.95*grains+0.24*relief,strength);
			if (range < 29.0) {
				float right = dot(textureGrad(ground_height_maps,uv+vec2(0.007,0.0),dx,dy).rgb,weights);
				float forward = dot(textureGrad(ground_height_maps,uv+vec2(0.0,0.007),dx,dy).rgb,weights);
				float primary_relief = dot(primary_heights,weights);
				vec2 slope = transpose(TERRAIN_ROTATION)*vec2(primary_relief-right,primary_relief-forward);
				NORMAL_MAP = normalize(vec3(slope*0.82,1.0))*0.5+0.5;
				NORMAL_MAP_DEPTH = 0.72*(1.0-smoothstep(7.0,29.0,range));
			}
		}
	}
	col = mix(col,vec3(0.25,0.24,0.22),rock*0.52);
	col = mix(col,overview ? vec3(0.58,0.51,0.37) : beach,sand*(overview ? 0.72 : 0.92));
	ALBEDO = mix(col,vec3(0.84,0.86,0.90),snow);
	if (!overview && dot(undiscovered_edges,vec4(1.0)) > 0.0) {
		float mist = detail_cloud_edge(tile_pos,ground_pos,undiscovered_edges);
		if (mist > 0.0) {
			vec2 projection = detail_cloud_projection(ground_pos,mat3(INV_VIEW_MATRIX)*VERTEX,CAMERA_POSITION_WORLD.y);
			ALBEDO *= 1.0-mist;
			EMISSION = detail_cloud_color(projection)*mist;
		}
	}
	ROUGHNESS = 1.0;
}
