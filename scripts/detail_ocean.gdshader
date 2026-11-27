shader_type spatial;
render_mode cull_disabled, depth_draw_never;

#include "res://scripts/water_surface.gdshaderinc"

uniform sampler2D ground_heights : filter_linear, repeat_disable;
uniform float grid_size = 9.0;
uniform vec2 phase_origin = vec2(0.0);
varying vec2 water_position;

void vertex() {
	water_position = VERTEX.xz + phase_origin;
}

void fragment() {
	vec2 height_uv = UV * ((grid_size - 1.0) / grid_size) + vec2(0.5 / grid_size);
	float depth = -texture(ground_heights, height_uv).r;
	if (depth <= 0.0) discard;
	float distance_from_camera = length(VERTEX);
	float fine = 1.0 - smoothstep(38.0, 240.0, distance_from_camera);
	vec3 wave = water_waves(water_position, TIME, fine);
	vec3 world_normal=normalize(vec3(-wave.x,1.0,-wave.y));
	vec3 normal=mat3(VIEW_MATRIX)*world_normal;
	float fresnel = pow(1.0 - clamp(dot(normal, VIEW), 0.0, 1.0), 4.0);
	float foam = 0.0;
	if (depth < 0.52) {
		float wash = max(0.0, depth - 0.045 - 0.10 * wave.z);
		float crest = 1.0 - smoothstep(0.028, 0.13, wash);
		float breakup = water_noise(water_position * 0.54 + vec2(TIME * 0.10, 0.0));
		foam = crest * smoothstep(0.47, 0.76, breakup + wave.z * 0.15) * smoothstep(0.026, 0.092, depth);
	}
	vec3 color = water_tint(depth, fresnel, wave.z);
	color+=water_reflection(world_normal,mat3(INV_VIEW_MATRIX)*VIEW,fine,fresnel)*.18;
	ALBEDO = mix(color, vec3(0.68, 0.73, 0.65), foam * 0.55);
	NORMAL = normal;
	ROUGHNESS = mix(0.32, 0.64, foam);
	SPECULAR = 0.32;
	ALPHA = mix(0.53, 0.96, smoothstep(0.04, 2.10, depth)) * smoothstep(0.0, 0.095, depth);
	ALPHA = max(ALPHA, foam * 0.32);
}
