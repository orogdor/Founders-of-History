vec2 relief_direction(vec3 view_dir, vec3 tangent, vec3 binormal, vec3 normal) {
	vec2 facing = vec2(dot(view_dir, tangent), dot(view_dir, binormal));
	return facing / max(0.35, dot(view_dir, normal));
}

vec3 height_blend_weights(vec3 coverage, vec3 heights) {
	vec3 levels = coverage + heights * 0.42;
	float top = max(levels.x, max(levels.y, levels.z)) - 0.28;
	vec3 weights = max(levels - vec3(top), vec3(0.0)) * coverage;
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}
