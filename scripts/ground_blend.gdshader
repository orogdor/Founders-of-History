shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://scripts/painted_relief.gdshaderinc"

uniform sampler2D painted_meadow : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_forest : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D painted_stone : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float forest_factor = 0.0;
uniform vec4 base_color : source_color = vec4(0.4,0.5,0.3,1.0);
uniform vec4 sand_color : source_color = vec4(0.698,0.631,0.486,1.0);
uniform vec4 wet_sand_color : source_color = vec4(0.561,0.510,0.4,1.0);
instance uniform vec2 painted_world_origin = vec2(0.0);
instance uniform bool blend_neighbours = false;
instance uniform vec4 ground_w : source_color = vec4(0.0);
instance uniform vec4 ground_e : source_color = vec4(0.0);
instance uniform vec4 ground_n : source_color = vec4(0.0);
instance uniform vec4 ground_s : source_color = vec4(0.0);
instance uniform vec4 ground_nw : source_color = vec4(0.0);
instance uniform vec4 ground_ne : source_color = vec4(0.0);
instance uniform vec4 ground_sw : source_color = vec4(0.0);
instance uniform vec4 ground_se : source_color = vec4(0.0);
varying float ground_height;
varying float beach_wobble;
varying vec2 tile_uv;
varying float slope;

void vertex() {
 ground_height=UV2.x;
 beach_wobble=UV2.y;
 tile_uv=UV;
 slope=1.0-abs(NORMAL.y);
}

float h(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1.0,0.0)),f.x),mix(h(i+vec2(0.0,1.0)),h(i+vec2(1.0,1.0)),f.x),f.y);}
float fractal(vec2 p){return n(p)*0.55+n(p*2.07+17.3)*0.30+n(p*4.31+41.9)*0.15;}
void fragment(){
 vec4 local_ground=vec4(base_color.rgb,forest_factor);
 if(blend_neighbours){
  float x=clamp(abs(tile_uv.x)/225.0,0.0,0.5),z=clamp(abs(tile_uv.y)/195.0,0.0,0.5);
  vec4 horizontal=tile_uv.x<0.0?ground_w:ground_e;
  vec4 vertical=tile_uv.y<0.0?ground_n:ground_s;
  vec4 diagonal=tile_uv.x<0.0?(tile_uv.y<0.0?ground_nw:ground_sw):(tile_uv.y<0.0?ground_ne:ground_se);
  local_ground=mix(mix(local_ground,horizontal,x),mix(vertical,diagonal,x),z);
 }
 vec2 point=tile_uv+painted_world_origin;
 float broad=fractal(point*0.040+vec2(2.7,5.3));
 float brush=fractal(point*0.21+vec2(7.7,20.1));
 float fine=n(point*0.93+vec2(19.0,4.0));
 float woodland=local_ground.a*smoothstep(0.29,0.68,broad*0.48+brush*0.52);
 float bare=smoothstep(0.44,0.70,broad*0.57+brush*0.31+fine*0.11);
 bare=max(bare,smoothstep(0.10,0.38,slope)*0.83);
 float temperate=smoothstep(0.01,0.055,local_ground.g-local_ground.r)
                 *(1.0-smoothstep(0.23,0.50,local_ground.b));
 float near_amount=(1.0-smoothstep(75.0,170.0,length(VERTEX)))*smoothstep(0.35,1.7,ground_height);
 vec3 deep=local_ground.rgb*vec3(0.62,0.79,0.79);
 vec3 sunny=local_ground.rgb*vec3(1.06,0.94,0.88);
 vec3 distant=mix(deep,sunny,smoothstep(0.18,0.78,broad));
 distant=mix(distant,vec3(0.175,0.127,0.081),bare*0.57*temperate);
 distant=mix(distant,vec3(0.082,0.095,0.051),woodland*0.55*temperate);
 distant*=0.94+0.12*brush+0.035*fine;

 vec4 ground=vec4(distant,0.5);
 if(near_amount>0.02 && temperate>0.02){
  vec2 uv=point*0.52;
  vec4 meadow=painted_regions(painted_meadow,uv,point/17.0);
  meadow.rgb*=vec3(1.07,0.83,1.13)*(0.78+0.32*broad);
  ground=mix(ground,meadow,temperate*0.91);
  if(woodland>0.025){
   vec4 forest=painted_regions(painted_forest,uv*0.86+vec2(1.4,0.2),point/19.0);
   ground=mix(ground,forest,woodland*0.92);
  }
  if(bare>0.025){
   vec4 earth=painted_regions(painted_soil,uv*0.75+vec2(0.8,1.2),point/21.0);
   ground=mix(ground,earth,bare*0.92);
  }
 } else if(near_amount>0.02) {
  vec4 earth=painted_regions(painted_soil,point*0.43,point/21.0);
  float rocky=smoothstep(0.18,0.58,slope);
  if(rocky>0.02){
   earth=mix(earth,painted_regions(painted_stone,point*0.34,point/23.0),rocky);
  }
  float grain=dot(earth.rgb,vec3(0.30,0.59,0.11));
  ground=vec4(distant*(0.86+0.51*grain),earth.a);
 }
 vec3 surface=mix(distant,ground.rgb,near_amount);
 float sand=1.0-smoothstep(0.4+beach_wobble,1.15+beach_wobble,ground_height);
 float relief=mix(0.5,ground.a,near_amount);
 if(sand>0.01){
  float coastal_detail=1.0-smoothstep(55.0,130.0,length(VERTEX));
  vec4 grain=vec4(0.25,0.25,0.25,0.5);
  if(coastal_detail>0.02){grain=painted_regions(painted_soil,point*0.85,point/14.0);}
  surface=mix(surface,sand_color.rgb*(0.65+(dot(grain.rgb,vec3(0.30,0.59,0.11))-0.25)*0.24*coastal_detail),sand);
  relief=mix(relief,mix(0.5,grain.a,coastal_detail*0.32),sand);
 }
 surface=mix(surface,wet_sand_color.rgb*0.55,(1.0-smoothstep(-0.05,0.35,ground_height))*0.55);
 ALBEDO=surface;
 NORMAL=painted_relief(VERTEX,NORMAL,relief,0.026);
 ROUGHNESS=mix(0.96,0.88,bare);
 SPECULAR=0.19;
}
