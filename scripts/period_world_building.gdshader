shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/painted_relief.gdshaderinc"

uniform sampler2D walls : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D roofs : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D accents : source_color, filter_linear_mipmap, repeat_enable;
uniform float paint_strength : hint_range(0.0, 1.0) = 0.66;

varying vec2 grain_uv;
varying flat float grain_variant;
varying flat float trim;

void vertex() {
	vec3 sides = abs(NORMAL);
	grain_uv = (sides.y > max(sides.x, sides.z) ? VERTEX.xz
		: vec2(sides.x > sides.z ? VERTEX.z : VERTEX.x, VERTEX.y)) * 0.71;
	grain_variant = round(INSTANCE_CUSTOM.x * 7.0);
	trim = UV.x;
}

void fragment() {
	vec4 painted;
	if (trim < 0.5) {
		painted = painted_atlas_sample(walls, grain_uv, grain_variant);
	} else if (trim < 1.5) {
		painted = painted_atlas_sample(roofs, grain_uv, grain_variant);
	} else {
		painted = painted_atlas_sample(accents, grain_uv, grain_variant);
	}
	ALBEDO = mix(COLOR.rgb, painted.rgb, paint_strength);
	NORMAL = painted_relief(VERTEX, NORMAL, painted.a, 0.0011);
	ROUGHNESS = 0.92;
}
