shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never;

#include "res://scripts/water_surface.gdshaderinc"

uniform vec2 phase_origin = vec2(0.0);
varying vec2 water_position;

void vertex() {
	water_position = VERTEX.xz + phase_origin;
}

void fragment() {
	float edge = clamp(COLOR.r, 0.0, 1.0);
	float depth = mix(1.8, 0.025, edge * edge);
	vec3 wave = water_waves(water_position * 1.32, TIME * 1.13, 0.34);
	vec3 world_normal=normalize(vec3(-wave.x*.61,1.0,-wave.y*.61));
	vec3 normal=mat3(VIEW_MATRIX)*world_normal;
	float fresnel = pow(1.0 - clamp(dot(normal, VIEW), 0.0, 1.0), 4.0);
	float rim = smoothstep(0.73, 0.98, edge) * smoothstep(0.67, 0.95, wave.z);
	vec3 color=water_tint(depth,fresnel*.73,wave.z);
	color+=water_reflection(world_normal,mat3(INV_VIEW_MATRIX)*VIEW,.53,fresnel)*.14;
	ALBEDO=mix(color,vec3(.54,.59,.48),rim*.23);
	NORMAL = normal;
	ROUGHNESS = mix(0.31, 0.52, edge);
	SPECULAR = 0.27;
	ALPHA = COLOR.a * mix(0.96, 0.51, edge * edge);
}
