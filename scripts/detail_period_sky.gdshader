shader_type sky;

uniform sampler2D cloud_shape : filter_linear_mipmap, repeat_enable;
uniform vec4 upper_sky : source_color;
uniform vec4 horizon_sky : source_color;
uniform vec4 bright_cloud : source_color;
uniform vec4 soft_cloud : source_color;
uniform vec4 sunlight : source_color;
uniform vec3 sun_direction;
uniform float daylight;
uniform float cloud_floor;
uniform float drift;

void sky() {
	float elevation = max(0.0, EYEDIR.y);
	vec3 backdrop = mix(horizon_sky.rgb, upper_sky.rgb, pow(elevation, 0.47));
	if (AT_CUBEMAP_PASS) {
		COLOR = backdrop;
	} else {
		vec2 cloud_uv = EYEDIR.xz / (0.33 + elevation) * vec2(0.23, 0.31);
		cloud_uv += vec2(drift, drift * 0.24);
		float broad = texture(cloud_shape, cloud_uv).r;
		float edges = texture(cloud_shape, cloud_uv * 2.9 + vec2(0.27, 0.07)).r;
		float clouds = 0.82 * broad + 0.18 * edges;
		float mask = smoothstep(cloud_floor, cloud_floor + 0.128, clouds);
		mask *= smoothstep(0.013, 0.13, elevation);
		float toward_sun = max(0.0, dot(EYEDIR, sun_direction));
		vec3 cloud_rgb = mix(soft_cloud.rgb, bright_cloud.rgb,
			clamp(edges * 0.36 + toward_sun * 0.46, 0.0, 1.0));
		vec3 glow = sunlight.rgb * pow(toward_sun, 18.0) * (0.105 * daylight);
		float disc = smoothstep(0.99945, 0.99977, toward_sun) * daylight * 0.76;
		COLOR = mix(backdrop + glow, cloud_rgb + glow * 0.3, mask);
		COLOR += sunlight.rgb * disc * (1.0 - mask * 0.90);
	}
}
