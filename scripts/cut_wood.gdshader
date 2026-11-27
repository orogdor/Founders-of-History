shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform bool bark=false;
uniform sampler2D bark_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying float wood_age;

void vertex() {
	vec2 origin=mod(MODEL_MATRIX[3].xz+vec2(112.5,97.5),vec2(225.0,195.0));
	wood_age=fract(sin(dot(floor(origin*3.0),vec2(39.14,26.48)))*44813.51);
}

void fragment() {
	if (bark) {
		vec2 bark_uv=UV*vec2(1.25,1.44)+vec2(wood_age*.69,.23);
		vec3 photo=texture(bark_texture,bark_uv).rgb;
		float pore=dot(photo,vec3(.23,.67,.10));
		float ridge=.5+.5*sin(UV.x*37.1+sin(UV.y*5.21+UV.x*4.6)*.53);
		float plates=smoothstep(.16,.60,pore*.73+ridge*.27);
		vec3 bark_color=mix(vec3(.065,.055,.045),vec3(.304,.251,.183),plates);
		vec3 birch=photo*mix(vec3(.58,.55,.46),vec3(.79,.76,.66),ridge);
		ALBEDO=mix(bark_color,birch,smoothstep(.75,.91,wood_age))*COLOR.rgb;
		ROUGHNESS=.96;
		SPECULAR=.14;
		float relief=(1.0-smoothstep(7.5,23.0,length(VERTEX)))*(.008*pore+ridge*.004);
		NORMAL=material_relief_normal(VERTEX,NORMAL,relief);
	} else {
	vec2 point = (UV - vec2(0.49, 0.52)) * vec2(1.04, 1.13);
	float radius = length(point);
	float angle = atan(point.y, point.x);
	float offset = sin(angle * 3.0 + radius * 11.0) * 0.019 + sin(angle * 5.0 - radius * 4.0) * 0.013;
	float rings = fract((radius + offset) * 22.5);
	float definition = 1.0 - smoothstep(0.36, 1.4, fwidth(radius) * 22.5);
	float latewood = smoothstep(0.59, 0.88, rings) * definition;
	float grain = sin(point.x * 157.0 + sin(point.y * 37.0) * 1.18) * 0.5 + 0.5;
	float split = smoothstep(0.991, 1.0, cos(angle * 5.0 + radius * 0.95)) * smoothstep(0.21, 0.45, radius);
	float edge = smoothstep(0.43, 0.55, radius + offset * 0.29);
	vec3 sapwood = mix(vec3(0.42, 0.268, 0.141), vec3(0.64, 0.468, 0.26), smoothstep(0.08, 0.41, radius));
	sapwood *= (.94+grain*.10)*(1.0-latewood*.20);
	sapwood=mix(sapwood,sapwood*vec3(.84,.88,.93)+vec3(.008,.006,.004),smoothstep(.27,.87,wood_age)*.75);
	sapwood = mix(sapwood, vec3(0.198, 0.138, 0.075), max(edge * 0.54, split * 0.78));
	ALBEDO = sapwood;
	ROUGHNESS = 0.92;
	SPECULAR = 0.13;
	float detail = 1.0 - smoothstep(5.0, 19.0, length(VERTEX));
	NORMAL = material_relief_normal(VERTEX, NORMAL, detail * (grain * 0.0013 - latewood * 0.0017 - split * 0.006));
	}
}
