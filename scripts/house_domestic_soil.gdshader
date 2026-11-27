shader_type spatial;
render_mode cull_disabled, depth_draw_never;

uniform sampler2D earth : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 soil : source_color;

void fragment() {
	float coarse = texture(earth, UV * 0.8).r;
	float grit = texture(earth, UV * 2.7).r;
	float shading = 0.80 + 0.59 * coarse + 0.27 * grit;
	ALBEDO = soil.rgb * shading * mix(0.91, 1.10, COLOR.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.14;
	ALPHA = COLOR.a;
}
