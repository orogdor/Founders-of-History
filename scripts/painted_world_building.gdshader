shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/painted_relief.gdshaderinc"

uniform sampler2D painted_grain : source_color, filter_linear_mipmap, repeat_enable;
instance uniform float painted_building_variant = 0.0;
varying vec2 grain_uv;
varying flat float grain_variant;

void vertex() {
	vec3 facing = abs(NORMAL);
	grain_uv = (facing.y > max(facing.x, facing.z) ? VERTEX.xz
		: vec2(facing.x > facing.z ? VERTEX.z : VERTEX.x, VERTEX.y)) * 0.65;
	grain_variant = mod(round(INSTANCE_CUSTOM.x * 7.0) + painted_building_variant, 8.0);
}

void fragment() {
	vec4 paint = painted_atlas_sample(painted_grain, grain_uv, grain_variant);
	float brush = dot(paint.rgb, vec3(0.30, 0.59, 0.11));
	ALBEDO = COLOR.rgb * (0.94 + 0.22 * brush + (paint.a - 0.5) * 0.05);
	NORMAL = painted_relief(VERTEX, NORMAL, paint.a, 0.0015);
	ROUGHNESS = 0.95;
}
