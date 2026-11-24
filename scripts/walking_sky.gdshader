shader_type sky;

uniform vec4 horizon : source_color = vec4(0.66,0.78,0.84,1.0);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform vec3 sun_direction = vec3(-0.3,0.7,0.3);

float sky_hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float sky_noise(vec2 p) {
	vec2 cell = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sky_hash(cell), sky_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(sky_hash(cell + vec2(0.0, 1.0)), sky_hash(cell + vec2(1.0)), f.x), f.y);
}

float cloud_field(vec2 p) {
	return 0.57 * sky_noise(p) + 0.27 * sky_noise(p * 2.13 + 9.5)
		+ 0.12 * sky_noise(p * 4.37 + 23.4) + 0.04 * sky_noise(p * 8.31 + 2.1);
}

void sky() {
	vec3 ray = EYEDIR;
	float height = max(0.0, ray.y);
	vec3 zenith = mix(vec3(0.009,0.017,0.038), vec3(0.055,0.245,0.54), daylight);
	vec3 sky_color = mix(horizon.rgb, zenith, pow(smoothstep(0.0, 0.94, height), 0.55));
	vec3 sun_ray = normalize(sun_direction);
	float toward_sun = max(0.0, dot(ray, sun_ray));
	float warm_glow = pow(toward_sun, 8.0) * (1.0 - smoothstep(0.0, 0.52, height));
	sky_color += vec3(0.64,0.22,0.075) * warm_glow * twilight * 0.47;
	sky_color += vec3(0.95,0.66,0.39) * pow(toward_sun, 60.0) * daylight * 0.25;

	if (ray.y > 0.015) {
		vec2 layer = ray.xz * (4.4 / (height + 0.19));
		float cloud = cloud_field(layer + vec2(3.0, 9.0));
		float mist = smoothstep(0.025, 0.18, height);
		float cover = smoothstep(0.51, 0.67, cloud) * mist;
		float volume = smoothstep(0.51, 0.75, cloud + sky_noise(layer + sun_ray.xz * 0.40) * 0.12);
		vec3 shaded = mix(vec3(0.032,0.043,0.070), vec3(0.48,0.59,0.68), daylight);
		vec3 lit = mix(vec3(0.12,0.15,0.21), vec3(0.95,0.96,0.94), daylight);
		lit += vec3(0.28,0.07,0.0) * twilight * warm_glow;
		sky_color = mix(sky_color, mix(shaded, lit, volume), cover * 0.91);
		float disc = smoothstep(0.99955, 0.99988, toward_sun) * mist;
		vec3 disc_color = mix(vec3(0.56,0.70,0.92), vec3(1.0,0.87,0.68), daylight);
		sky_color = mix(sky_color, disc_color, disc * (1.0-cover) * (0.62 + 0.38*daylight));
	}
	COLOR = sky_color;
}
