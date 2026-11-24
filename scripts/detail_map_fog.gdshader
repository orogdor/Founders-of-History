shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

#include "res://scripts/detail_map_fog.gdshaderinc"

uniform vec2 map_offset;
varying vec2 map_position;

void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz + map_offset;
}

void fragment() {
	ALBEDO = detail_cloud_color(map_position);
}
