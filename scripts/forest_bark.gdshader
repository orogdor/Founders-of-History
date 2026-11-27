shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D bark_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool birch=false;
varying vec3 bark_position;
varying float instance_age;

void vertex() {
	bark_position=VERTEX;
	vec2 origin=mod(MODEL_MATRIX[3].xz+vec2(112.5,97.5),vec2(225.0,195.0));
	instance_age=fract(sin(dot(floor(origin*2.0),vec2(7.42,17.03))+19.31)*24317.731);
}

void fragment() {
	vec3 bark=texture(bark_atlas,UV).rgb;
	float height=bark_position.y;
	float grain=dot(bark,vec3(.25,.64,.11));
	float foot=1.0-smoothstep(.32,2.10,height);
	float lichen=sin(bark_position.x*1.26+bark_position.z*2.13+instance_age*3.2)
	            *sin(height*3.4+bark_position.z*.93);
	float moss=foot*smoothstep(-.27,.60,lichen+grain*.27);
	float aging=mix(.80,1.05,instance_age);
	vec3 aged=bark*vec3(1.04,.98,.89)*aging;
	if (birch) aged=mix(aged,grain*vec3(1.04,1.02,.95),.33);
	ALBEDO=mix(aged,aged*vec3(.65,.89,.60)+vec3(.026,.035,.012),moss*.74)*(1.0-foot*.14);
	ROUGHNESS=mix(.97,.87,grain);
	SPECULAR=.14;
	float nearby=1.0-smoothstep(13.0,35.0,length(VERTEX));
	float fissure=sin(bark_position.y*2.95+bark_position.x*7.1)*.004;
	NORMAL=material_relief_normal(VERTEX,NORMAL,nearby*(grain*.016+fissure));
}
