shader_type spatial;
render_mode cull_disabled;

#include "res://scripts/water_surface.gdshaderinc"

varying float land_height;
varying vec2 map_position;

void vertex() {
	land_height = COLOR.r * 160.0 - 80.0;
	map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 25.0;
}

void fragment() {
	float depth = 0.72 - land_height;
	if (depth <= 0.0) discard;
	vec3 wave = water_waves(map_position * 0.33, TIME * 0.76, 0.12);
	vec3 normal = normalize(mat3(VIEW_MATRIX) * vec3(-wave.x * 0.51, 1.0, -wave.y * 0.51));
	float fresnel = pow(1.0 - clamp(dot(normal, VIEW), 0.0, 1.0), 4.0);
	float shoal = 1.0 - smoothstep(0.07, 1.7, depth);
	float fragments = water_noise(map_position * 0.088 + vec2(0.24, 0.57) * TIME * 0.07);
	float foam = shoal * smoothstep(0.67, 0.89, fragments) * smoothstep(0.02, 0.18, depth);
	ALBEDO = mix(water_tint(depth * 0.31, fresnel * 0.54, wave.z), vec3(0.53, 0.64, 0.63), foam * 0.40);
	NORMAL = normal;
	ROUGHNESS = mix(0.32, 0.50, shoal);
	SPECULAR = 0.25;
}
