shader_type spatial;
render_mode cull_disabled;

uniform sampler2D reed_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D stone_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D clay_atlas : source_color, filter_linear_mipmap, repeat_disable;

float surface_grain(sampler2D atlas, vec2 uv, vec2 dx, vec2 dy, float tile) {
	vec2 page = vec2(512.0) / vec2(2640.0, 528.0);
	vec2 at = (fract(uv) * 512.0 + vec2(8.0 + tile * 528.0, 8.0)) / vec2(2640.0, 528.0);
	vec3 sample_color = textureGrad(atlas, at, dx * page, dy * page).rgb;
	return dot(sample_color, vec3(0.23, 0.69, 0.08));
}

void fragment() {
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	float courses = UV.y * (3.0 / 2.3);
	float band_visibility = 1.0 - smoothstep(0.18, 0.48, fwidth(courses));
	float finish = UV2.x;
	float tone = 1.0;
	if (finish > 0.5 && finish < 1.5) {
		vec2 scale = vec2(1.3, 0.66);
		float grain = surface_grain(reed_atlas, UV * scale, dx * scale, dy * scale, 2.0);
		tone += (grain - 0.28) * 0.22 - cos(TAU * courses) * 0.075 * band_visibility;
	} else if (finish > 1.5 && finish < 2.5) {
		float grain = surface_grain(stone_atlas, UV * 0.65, dx * 0.65, dy * 0.65, 0.0);
		tone += (grain - 0.30) * 0.30;
	} else if (finish > 2.5) {
		float grain = surface_grain(clay_atlas, UV, dx, dy, 1.0);
		tone += (grain - 0.28) * 0.20;
	}
	ALBEDO = COLOR.rgb * tone;
	ROUGHNESS = 0.92;
}
