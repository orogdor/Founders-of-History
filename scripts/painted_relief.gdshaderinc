// Work in view space. The footprint grows correctly at grazing angles and
// uses the same height as the painted color without another texture lookup.
vec3 painted_relief(vec3 position, vec3 normal, float surface_height, float amplitude) {
	vec3 dx = dFdx(position);
	vec3 dy = dFdy(position);
	vec3 across_x = cross(dy, normal);
	vec3 across_y = cross(normal, dx);
	float area = dot(dx, across_x);
	if (abs(area) < 0.0000001) {
		return normal;
	}
	vec3 gradient = (across_x * dFdx(surface_height) + across_y * dFdy(surface_height)) * sign(area);
	return normalize(abs(area) * normal - gradient * amplitude);
}

vec4 painted_atlas_sample(sampler2D atlas, vec2 uv, float index) {
	vec2 tile = vec2(mod(index, 4.0), floor(index / 4.0));
	vec2 sheet_size = vec2(1664.0, 832.0);
	vec2 sample_uv = (tile * 416.0 + 16.0 + fract(uv) * 384.0) / sheet_size;
	vec2 scale = 384.0 / sheet_size;
	return textureGrad(atlas, sample_uv, dFdx(uv) * scale, dFdy(uv) * scale);
}

float painted_region_variant(vec2 cell) {
	vec2 f = fract(cell * vec2(0.1031, 0.1537));
	f += dot(f, f.yx + 19.19);
	return floor(fract(f.x * f.y) * 8.0);
}

vec4 painted_regions(sampler2D atlas, vec2 uv, vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = smoothstep(vec2(0.23), vec2(0.77), fract(point));
	float a = painted_region_variant(cell);
	float b = painted_region_variant(cell + vec2(1.0, 0.0));
	float c = painted_region_variant(cell + vec2(0.0, 1.0));
	float d = painted_region_variant(cell + vec2(1.0, 1.0));
	vec2 turn = vec2(-uv.y, uv.x) * 0.81 + vec2(0.41, 0.12);
	bool even = mod(cell.x + cell.y, 2.0) < 0.5;
	vec2 first = even ? uv : turn;
	vec2 second = even ? turn : uv;
	vec4 top = mix(painted_atlas_sample(atlas, first, a), painted_atlas_sample(atlas, second, b), blend.x);
	vec4 bottom = mix(painted_atlas_sample(atlas, second, c), painted_atlas_sample(atlas, first, d), blend.x);
	return mix(top, bottom, blend.y);
}
