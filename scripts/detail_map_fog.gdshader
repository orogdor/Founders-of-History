shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec2 map_offset;
varying vec2 map_position;

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

void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xz + map_offset;
}

void fragment() {
	float drift = cloud_noise(map_position*0.012)*0.73 + cloud_noise(map_position*0.031+19.7)*0.27;
	ALBEDO = mix(vec3(0.30,0.36,0.35),vec3(0.65,0.69,0.63),smoothstep(0.12,0.87,drift));
}
