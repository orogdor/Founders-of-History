shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;
uniform sampler2D seen_linear : filter_linear, repeat_disable;
uniform sampler2D seen_exact : filter_nearest, repeat_disable;
uniform sampler2D symbols : filter_nearest, repeat_disable;
varying vec2 map_pos;
float fog_hash(vec2 p) {
 vec3 mix_seed=fract(vec3(p.xyx)*.1031);
 mix_seed+=dot(mix_seed,mix_seed.yzx+33.33);
 return fract((mix_seed.x+mix_seed.y)*mix_seed.z);
}
float fog_noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(fog_hash(i),fog_hash(i+vec2(1.0,0.0)),f.x),mix(fog_hash(i+vec2(0.0,1.0)),fog_hash(i+vec2(1.0,1.0)),f.x),f.y);
}
float segment(vec2 p,vec2 a,vec2 b) {
 vec2 ab=b-a;float t=clamp(dot(p-a,ab)/dot(ab,ab),0.0,1.0);
 return 1.0-smoothstep(.018,.032,length(p-(a+t*ab)));
}
float symbol_ink(vec2 p,float kind) {
 float m=0.0;
 if(kind<.375) {
  m=max(segment(p,vec2(.12,.62),vec2(.32,.45)),segment(p,vec2(.32,.45),vec2(.52,.63)));
  m=max(m,segment(p,vec2(.52,.63),vec2(.68,.72)));m=max(m,segment(p,vec2(.68,.72),vec2(.88,.52)));
  m=max(m,segment(p,vec2(.17,.78),vec2(.84,.78)));m=max(m,segment(p,vec2(.17,.86),vec2(.84,.86)));
 } else if(kind<.625) {
  m=max(segment(p,vec2(.14,.75),vec2(.36,.38)),segment(p,vec2(.36,.38),vec2(.56,.75)));
  m=max(m,segment(p,vec2(.44,.75),vec2(.67,.30)));m=max(m,segment(p,vec2(.67,.30),vec2(.87,.75)));
 } else if(kind<.875) {
  for(int i=0;i<3;i++) {float x=.26+float(i)*.24;
   m=max(m,segment(p,vec2(x,.77),vec2(x,.63)));
   m=max(m,segment(p,vec2(x-.12,.64),vec2(x,.39)));
   m=max(m,segment(p,vec2(x,.39),vec2(x+.12,.64)));
   m=max(m,segment(p,vec2(x-.12,.64),vec2(x+.12,.64)));
  }
 } else {
  float radius=length(p-vec2(.5));m=1.0-smoothstep(.018,.032,abs(radius-.20));
  for(int i=0;i<8;i++){float a=float(i)*.785398;vec2 d=vec2(cos(a),sin(a));m=max(m,segment(p,vec2(.5)+d*.24,vec2(.5)+d*.36));}
 }
 return m;
}
void vertex() { map_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz; }
void fragment() {
 vec2 cells=vec2(textureSize(seen_exact,0));
 vec2 tile=(map_pos+cells)*.5;
 vec2 paper=tile*50.0;
 vec2 center=(floor(tile)+.5)/cells;
 float covered=step(.5,texture(seen_exact,center).a);
 float nearby=texture(seen_linear,tile/cells).a;
 float grain=fog_noise(paper*.057);
 float stain=fog_noise(paper*.0037)+.35*fog_noise(paper*.013);
 float edge=smoothstep(.24,.51,nearby+(grain-.5)*.08);
 vec2 fiber_pos=vec2(paper.x-paper.y*.37,paper.x*.24+paper.y)*vec2(.65,.09);
 float fibers=(fog_noise(fiber_pos)-.5)*(1.0-smoothstep(.34,1.25,length(fwidth(paper))));
 vec3 paper_color=mix(vec3(.70,.59,.42),vec3(.89,.80,.63),clamp(stain*.61+.17,0.0,1.0));
 paper_color*=.985+fibers*.085+grain*.035;
 float kind=texture(symbols,center).r;
 if(kind>.1) {
  float ink=symbol_ink(fract(tile),kind)*(.33+.17*grain);
  paper_color=mix(paper_color,vec3(.34,.26,.15),ink);
 }
 ALBEDO=paper_color*mix(1.0,.91,edge*(1.0-smoothstep(.57,.98,nearby)));
 ALPHA=max(covered,edge);
}
