shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D stone_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_height_map = false;
uniform vec4 stone_tint : source_color = vec4(1.0);
uniform int atlas_tile = -1;
uniform float tiling = 1.0;
uniform bool mesh_uv = false;
uniform float relief_amount = 0.0;

varying vec3 stone_position;
varying vec3 stone_normal;

void vertex() {
	stone_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	stone_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec4 stone_photo(vec2 point, vec2 start, vec2 area, vec2 dx, vec2 dy, bool relief) {
	vec2 uv = start + point * area;
	vec3 color = textureGrad(stone_texture, uv, dx * area, dy * area).rgb;
	float depth = relief ? textureGrad(stone_height, uv, dx * area, dy * area).r : dot(color, vec3(0.2126, 0.7152, 0.0722));
	return vec4(color, depth);
}

vec4 stone_sample(vec2 at, bool relief) {
	vec2 dx = dFdx(at);
	vec2 dy = dFdy(at);
	if (atlas_tile < 0) {
		return stone_photo(at, vec2(0.0), vec2(1.0), dx, dy, relief);
	}
	vec2 texel = vec2(1.0) / vec2(textureSize(stone_texture, 0));
	vec2 tile_size = vec2(0.2, 1.0);
	vec2 padding = tile_size * (1.0 / 66.0);
	vec2 area = tile_size - 2.0 * padding - texel;
	vec2 start = vec2(float(atlas_tile) * tile_size.x, 0.0) + padding + texel * 0.5;
	vec2 uv = fract(at);
	vec2 shifted = fract(at + vec2(0.423, 0.617));
	vec2 edge = 1.0 - smoothstep(vec2(0.018), vec2(0.14), min(uv, 1.0 - uv));
	// Offset only the strip crossing each join. The photo keeps its original
	// orientation and the interior is sampled once.
	vec4 color = stone_photo(uv, start, area, dx, dy, relief);
	if (edge.x > 0.0) {
		color = mix(color, stone_photo(vec2(shifted.x, uv.y), start, area, dx, dy, relief), edge.x);
	}
	if (edge.y > 0.0) {
		vec4 across = stone_photo(vec2(uv.x, shifted.y), start, area, dx, dy, relief);
		if (edge.x > 0.0) {
			across = mix(across, stone_photo(shifted, start, area, dx, dy, relief), edge.x);
		}
		color = mix(color, across, edge.y);
	}
	return color;
}

void fragment() {
	vec4 stone;
	float distance_to_camera = length(VERTEX);
	bool relief = has_height_map && distance_to_camera < 48.0;
	if (mesh_uv) {
		stone = stone_sample(UV * tiling, relief);
	} else {
		// World-space proportions prevent imported walls from stretching their
		// texture when a wall run grows, turns or meets the next segment.
		vec3 p = stone_position * (0.64 * tiling);
		vec3 weights = pow(abs(normalize(stone_normal)), vec3(7.0));
		weights /= max(0.00001, dot(weights, vec3(1.0)));
		stone = stone_sample(vec2(p.z, -p.y), relief) * weights.x;
		stone += stone_sample(p.xz, relief) * weights.y;
		stone += stone_sample(vec2(p.x, -p.y), relief) * weights.z;
	}
	float age = sin(stone_position.x * 0.76 + stone_position.y * 0.71)
	          * sin(stone_position.z * 0.88 - stone_position.y * 0.51);
	ALBEDO = stone.rgb * stone_tint.rgb * (0.97 + age * 0.075);
	ROUGHNESS = 0.95;
	SPECULAR = 0.16;
	if (relief_amount > 0.0) {
		float close_relief = 1.0 - smoothstep(16.0, 46.0, distance_to_camera);
		NORMAL = material_relief_normal(VERTEX, NORMAL, stone.a * relief_amount * close_relief);
	}
}

