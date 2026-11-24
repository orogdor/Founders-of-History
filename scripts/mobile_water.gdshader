shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform bool overview = false;
uniform sampler2D ground_heights : filter_linear, repeat_disable;
uniform float grid_size = 9.0;
varying highp vec2 water_pos;
varying float land_height;

void vertex() {
	water_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xz;
	land_height = COLOR.r*160.0-80.0;
}

void fragment() {
	vec2 height_uv = (UV*(grid_size-1.0)+vec2(0.5))/grid_size;
	float depth = overview ? 0.72-land_height : (0.5-texture(ground_heights,height_uv).r)*16.0;
	if (depth <= 0.0) discard;
	float shore = 1.0-smoothstep(0.0,overview ? 3.6 : 1.08,depth);
	highp vec2 wave_pos = water_pos*(overview ? 3.0 : 0.25);
	float ripple = sin(wave_pos.x*1.7+wave_pos.y+TIME*0.9)*sin(wave_pos.y*1.3-TIME*0.65);
	vec3 water = mix(vec3(0.16,0.34,0.39),vec3(0.39,0.51,0.42),shore*shore*0.84);
	ALBEDO = water*(1.0+ripple*0.045);
	ROUGHNESS = 0.85;
}
