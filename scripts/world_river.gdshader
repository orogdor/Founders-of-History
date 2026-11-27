shader_type spatial;
render_mode cull_disabled, depth_draw_never;

#include "res://scripts/water_surface.gdshaderinc"

varying vec2 river_world;

void vertex() {
	river_world=VERTEX.xz*25.0;
}

void fragment() {
	float edge = abs(UV.x * 2.0 - 1.0);
	float shallow=pow(edge,2.35);
	float depth=mix(2.3,.04,shallow);
	vec3 ripple=water_waves(river_world*.36,TIME*.77,.13);
	vec3 normal=normalize(mat3(VIEW_MATRIX)*vec3(-ripple.x*.44,1.0,-ripple.y*.44));
	float fresnel=pow(1.0-clamp(dot(normal,VIEW),0.0,1.0),4.0);
	ALBEDO=water_tint(depth,fresnel*.57,ripple.z);
	NORMAL=normal;
	ALPHA=COLOR.a*(.96-.39*shallow);
	ROUGHNESS=mix(.33,.58,shallow);
	SPECULAR=.24;
}
