// Surface gradient in view space. This also works for meshes without tangents.
vec3 material_relief_normal(vec3 point, vec3 normal, float height) {
	vec3 dpdx = dFdx(point);
	vec3 dpdy = dFdy(point);
	vec3 along_x = cross(dpdy, normal);
	vec3 along_y = cross(normal, dpdx);
	float determinant = dot(dpdx, along_x);
	vec3 gradient = dFdx(height) * along_x + dFdy(height) * along_y;
	return normalize(max(abs(determinant), 0.000001) * normal - sign(determinant) * gradient);
}
