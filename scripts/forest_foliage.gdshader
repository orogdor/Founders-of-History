shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D foliage_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 canopy_tint = vec3(0.72, 0.81, 0.64);
uniform float alpha_cut = 0.5;
varying float crown_height;
varying float tree_variation;

void vertex() {
	vec2 origin = mod(MODEL_MATRIX[3].xz + vec2(112.5, 97.5), vec2(225.0, 195.0));
	tree_variation = fract(sin(dot(floor(origin*2.0),vec2(7.42,17.03)) + 19.31) * 24317.731);
	crown_height = smoothstep(1.7, 15.5, VERTEX.y);
	float sway = sin(TIME * 1.18 + dot(origin, vec2(0.12, 0.22)) + VERTEX.y * 0.17);
	float fine = sin(TIME * 2.2 + (VERTEX.x + VERTEX.z) * 2.8 + tree_variation * 3.1);
	VERTEX.xz += vec2(sway * 0.09 + fine * 0.024, sway * 0.043) * crown_height;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.24, 0.0));
}

void fragment() {
	vec4 leaf = texture(foliage_atlas, UV);
	vec3 spring = vec3(.87,1.00,.79);
	vec3 summer = vec3(1.10,.96,.88);
	vec3 seasonal = mix(spring, summer, tree_variation);
	vec3 color = leaf.rgb * canopy_tint * seasonal;
	color *= mix(0.88, 1.12, crown_height) * mix(0.91, 1.08, tree_variation);
	float pigment=dot(color,vec3(.29,.61,.10));
	color=mix(color,pigment*vec3(.96,.94,.80),.13);
	ALBEDO = color;
	BACKLIGHT = color * vec3(0.24, 0.39, 0.10);
	ROUGHNESS = 0.91;
	SPECULAR = 0.13;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
