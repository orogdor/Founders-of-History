shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/material_relief.gdshaderinc"

uniform bool close_detail = true;
varying vec3 local_pos;
varying vec3 local_normal;
float h154(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float n154(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h154(i),h154(i+vec2(1.0,0.0)),f.x),mix(h154(i+vec2(0.0,1.0)),h154(i+vec2(1.0,1.0)),f.x),f.y);}
void vertex(){local_pos=VERTEX;local_normal=NORMAL;}
void fragment(){
 int m=int(floor(UV.x*15.0+0.5));vec3 p=local_pos,n=normalize(local_normal);bool side=abs(n.x)>abs(n.z);float u=side?p.z:p.x,v=p.y;float k=1.0;vec3 col=COLOR.rgb;float rough=0.88,metal=0.0;
 if(m==1){k=0.93+0.10*n154(p.xz*1.7+p.y*1.3)+0.04*n154(vec2(u,v)*6.0);}
 else if(m==2){float b=fract(u*2.6);k=0.90+0.12*n154(vec2(floor(u*2.6),v*0.7))+0.05*n154(vec2(u*20.0,v*1.5));k*=mix(0.72,1.0,smoothstep(0.0,0.08,b)*(1.0-smoothstep(0.92,1.0,b)));}
 else if(m==3){float r=fract(v*3.2);float roundness=sin(r*3.14159);k=(0.66+0.38*roundness)*(0.9+0.14*n154(vec2(u*1.3,floor(v*3.2))));}
 else if(m==4){float row=floor(v*2.2);float x=u*1.5+h154(vec2(row,3.1))*7.0+row*0.37;float cx=fract(x),cy=fract(v*2.2);float jt=min(min(cx,1.0-cx)*2.6,min(cy,1.0-cy)*4.5);k=(0.82+0.25*h154(vec2(floor(x),row)))*mix(0.55,1.0,smoothstep(0.04,0.16,jt));}
 else if(m==5){float row=floor(v*6.0);float x=u*3.0+row*0.5;float cx=fract(x),cy=fract(v*6.0);float jt=min(min(cx,1.0-cx)*5.0,min(cy,1.0-cy)*3.0);k=(0.84+0.22*h154(vec2(floor(x),row)))*mix(1.25,1.0,smoothstep(0.05,0.2,jt));if(jt<0.05)k=1.35;}
 else if(m==6){float row=v*4.2;float r=fract(row);float x=fract(u*2.8+floor(row)*0.5);k=(0.78+0.28*smoothstep(0.0,0.85,r))*(0.9+0.16*h154(vec2(floor(u*2.8+floor(row)*0.5),floor(row))))*mix(0.78,1.0,smoothstep(0.0,0.12,x));}
 else if(m==7){k=0.78+0.30*n154(vec2(u*9.0,v*1.4))+0.10*n154(vec2(u*30.0,v*4.0));k*=0.92+0.10*smoothstep(0.85,1.0,fract(v*1.6));}
 else if(m==8){float r=fract(v*5.5);float x=fract(u*3.4+floor(v*5.5)*0.5);k=(0.82+0.2*h154(vec2(floor(u*3.4+floor(v*5.5)*0.5),floor(v*5.5))))*mix(0.8,1.0,smoothstep(0.0,0.1,r))*mix(0.85,1.0,smoothstep(0.0,0.08,x));}
 else if(m==9){float g=smoothstep(0.2,0.9,n154(vec2(u*0.7+v*0.4,v*0.3)));col=mix(col,vec3(0.78,0.86,0.9),g*0.35);rough=0.12;}
 else if(m==10){k=0.92+0.1*n154(vec2(u*4.0,v*4.0));rough=0.42;metal=0.55;}
 else if(m==11){k=0.86+0.16*n154(vec2(u*1.5+v*1.5,(u+v)*14.0));}
 else if(m==12){k=0.84+0.24*n154(p.xz*1.4)+0.06*n154(p.xz*9.0);}
 else if(m==13){k=0.75+0.35*n154(p.xz*3.0+p.y*2.0);}
 else if(m==14){k=0.95+0.05*n154(vec2(u*12.0,v*12.0));}
 // Retain the original board and masonry spacing. Add a finer scale of
 // directional grain on wood and more isotropic grain on mineral surfaces.
 float micro=0.0;
 float relief=0.0;
 float closeness=close_detail ? 1.0-smoothstep(29.0,90.0,length(VERTEX)) : 0.0;
 if(m!=9 && m!=10 && m!=14){
  vec2 face=abs(n.y)>0.7?p.xz:vec2(u,v);
  bool timber=m==2 || m==3 || m==7 || m==8 || m==11;
  vec2 fibre=timber?vec2(73.0,7.0):vec2(38.0,46.0);
  vec2 texel=face*fibre+vec2(9.4,13.7);
  float footprint=max(length(dFdx(texel)),length(dFdy(texel)));
  float resolved=1.0-smoothstep(0.25,1.4,footprint);
  micro=(n154(texel)-0.5)*resolved;
  relief=(k-0.85)*(timber?0.022:0.035)+micro*(timber?0.007:0.010);
  rough=clamp(rough+0.13*(0.8-k),0.72,0.99);
 }
 NORMAL=material_relief_normal(VERTEX,NORMAL,relief*closeness);
 ALBEDO=col*k*(1.0+0.22*micro*closeness);
 ROUGHNESS=rough;
 METALLIC=metal;
 SPECULAR=m==9?0.47:0.22;
}
