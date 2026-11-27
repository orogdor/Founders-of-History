shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, diffuse_burley;

#include "res://scripts/water_surface.gdshaderinc"
#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D bank_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 phase_origin=vec2(0.0);
varying vec2 bank_position;

void vertex() {
	bank_position=VERTEX.xz+phase_origin;
}

void fragment() {
	float near_water=clamp(COLOR.a,0.0,1.0);
	float coarse=water_noise(bank_position*.18);
	float patch=water_noise(bank_position*.54+vec2(14.9,3.6));
	float visibility=1.0-smoothstep(68.0,160.0,length(VERTEX));
	vec2 stones=bank_position*.47+vec2(coarse,patch)*.57;
	vec3 gravel=texture(bank_texture,stones).rgb;
	float grain=dot(gravel,vec3(.24,.65,.11));
	float sand=smoothstep(.22,.67,coarse+patch*.19);
	vec3 sediment=mix(vec3(.27,.232,.164),vec3(.42,.371,.285),sand);
	sediment*=mix(1.0,.80+.51*grain,visibility);
	float moss=smoothstep(.42,.72,patch)*smoothstep(.32,.81,near_water);
	ALBEDO=mix(sediment,vec3(.195,.247,.149),moss*.48);
	ROUGHNESS=mix(.98,.71,near_water);
	SPECULAR=mix(.13,.29,near_water);
	vec3 slope=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));
	vec3 up=mat3(VIEW_MATRIX)*vec3(0.0,1.0,0.0);
	slope*=sign(dot(slope,up));
	NORMAL=material_relief_normal(VERTEX,slope,grain*.011*visibility);
	ALPHA=smoothstep(.01,.81,near_water)*(.45+coarse*.39+patch*.08);
}
