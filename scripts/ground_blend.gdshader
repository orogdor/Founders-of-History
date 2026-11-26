shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/surface_relief.gdshaderinc"
#include "res://scripts/detail_map_fog.gdshaderinc"
#include "res://scripts/detail_surface_sampling.gdshaderinc"

uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D forest_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_height_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float forest_factor = 0.0;
uniform vec4 base_color : source_color = vec4(0.4,0.5,0.3,1.0);
uniform vec4 sand_color : source_color = vec4(0.698,0.631,0.486,1.0);
uniform vec4 wet_sand_color : source_color = vec4(0.561,0.510,0.4,1.0);
instance uniform vec2 detail_uv_offset = vec2(0.0);
instance uniform bool blend_neighbours = false;
instance uniform vec4 undiscovered_edges = vec4(0.0);
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
varying vec2 shifted_uv;
varying vec2 tile_uv;

void vertex(){ground_height=UV2.x;beach_wobble=UV2.y;tile_uv=UV;shifted_uv=UV+detail_uv_offset;}

float h(vec2 p){p=fract(p*vec2(123.34,456.21));p+=dot(p,p+45.32);return fract(p.x*p.y);}
float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(h(i),h(i+vec2(1.0,0.0)),f.x),mix(h(i+vec2(0.0,1.0)),h(i+vec2(1.0,1.0)),f.x),f.y);}
float fractal(vec2 p){return n(p)*0.55+n(p*2.07+17.3)*0.30+n(p*4.31+41.9)*0.15;}
vec4 sample_ground(sampler2D image, vec2 uv, vec2 wide, vec2 dx, vec2 dy, vec2 wx, vec2 wy, float blend) {
	return mix(textureGrad(image, uv, dx, dy),textureGrad(image, wide, wx, wy),blend);
}

void fragment(){
 vec2 q=shifted_uv;
 vec2 uv=terrain_primary_uv(q);
 vec2 dx=dFdx(uv)*1.08,dy=dFdy(uv)*1.08;
 vec2 wide=terrain_secondary_uv(q);
 vec2 wx=dFdx(wide)*1.08,wy=dFdy(wide)*1.08;
 float distance_to_camera=length(VERTEX);
 vec4 local_ground=vec4(base_color.rgb,forest_factor);
 if(blend_neighbours){
  float x=clamp(abs(tile_uv.x)/225.0,0.0,0.5),z=clamp(abs(tile_uv.y)/195.0,0.0,0.5);
  vec4 horizontal=tile_uv.x<0.0?ground_w:ground_e;
  vec4 vertical=tile_uv.y<0.0?ground_n:ground_s;
  vec4 diagonal=tile_uv.x<0.0?(tile_uv.y<0.0?ground_nw:ground_sw):(tile_uv.y<0.0?ground_ne:ground_se);
  local_ground=mix(mix(local_ground,horizontal,x),mix(vertical,diagonal,x),z);
 }
 float photo_strength=0.93*(1.0-smoothstep(112.0,300.0,distance_to_camera))*smoothstep(0.4,1.6,ground_height);
 // The source keeps procedural meadow and soil variation after the close-up
 // photographs have faded; a uniform fallback makes the whole tile flat green.
 float meadow=fractal(q*0.034+vec2(8.0,8.0));
 vec2 patch=q+terrain_bend(q*0.037,vec2(71.3,41.9))*12.0;
 float drainage=0.68*meadow+0.32*fractal(patch*vec2(0.055,0.091)+vec2(16.8,21.2));
 float lowland=1.0-smoothstep(7.0,9.0,ground_height);
 vec3 muted=mix(local_ground.rgb,vec3(0.0648,0.0908,0.0423),0.24)*0.87;
 vec3 ground=mix(local_ground.rgb,muted,lowland);
 vec3 lush=ground*vec3(0.84,1.0,0.82);
 vec3 dry=ground*vec3(1.13,1.05,0.76)+vec3(0.035,0.02,0.0);
 vec3 distant=mix(lush,dry,smoothstep(0.38,0.74,meadow));
 float cl=n(q*0.55),cl2=n(q*1.7+vec2(4.0));
 distant*=1.0+(cl-0.5)*0.12+(cl2-0.5)*0.05;
 float organic=fractal(q*0.72+vec2(17.0,3.0));
 distant=mix(distant,distant*vec3(0.73,0.68,0.54),smoothstep(0.54,0.83,organic)*0.20);
 float soil_patch=smoothstep(0.62,0.81,fractal(q*0.048+vec2(11.0))+(n(q*0.6)-0.5)*0.12);
 vec3 soil_tint=mix(distant,vec3(0.40,0.32,0.22),0.75)*(0.85+n(q*2.3)*0.28);
 distant=mix(distant,soil_tint,soil_patch*(0.45+0.20*local_ground.a));
 vec3 surface=distant;
 ROUGHNESS=0.94;
 NORMAL_MAP=vec3(0.5,0.5,1.0);
 NORMAL_MAP_DEPTH=0.0;
 if(photo_strength>0.0){
  float clearings=fractal(q*0.090+vec2(13.0,29.0));
  float dirt=smoothstep(0.49,0.76,clearings+(drainage-0.5)*0.18+(n(q*0.92)-0.5)*0.08);
  float forest=local_ground.a*(0.68+0.25*n(q*0.13));
  vec3 coverage=vec3((1.0-dirt)*(1.0-forest),dirt*(1.0-forest),forest);
  float scale_blend=terrain_layer_mix(q);
  vec3 heights=sample_ground(ground_height_maps,uv,wide,dx,dy,wx,wy,scale_blend).rgb;
  vec3 weights=mix(coverage,height_blend_weights(coverage,heights),0.74);
  float height=dot(heights,weights);
  float relief=(1.0-smoothstep(16.0,52.0,distance_to_camera))*photo_strength;
  vec2 parallax=relief_direction(VIEW,TANGENT,BINORMAL,NORMAL)*(1.0-height)*0.027*relief;
  vec2 shifted=uv-TERRAIN_ROTATION*parallax;
  vec2 shifted_wide=wide-TERRAIN_SECONDARY_ROTATION*parallax*(TERRAIN_SECONDARY_SCALE/0.51);
  vec3 grass=sample_ground(grass_color,shifted,shifted_wide,dx,dy,wx,wy,scale_blend).rgb;
  vec3 soil=sample_ground(soil_color,shifted,shifted_wide,dx,dy,wx,wy,scale_blend).rgb;
  vec3 litter=sample_ground(forest_color,shifted,shifted_wide,dx,dy,wx,wy,scale_blend).rgb;
  float growth=smoothstep(0.29,0.71,drainage);
  grass*=mix(vec3(0.71,0.91,0.83),vec3(1.28,1.18,0.88),growth);
  soil*=mix(vec3(0.79,0.66,0.56),vec3(1.22,1.02,0.86),smoothstep(0.27,0.69,heights.y));
  soil=mix(soil,grass*vec3(1.20,0.99,0.75),0.18);
  litter*=mix(vec3(0.75,0.74,0.64),vec3(1.17,1.01,0.79),smoothstep(0.29,0.72,heights.z));
  vec3 photo=(grass*weights.x+soil*weights.y+litter*weights.z)*(0.87+0.13*growth);
  photo=mix(photo,photo*local_ground.rgb*2.0,0.18);
  photo*=mix(1.0,0.77+0.36*height,relief);
  vec3 surface_normal=textureGrad(grass_normal,shifted,dx,dy).xyz*weights.x
                    +textureGrad(soil_normal,shifted,dx,dy).xyz*weights.y
                    +textureGrad(forest_normal,shifted,dx,dy).xyz*weights.z;
  surface_normal.xy=transpose(TERRAIN_ROTATION)*(surface_normal.xy-0.5)+0.5;
  vec3 roughness=vec3(textureGrad(grass_rough,shifted,dx,dy).r,
                      textureGrad(soil_rough,shifted,dx,dy).r,
                      textureGrad(forest_rough,shifted,dx,dy).r);
  ROUGHNESS=mix(0.94,clamp(dot(roughness,weights),0.65,1.0),photo_strength);
  // Resolve smaller blades, leaf litter and pebbles near the camera using a
  // second octave of the packed photographic height maps. Mips handle minification.
  float close_detail=1.0-smoothstep(18.0,70.0,distance_to_camera);
  if(close_detail>0.0){
   vec2 grain_uv=TERRAIN_SECONDARY_ROTATION*uv*2.0+vec2(0.63,0.11);
   vec2 grain_dx=TERRAIN_SECONDARY_ROTATION*dx*2.0,grain_dy=TERRAIN_SECONDARY_ROTATION*dy*2.0;
   float grain=dot(textureGrad(ground_height_maps,grain_uv,grain_dx,grain_dy).rgb,weights);
   float grain_x=dot(textureGrad(ground_height_maps,grain_uv+vec2(0.005,0.0),grain_dx,grain_dy).rgb,weights);
   float grain_y=dot(textureGrad(ground_height_maps,grain_uv+vec2(0.0,0.005),grain_dx,grain_dy).rgb,weights);
   float contact=clamp((grain-0.5)*0.83+(height-grain)*0.18,-0.25,0.25);
   photo*=1.0+contact*close_detail;
   vec2 grain_slope=transpose(TERRAIN_SECONDARY_ROTATION*TERRAIN_ROTATION)*vec2(grain-grain_x,grain-grain_y);
   surface_normal.xy+=grain_slope*0.40*close_detail;
   ROUGHNESS=clamp(ROUGHNESS+(0.5-grain)*0.13*close_detail,0.62,1.0);
  }
  surface=mix(distant,photo,photo_strength);
  NORMAL_MAP=clamp(surface_normal,vec3(0.0),vec3(1.0));
  NORMAL_MAP_DEPTH=0.77*photo_strength;
 }
 float sand=1.0-smoothstep(0.12+beach_wobble,0.83+beach_wobble,ground_height);
 if(sand>0.0){
  float grains=dot(textureGrad(soil_color,uv,dx,dy).rgb,vec3(0.31,0.57,0.12));
  float relief=textureGrad(ground_height_maps,uv,dx,dy).g;
  float grain_amount=1.0-smoothstep(115.0,280.0,distance_to_camera);
  float moisture=(1.0-smoothstep(-0.05,0.33,ground_height))*0.72;
  vec3 shore=mix(sand_color.rgb,wet_sand_color.rgb,moisture);
  shore*=0.62+0.27*fractal(q*0.10)+grain_amount*(grains*0.34+relief*0.17-0.12);
  surface=mix(surface,shore,sand);
 }
 ALBEDO=surface;
 SPECULAR=mix(0.12,0.22,sand);
 if(dot(undiscovered_edges,vec4(1.0))>0.0){
  float mist=detail_cloud_edge(tile_uv,shifted_uv,undiscovered_edges);
  if(mist>0.0){
   vec2 projection=detail_cloud_projection(shifted_uv,mat3(INV_VIEW_MATRIX)*VERTEX,CAMERA_POSITION_WORLD.y);
   ALBEDO*=1.0-mist;
   EMISSION=detail_cloud_color(projection)*mist;
   SPECULAR*=1.0-mist;
  }
 }
}
