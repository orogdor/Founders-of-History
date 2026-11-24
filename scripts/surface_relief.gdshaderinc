vec2 relief_direction(vec3 view_dir, vec3 tangent, vec3 binormal, vec3 normal) {
	vec2 facing = vec2(dot(view_dir, tangent), dot(view_dir, binormal));
	return facing / max(0.35, dot(view_dir, normal));
}
