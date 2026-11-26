float cloud_hash(vec2 p) {
	p = fract(p * vec2(0.1031,0.1030));
	p += dot(p,p.yx+33.33);
	return fract((p.x+p.y)*p.x);
}

float cloud_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(cloud_hash(cell),cloud_hash(cell+vec2(1.0,0.0)),f.x),
		mix(cloud_hash(cell+vec2(0.0,1.0)),cloud_hash(cell+vec2(1.0)),f.x),f.y);
}

vec3 detail_cloud_color(vec2 position) {
	float drift = cloud_noise(position*0.012)*0.73 + cloud_noise(position*0.031+19.7)*0.27;
	return mix(vec3(0.30,0.36,0.35),vec3(0.65,0.69,0.63),smoothstep(0.12,0.87,drift));
}

float detail_cloud_edge(vec2 local, vec2 position, vec4 undiscovered) {
	vec4 distances = vec4(112.5+local.x,112.5-local.x,97.5+local.y,97.5-local.y);
	distances += (1.0-undiscovered)*900.0;
	float edge = min(min(distances.x,distances.y),min(distances.z,distances.w));
	if (edge >= 42.0) { return 0.0; }
	float width = mix(22.0,42.0,cloud_noise(position*0.047+7.0));
	return 1.0-smoothstep(0.6,width,edge);
}

vec2 detail_cloud_projection(vec2 position, vec3 from_camera, float camera_height) {
	float surface_height = camera_height+from_camera.y;
	if (from_camera.y > -0.12) { return position; }
	return position+from_camera.xz*clamp((-20.0-surface_height)/from_camera.y,0.0,1.8);
}
