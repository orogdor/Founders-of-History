shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

#include "res://scripts/water_surface.gdshaderinc"

varying float flame_seed;

void vertex() {
	vec2 origin=mod(MODEL_MATRIX[3].xz+vec2(112.5,97.5),vec2(225.0,195.0));
	flame_seed=water_hash(origin)*8.0;
}

void fragment() {
	float x=UV.x-.5;
	float y=1.0-UV.y;
	float t=TIME*3.4+flame_seed;
	float draft=water_noise(vec2(flame_seed+t*.51,y*3.3-t*.92))-.5;
	float tongue=water_noise(vec2(x*9.5+y*1.1,y*4.3-t*1.3));
	float curl=(draft*.27+.045*sin(t+y*5.5))*y*y;
	float lift=clamp(1.0-y*(1.12-.24*tongue),0.0,1.0);
	float width=max(.001,pow(lift,.78)*(.275+.092*tongue));
	float cross_section=abs(x+curl)/width;
	float flame=(1.0-smoothstep(.28,1.0,cross_section))*smoothstep(.0,.075,y)*smoothstep(.015,.16,lift);
	float hot=(1.0-smoothstep(.08,.68,cross_section))*(1.0-smoothstep(.37,.71,y));
	vec3 color=mix(vec3(.91,.16,.028),vec3(1.0,.57,.146),flame);
	color=mix(color,vec3(1.0,.92,.68),hot);
	color=mix(color,vec3(.30,.37,.58),(1.0-smoothstep(.013,.085,y))*.55);
	ALBEDO=color*(.94+.55*hot);
	ALPHA=flame*.74;
}
