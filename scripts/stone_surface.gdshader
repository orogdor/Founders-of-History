shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D stone_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
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

vec3 stone_sample(vec2 at) {
	vec2 dx = dFdx(at);
	vec2 dy = dFdy(at);
	if (atlas_tile < 0) {
		return textureGrad(stone_texture, at, dx, dy).rgb;
	}
	// The photographs have their own padded borders. Reflection keeps joints
	// continuous at the edge without cross-fading unrelated stones.
	vec2 mirrored = abs(fract(at * 0.5 + 0.5) * 2.0 - 1.0);
	vec2 direction = mix(vec2(1.0), vec2(-1.0), step(vec2(1.0), mod(at, 2.0)));
	vec2 texel = vec2(1.0) / vec2(textureSize(stone_texture, 0));
	vec2 tile_size = vec2(0.2, 1.0);
	vec2 padding = tile_size * (1.0 / 66.0);
	vec2 area = tile_size - 2.0 * padding - texel;
	vec2 start = vec2(float(atlas_tile) * tile_size.x, 0.0) + padding + texel * 0.5;
	return textureGrad(stone_texture, start + mirrored * area, dx * direction * area, dy * direction * area).rgb;
}

void fragment() {
	vec3 color;
	if (mesh_uv) {
		color = stone_sample(UV * tiling);
	} else {
		// World-space proportions prevent imported walls from stretching their
		// texture when a wall run grows, turns or meets the next segment.
		vec3 p = stone_position * (0.64 * tiling);
		vec3 weights = pow(abs(normalize(stone_normal)), vec3(7.0));
		weights /= max(0.00001, dot(weights, vec3(1.0)));
		color = stone_sample(vec2(p.z, -p.y)) * weights.x;
		color += stone_sample(p.xz) * weights.y;
		color += stone_sample(vec2(p.x, -p.y)) * weights.z;
	}
	float grain = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float age = sin(stone_position.x * 0.76 + stone_position.y * 0.71)
	          * sin(stone_position.z * 0.88 - stone_position.y * 0.51);
	ALBEDO = color * stone_tint.rgb * (0.97 + age * 0.075);
	ROUGHNESS = 0.95;
	SPECULAR = 0.16;
	if (relief_amount > 0.0) {
		float close_relief = 1.0 - smoothstep(16.0, 48.0, length(VERTEX));
		NORMAL = material_relief_normal(VERTEX, NORMAL, grain * relief_amount * close_relief);
	}
}

