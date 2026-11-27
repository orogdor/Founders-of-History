shader_type spatial;
render_mode diffuse_burley;

varying float tip_tone;
varying vec3 stem_tint;

void vertex() {
	tip_tone = smoothstep(0.0, 0.30, VERTEX.y);
	stem_tint = COLOR.rgb;
}

void fragment() {
	ALBEDO = stem_tint * mix(0.72, 1.10, tip_tone);
	NORMAL = normalize(mix(NORMAL, normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz), 0.78));
	SPECULAR = 0.14;
	ROUGHNESS = 0.97;
}
