float water_hash(vec2 cell) {
	vec3 seed = fract(cell.xyx * vec3(0.1031, 0.0973, 0.1099));
	seed += dot(seed, seed.yzx + 33.33);
	return fract((seed.x + seed.y) * seed.z);
}

float water_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 mix_point = fract(point);
	mix_point = mix_point * mix_point * (3.0 - 2.0 * mix_point);
	return mix(mix(water_hash(cell), water_hash(cell + vec2(1.0, 0.0)), mix_point.x),
		mix(water_hash(cell + vec2(0.0, 1.0)), water_hash(cell + vec2(1.0, 1.0)), mix_point.x), mix_point.y);
}

vec3 water_waves(vec2 pos, float clock, float fine) {
	vec2 a = vec2(1.12, 0.35);
	vec2 b = vec2(0.41, -1.57);
	vec2 c = vec2(2.66, 3.19);
	vec2 d = vec2(-4.37, 1.47);
	float phase_a = dot(pos, a) - clock * 1.24 + 0.44 * sin(dot(pos, vec2(0.12, -0.30)));
	float phase_b = dot(pos, b) + clock * 1.49;
	float phase_c = dot(pos, c) - clock * 2.09 + 0.64 * sin(phase_a * 0.27);
	float phase_d = dot(pos, d) + clock * 2.64;
	vec2 slope = a * cos(phase_a) * 0.026 + b * cos(phase_b) * 0.015;
	slope += (c * cos(phase_c) * 0.007 + d * cos(phase_d) * 0.004) * fine;
	float crest = 0.5 + 0.24 * sin(phase_a) + 0.14 * sin(phase_b) + 0.06 * sin(phase_c) * fine;
	return vec3(slope, crest);
}

vec3 water_tint(float depth, float fresnel, float crest) {
	vec3 shallows = vec3(.277,.394,.321);
	vec3 mids = vec3(.089,.216,.228);
	vec3 depths = vec3(.034,.113,.167);
	vec3 color = mix(shallows, mids, 1.0 - exp(-depth * 0.85));
	color = mix(color, depths, smoothstep(1.0, 8.5, depth) * 0.76);
	color = mix(color, vec3(.247,.343,.424), fresnel*.43);
	return color * (0.95 + crest * 0.10);
}

vec3 water_reflection(vec3 surface_normal,vec3 viewer,float fine,float fresnel) {
	vec3 reflected=reflect(-viewer,surface_normal);
	float height=clamp(reflected.y,0.0,1.0);
	vec3 sky=mix(vec3(.52,.69,.76),vec3(.18,.36,.55),1.0-exp(-height*3.2));
	vec2 layer=reflected.xz*(2.4/(height+.29));
	float cloud=water_noise(layer+vec2(3.0,9.0))*.66+water_noise(layer*2.11+17.3)*.34;
	return mix(sky,vec3(.66,.72,.74),smoothstep(.53,.81,cloud)*.43*fine)*fresnel;
}
