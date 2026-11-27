shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D stone_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 weights = pow(abs(normalize(local_normal)), vec3(5.0));
	weights /= max(0.001, dot(weights, vec3(1.0)));
	vec3 map = local_position * vec3(1.63, 1.16, 1.58);
	vec3 stone = texture(stone_detail, map.zy + vec2(0.17, 0.39)).rgb * weights.x
	           + texture(stone_detail, map.xz + vec2(0.36, 0.15)).rgb * weights.y
	           + texture(stone_detail, map.xy + vec2(0.75, 0.62)).rgb * weights.z;
	float grain = dot(stone, vec3(0.25, 0.58, 0.17));
	float rock_detail = 1.0 - smoothstep(12.0, 29.0, length(VERTEX));
	float strata = 0.5 + 0.5 * sin(local_position.y * 21.0 + local_position.x * 3.3
	             + sin(local_position.z * 9.4) * 0.44);
	float layer = smoothstep(0.72, 0.96, strata) * smoothstep(0.12, 0.55, grain);
	float underside = smoothstep(-0.08, 0.31, local_position.y);
	vec3 color = COLOR.rgb * mix(vec3(0.32), stone * 1.38, 0.69);
	color *= (0.74 + 0.26 * underside) * (1.0 + layer * rock_detail * 0.18);
	ALBEDO = color;
	ROUGHNESS = clamp(0.94 - grain * 0.18, 0.77, 0.97);
	SPECULAR = 0.13;
	NORMAL = material_relief_normal(VERTEX, NORMAL, rock_detail * (grain * 0.026 + layer * 0.003));
}
