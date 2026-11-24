shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D seen_linear : filter_linear, repeat_disable;

void fragment() {
	float opacity = smoothstep(0.30,0.70,texture(seen_linear,UV).a);
	if (opacity < 0.01) discard;
	ALBEDO = vec3(0.79,0.71,0.56);
	ALPHA = opacity;
}
