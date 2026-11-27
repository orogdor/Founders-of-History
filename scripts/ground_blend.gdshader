shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/surface_relief.gdshaderinc"
#include "res://scripts/detail_map_fog.gdshaderinc"
#include "res://scripts/detail_surface_sampling.gdshaderinc"
#include "res://scripts/material_relief.gdshaderinc"
#include "res://scripts/terrain_climate.gdshaderinc"

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
uniform sampler2D cliff_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool detail_maps_ready = false;
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
varying float relief_height;
varying float beach_wobble;
varying vec2 shifted_uv;
varying vec2 tile_uv;

void vertex(){ground_height=UV2.x;relief_height=VERTEX.y;beach_wobble=UV2.y;tile_uv=UV;shifted_uv=UV+detail_uv_offset;}

float fractal(vec2 p){return cloud_noise(p)*0.55+cloud_noise(p*2.07+17.3)*0.30+cloud_noise(p*4.31+41.9)*0.15;}
vec4 sample_ground(sampler2D image, vec2 uv, vec2 wide, vec2 dx, vec2 dy, vec2 wx, vec2 wy, float blend) {
	return mix(textureGrad(image, uv, dx, dy),textureGrad(image, wide, wx, wy),blend);
}

void fragment(){
 vec2 q=shifted_uv;
 vec3 climate=ground_climate(q/vec2(225.0,195.0),false);
 float dry_terrain=climate_dry(climate);
 vec2 organic_uv=q+terrain_bend(q*0.17,vec2(17.1,49.0))*1.68;
 vec2 uv=terrain_primary_uv(organic_uv);
 vec2 dx=dFdx(uv)*1.12,dy=dFdy(uv)*1.12;
 vec2 wide=terrain_secondary_uv(organic_uv);
 vec2 wx=dFdx(wide)*1.12,wy=dFdy(wide)*1.12;
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
 vec3 land_normal=normalize(mat3(INV_VIEW_MATRIX)*NORMAL);
 float slope=1.0-abs(land_normal.y);
 float exposed=smoothstep(0.065,0.33,slope);
 float wet=1.0-smoothstep(0.75,6.2,ground_height);
 float damp=wet*smoothstep(0.25,0.68,drainage);
 float lowland=1.0-smoothstep(7.0,9.0,ground_height);
 vec3 muted=mix(local_ground.rgb,vec3(0.066,0.083,0.046),0.22)*0.91;
 vec3 ground=mix(local_ground.rgb,muted,lowland);
 vec3 lush=ground*vec3(0.81,1.04,0.86);
 vec3 dry=ground*vec3(1.085,1.04,0.80)+vec3(0.026,0.017,0.006);
 vec3 distant=mix(lush,dry,smoothstep(0.38,0.74,meadow));
 float cl=cloud_noise(q*0.55),cl2=cloud_noise(q*1.7+vec2(4.0));
 distant*=1.0+(cl-0.5)*0.085+(cl2-0.5)*0.035;
 float organic=fractal(q*0.72+vec2(17.0,3.0));
 distant=mix(distant,distant*vec3(0.73,0.68,0.54),smoothstep(0.54,0.83,organic)*0.20);
 float soil_patch=smoothstep(0.59,0.80,fractal(patch*0.048+vec2(11.0))+(cl-0.5)*0.12+exposed*0.21);
 vec3 soil_tint=mix(distant,vec3(0.37,0.31,0.235),0.72)*(0.89+cl2*0.22);
 distant=mix(distant,soil_tint,soil_patch*(0.45+0.20*local_ground.a));
 distant*=1.0-damp*0.12;
 vec3 surface=distant;
 ROUGHNESS=0.94;
 NORMAL_MAP=vec3(0.5,0.5,1.0);
 NORMAL_MAP_DEPTH=0.0;
 if(photo_strength>0.0){
  float clearings=fractal(patch*0.077+vec2(13.0,29.0));
  float dirt=smoothstep(0.47,0.74,clearings+(0.48-drainage)*0.22+(cl-0.5)*0.10+exposed*0.21);
  float moss=fractal(patch*0.147+vec2(37.0,55.4));
  float forest=local_ground.a*mix(0.43,0.91,smoothstep(0.24,0.76,moss))*(1.0-exposed*0.45);
  float bare=max(dirt*0.93,smoothstep(0.55,0.83,fractal(patch*0.18+vec2(87.0)))*0.66);
  bare=mix(bare,1.0,dry_terrain);
  vec3 coverage=vec3((1.0-bare)*(1.0-forest),bare*(1.0-forest),forest);
  float scale_blend=terrain_layer_mix(organic_uv);
  vec3 heights=sample_ground(ground_height_maps,uv,wide,dx,dy,wx,wy,scale_blend).rgb;
  vec3 weights=mix(coverage,height_blend_weights(coverage,heights),0.43);
  float height=dot(heights,weights);
  float relief=(1.0-smoothstep(16.0,52.0,distance_to_camera))*photo_strength;
  vec2 parallax=relief_direction(VIEW,TANGENT,BINORMAL,NORMAL)*(1.0-height)*0.012*relief;
  vec2 shifted=uv-TERRAIN_ROTATION*parallax;
  vec2 shifted_wide=wide-TERRAIN_SECONDARY_ROTATION*parallax*(TERRAIN_SECONDARY_SCALE/TERRAIN_PRIMARY_SCALE);
  vec3 grass=sample_ground(grass_color,shifted,shifted_wide,dx,dy,wx,wy,scale_blend).rgb;
  vec3 soil=sample_ground(soil_color,shifted,shifted_wide,dx,dy,wx,wy,scale_blend).rgb;
  vec3 litter=sample_ground(forest_color,shifted,shifted_wide,dx,dy,wx,wy,scale_blend).rgb;
  float growth=smoothstep(0.29,0.71,drainage);
  grass*=mix(vec3(0.95,0.91,0.77),vec3(0.78,1.02,0.91),growth);
  soil*=mix(vec3(0.76,0.72,0.65),vec3(1.27,1.11,0.94),smoothstep(0.24,0.72,heights.y));
  soil=mix(soil,grass*vec3(1.12,0.94,0.80),0.15);
  litter*=mix(vec3(1.21,0.99,0.76),vec3(0.84,1.04,0.84),moss);
  litter=mix(litter,grass*vec3(0.85,1.0,0.76),smoothstep(0.44,0.78,drainage)*0.29);
  vec3 photo=grass*weights.x+soil*weights.y+litter*weights.z;
  photo=mix(photo,photo*local_ground.rgb*2.0,0.20);
  photo*=mix(1.0,0.92+0.18*height,relief)*(1.0-damp*0.18);
  vec3 surface_normal=vec3(0.5,0.5,1.0);
  float material_detail=1.0-smoothstep(59.0,91.0,distance_to_camera);
  if(detail_maps_ready && material_detail>0.0){
   vec3 measured_normal=textureGrad(grass_normal,shifted,dx,dy).xyz*weights.x
                       +textureGrad(soil_normal,shifted,dx,dy).xyz*weights.y
                       +textureGrad(forest_normal,shifted,dx,dy).xyz*weights.z;
   measured_normal.xy=transpose(TERRAIN_ROTATION)*(measured_normal.xy-0.5)+0.5;
   surface_normal=mix(surface_normal,measured_normal,material_detail);
   vec3 roughness=vec3(textureGrad(grass_rough,shifted,dx,dy).r,
                       textureGrad(soil_rough,shifted,dx,dy).r,
                       textureGrad(forest_rough,shifted,dx,dy).r);
   ROUGHNESS=mix(0.94,clamp(dot(roughness,weights),0.65,1.0),photo_strength*material_detail);
  }
  // Resolve smaller blades, leaf litter and pebbles near the camera using a
  // second octave of the packed photographic height maps. Mips handle minification.
  float close_detail=1.0-smoothstep(18.0,70.0,distance_to_camera);
  if(close_detail>0.0){
   vec2 grain_uv=TERRAIN_SECONDARY_ROTATION*uv*2.0+vec2(0.63,0.11);
   vec2 grain_dx=TERRAIN_SECONDARY_ROTATION*dx*2.0,grain_dy=TERRAIN_SECONDARY_ROTATION*dy*2.0;
   float grain=dot(textureGrad(ground_height_maps,grain_uv,grain_dx,grain_dy).rgb,weights);
   float grain_x=dot(textureGrad(ground_height_maps,grain_uv+vec2(0.005,0.0),grain_dx,grain_dy).rgb,weights);
   float grain_y=dot(textureGrad(ground_height_maps,grain_uv+vec2(0.0,0.005),grain_dx,grain_dy).rgb,weights);
   float contact=clamp((grain-0.5)*0.65+(height-grain)*0.17,-0.22,0.22);
   photo*=1.0+contact*close_detail;
   vec2 grain_slope=transpose(TERRAIN_SECONDARY_ROTATION*TERRAIN_ROTATION)*vec2(grain-grain_x,grain-grain_y);
   surface_normal.xy+=grain_slope*0.40*close_detail;
   ROUGHNESS=clamp(ROUGHNESS+(0.5-grain)*0.13*close_detail,0.62,1.0);
  }
  surface=mix(distant,photo,photo_strength);
  NORMAL_MAP=clamp(surface_normal,vec3(0.0),vec3(1.0));
  NORMAL_MAP_DEPTH=0.46*photo_strength;
 }
 float exposed_slope=smoothstep(.055,.34,slope+(meadow-.5)*.071)*smoothstep(.73,4.2,ground_height);
 float cliff_height=max(ground_height,relief_height*.73);
 float upland=smoothstep(14.0,36.0,cliff_height+(meadow-.52)*12.0);
 float rock_face=max(exposed_slope,upland*(.65+.30*smoothstep(.26,.75,organic)));
 if(rock_face>.005){
  vec2 face=vec2(relief_height*.23+q.x*.047+q.y*.036,q.y*.046-q.x*.033);
  vec2 bends=terrain_bend(patch*.073,vec2(19.3,36.2))*2.3;
  float bedding=.67*cloud_noise(face+bends)+.33*cloud_noise(face*2.37+bends*.88+vec2(16.1,11.4));
  float strata=.53+bedding*.47;
  vec3 rock=mix(vec3(.26,.24,.20),vec3(.47,.435,.37),clamp(strata,0.0,1.0));
  float rock_detail=(1.0-smoothstep(104.0,210.0,distance_to_camera))*rock_face;
  if(detail_maps_ready && rock_detail>0.0){
   vec2 ridge=vec2(cl*.23,relief_height+q.x*.12+q.y*.07-cl*.08);
   vec3 first=texture(cliff_color,vec2(q.x*.32,0.0)+ridge*.36).rgb;
   vec3 second=texture(cliff_color,vec2(q.y*.31,0.0)+ridge*.34+vec2(.36,.63)).rgb;
   vec3 upper=texture(cliff_color,vec2(q.x*.315,q.y*.286)+vec2(.58,.18)*cloud_noise(q*.126)).rgb;
   vec3 orientation=land_normal*land_normal;
   vec3 fragments=upper*orientation.y+first*orientation.z+second*orientation.x;
   float depth=dot(fragments,vec3(.22,.68,.10));
   float cracks=smoothstep(.10,.48,depth*.8+bedding*.2);
   rock=mix(rock,rock*(.52+.81*fragments)+vec3(.017,.012,.008),rock_detail);
   NORMAL=material_relief_normal(VERTEX,NORMAL,(cracks*.033+bedding*.019)*rock_detail);
  }
  float lichen=meadow*smoothstep(.52,.80,organic)*mix(.52,1.0,damp);
  rock=mix(rock,vec3(.29,.33,.20),lichen*.44);
  surface=mix(surface,rock,rock_face*.89);
  NORMAL_MAP_DEPTH*=1.0-rock_face;
  ROUGHNESS=mix(ROUGHNESS,.87,rock_face);
 }
 if(dry_terrain>.001) {
  vec2 drift=vec2(q.x*.38+q.y*.92,q.y*.30-q.x*.46);
  float texture_strength=1.0-smoothstep(.31,1.5,length(fwidth(drift)));
  vec2 windswept=drift+terrain_bend(drift*.18,vec2(22.5,9.3))*.92;
  float ripples=cloud_noise(windswept*vec2(4.4,.73)+vec2(2.4,7.9));
  float texture_mix=mix(.50,ripples,texture_strength*(1.0-rock_face)*.34);
  float dune_face=smoothstep(.21,.82,drainage*.55+texture_mix*.16+cl*.29);
  vec3 dry_ground=desert_grains(climate,dune_face,rock_face)*(.88+organic*.16+cl2*.14);
  dry_ground=mix(dry_ground,surface,clamp(.14+rock_face*.56,0.0,1.0));
  surface=mix(surface,dry_ground,dry_terrain);
 }
 float snow_cover=climate_snow(climate,slope,organic)*smoothstep(.36,1.02,ground_height);
 if(snow_cover>.001){
  float crust=smoothstep(.28,.76,organic*.72+cl2*.28);
  vec3 snow=snow_grains(clamp(meadow*.57+crust*.43,0.0,1.0),crust);
  surface=mix(surface,snow,snow_cover);
  NORMAL_MAP_DEPTH*=1.0-snow_cover*.74;
  ROUGHNESS=mix(ROUGHNESS,.82,snow_cover);
 }
 float sand=1.0-smoothstep(0.12+beach_wobble,0.83+beach_wobble,ground_height);
 if(sand>0.0){
  float grains=dot(textureGrad(soil_color,uv,dx,dy).rgb,vec3(0.31,0.57,0.12));
  float relief=textureGrad(ground_height_maps,uv,dx,dy).g;
  float grain_amount=1.0-smoothstep(115.0,280.0,distance_to_camera);
  float moisture=(1.0-smoothstep(-0.075,0.33,ground_height))*0.78;
  vec3 shore=mix(sand_color.rgb,wet_sand_color.rgb,moisture);
  shore*=0.65+0.25*fractal(patch*0.11)+grain_amount*(grains*0.39+relief*0.15-0.13);
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
