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
 float fine=clay_noise(uv*56.0);
 float wash=clay_noise(uv*2.7+vec2(3.0,7.0));
 float worn=smoothstep(0.66,0.87,clay_noise(uv*vec2(5.7,3.9)+vec2(34.0,1.1))+fine*0.12)
            *smoothstep(0.61,0.98,uv.y);
 vec3 earth=texture(clay_atlas,uv*0.92).rgb;
 vec3 branches=texture(wattle_atlas,uv*2.4).rgb;
 vec3 warm=mix(vec3(0.36,0.24,0.14),vec3(0.58,0.43,0.27),wash);
 vec3 daub=mix(warm,earth*vec3(1.27,1.12,0.88),0.26);
 daub*=0.88+0.16*fine+0.12*(1.0-smoothstep(0.58,1.28,uv.y));
 ALBEDO=mix(daub,branches*vec3(0.96,0.82,0.64),worn*0.75);
 float relief=(fine*0.006+wash*0.008)*(1.0-smoothstep(10.0,33.0,length(VERTEX)));
 NORMAL=material_relief_normal(VERTEX,NORMAL,relief);
 ROUGHNESS=0.97;
 SPECULAR=0.12;
}

