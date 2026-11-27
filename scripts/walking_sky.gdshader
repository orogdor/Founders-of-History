shader_type sky;

uniform vec4 horizon : source_color = vec4(0.66,0.78,0.84,1.0);
uniform float daylight = 1.0;
uniform float twilight = 0.0;
uniform vec3 sun_direction = vec3(-0.3,0.7,0.3);
uniform vec2 weather_offset = vec2(0.0);

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
	vec3 zenith = mix(vec3(0.009,0.016,0.036), vec3(0.060,0.220,0.45), daylight);
	float altitude = 1.0 - exp(-height * 3.8);
	vec3 sky_color = mix(horizon.rgb, zenith, altitude);
	vec3 sun_ray = normalize(sun_direction);
	float toward_sun = max(0.0, dot(ray, sun_ray));
	float warm_glow = pow(toward_sun, 6.0) * exp(-height * 4.1);
	sky_color += vec3(0.49,0.16,0.061) * warm_glow * twilight * 0.59;
	sky_color += vec3(0.85,0.62,0.39) * pow(toward_sun, 46.0) * daylight * 0.20;

	if (ray.y > 0.015) {
		vec2 layer = ray.xz * (3.45 / (height + 0.28)) + weather_offset;
		vec2 curl = vec2(sky_noise(layer * 0.45 + vec2(6.3, 27.1)),
		                sky_noise(layer * 0.46 + vec2(-2.4, 16.5))) - 0.5;
		layer += curl * 1.42;
		float cloud = cloud_field(layer + vec2(3.0, 9.0));
		float cluster=sky_noise(layer*.34+vec2(6.3,17.8));
		float cloud_base=mix(.43,.52,cluster);
		float veil = smoothstep(0.045, 0.28, height);
		float cover = smoothstep(cloud_base,cloud_base+.22,cloud)*veil;
		float volume = smoothstep(0.41, 0.78, cloud + sky_noise(layer + sun_ray.xz * 0.67) * 0.19);
		vec3 shaded = mix(vec3(0.030,0.044,0.065), vec3(0.43,0.55,0.63), daylight);
		vec3 lit = mix(vec3(0.105,0.143,0.209), vec3(0.91,0.93,0.91), daylight);
		lit += vec3(0.30,0.10,0.022) * twilight * (0.24 + warm_glow);
		float rim = pow(toward_sun, 18.0) * (1.0 - cover) * smoothstep(0.40, 0.57, cloud);
		vec3 cloud_color = mix(shaded, lit, volume) + vec3(0.40,0.29,0.16) * rim * twilight;
		float cirrus=cloud_field(ray.xz*(2.45/(height+.39))+weather_offset*.65+vec2(24.7,6.4));
		float thin_cloud=smoothstep(.60,.79,cirrus)*veil*(1.0-cover)*.22;
		sky_color=mix(sky_color,lit,thin_cloud);

		vec2 stars = ray.xz / (height + 0.24) * 180.0;
		vec2 cell = floor(stars);
		float star = step(0.996, sky_hash(cell + vec2(17.0, 5.0)));
		star *= 1.0 - smoothstep(0.055, 0.17, length(fract(stars) - 0.5));
		sky_color += vec3(0.54,0.66,0.83) * star * (1.0 - daylight) * (1.0 - twilight) * veil * 0.54;
		sky_color = mix(sky_color, cloud_color, cover * 0.92);
		float disc=smoothstep(.99968,.99983,toward_sun);
		vec3 disc_color=vec3(1.0,.87,.69);
		if(daylight<.45 && twilight<.36 && toward_sun>.9984) {
			vec3 right=normalize(cross(sun_ray,vec3(0,1,0)));
			vec3 top=cross(right,sun_ray);
			vec2 face=vec2(dot(ray,right),dot(ray,top))/.021;
			float phase=smoothstep(-.63,-.42,face.x+face.y*.17+dot(face,face)*.43);
			float maria=sky_noise(face*4.9+vec2(6.7,8.2))*.68+sky_noise(face*11.6+3.7)*.32;
			disc_color=mix(vec3(.50,.60,.70),vec3(.86,.90,.93),smoothstep(.25,.76,maria));
			disc=(1.0-smoothstep(.93,1.06,length(face)))*phase;
		}
		sky_color=mix(sky_color,disc_color,disc*(1.0-cover)*smoothstep(.015,.075,height));
	}
	COLOR = sky_color;
}
