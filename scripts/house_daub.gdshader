shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D clay_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wattle_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float clay_hash(vec2 p) {
 return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}

float clay_noise(vec2 p) {
 vec2 cell=floor(p), f=fract(p);
 f=f*f*(3.0-2.0*f);
 return mix(mix(clay_hash(cell),clay_hash(cell+vec2(1.0,0.0)),f.x),
            mix(clay_hash(cell+vec2(0.0,1.0)),clay_hash(cell+vec2(1.0,1.0)),f.x),f.y);
}

void fragment() {
 vec2 uv=UV;
 float fine=clay_noise(uv*41.0);
 float wash=clay_noise(uv*2.7+vec2(3.0,7.0));
 float worn=smoothstep(0.66,0.87,clay_noise(uv*vec2(5.7,3.9)+vec2(34.0,1.1))+fine*0.12)
            *smoothstep(0.61,0.98,uv.y);
 vec3 earth=texture(clay_atlas,uv*0.92).rgb;
 vec3 branches=texture(wattle_atlas,uv*2.4).rgb;
 vec3 earth_tone=mix(vec3(.34,.285,.210),vec3(.58,.495,.365),wash);
 vec3 lime=vec3(.65,.61,.51);
 float lime_wash=smoothstep(.29,.73,wash)*.36;
 vec3 daub=mix(mix(earth_tone,lime,lime_wash),earth*vec3(1.05,1.03,.93),.21);
 daub*=0.88+0.16*fine+0.06*(1.0-smoothstep(0.58,1.28,uv.y));
 ALBEDO=mix(daub,branches*vec3(0.89,0.75,0.58),worn*0.69)*COLOR.r;
 AO=mix(.56,1.0,COLOR.r);
 AO_LIGHT_AFFECT=.22;
 float relief=(fine*.006+wash*.014)*(1.0-smoothstep(10.0,33.0,length(VERTEX)));
 NORMAL=material_relief_normal(VERTEX,NORMAL,relief);
 ROUGHNESS=0.97;
 SPECULAR=0.12;
}

