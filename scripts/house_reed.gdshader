shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D reed_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 reed_tint : source_color = vec4(0.46, 0.42, 0.36, 1.0);
uniform bool settlement_detail = false;
uniform bool hut_thatch = false;
uniform sampler2D hut_height_map : filter_linear_mipmap, repeat_disable;
uniform bool has_hut_height_map = false;
varying vec3 surface_world;
varying float roof_age;

void vertex() {
 surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 vec2 foundation=mod(MODEL_MATRIX[3].xz+vec2(112.5,97.5),vec2(225.0,195.0));
 roof_age=fract(sin(dot(floor(foundation*2.0),vec2(9.35,17.19)))*14719.3);
}

vec2 reed_hash(vec2 p) {
 vec3 v = fract(p.xyx * vec3(0.1031, 0.1030, 0.0973));
 v += dot(v, v.yzx + vec3(33.33));
 return fract((v.xx + v.yz) * v.zy);
}

vec3 reed_sample(vec2 cell, vec2 uv) {
 vec2 random = reed_hash(cell);
 float variant = min(4.0, floor(random.x * 5.0));
 vec2 local_uv = fract(uv + random * 7.7);
 vec2 atlas_uv = (local_uv * 512.0 + vec2(8.0) + vec2(variant * 528.0, 0.0)) / vec2(2640.0, 528.0);
 vec2 atlas_scale = vec2(512.0) / vec2(2640.0, 528.0);
 return textureGrad(reed_atlas, atlas_uv, dFdx(uv)*atlas_scale, dFdy(uv)*atlas_scale).rgb;
}

void fragment() {
 if (hut_thatch) {
  float roof_run = clamp(UV.y / 2.3, 0.0, 1.0);
  vec2 bundles = UV * vec2(2.8, 1.22);
  bundles.x += sin(UV.x * 18.5 + UV.y * 5.7) * 0.023;
  vec2 page = vec2(512.0) / vec2(2640.0, 528.0);
  vec2 coordinates = (fract(bundles + vec2(0.11, 0.44)) * 512.0 + vec2(2.0 * 528.0 + 8.0, 8.0)) / vec2(2640.0, 528.0);
  vec2 dx = dFdx(bundles) * page, dy = dFdy(bundles) * page;
  vec3 reed = textureGrad(reed_atlas, coordinates, dx, dy).rgb;
  float grain = dot(reed, vec3(0.23, 0.69, 0.08));
  float weather = 0.48 + 0.25 * sin(surface_world.x * 0.68 + surface_world.y * 1.23)
                      * sin(surface_world.z * 1.04 - surface_world.y * 0.92)
                      + 0.12 * sin(surface_world.z * 2.4 + surface_world.x * 1.47);
  float grain_detail = 1.0 - smoothstep(15.0, 54.0, length(VERTEX));
  float strand = sin(UV.x * 493.0 + sin(UV.x * 87.0) * 0.85 + sin(UV.y * 6.3 + UV.x * 7.2) * 0.72);
  strand *= grain_detail * (1.0 - smoothstep(0.14, 1.25, fwidth(UV.x) * 493.0));
  float overlap = fract(roof_run * 5.0 + sin(UV.x * 11.2) * 0.057 + sin(UV.x * 27.6 + UV.y) * 0.028);
  float lip = 1.0 - smoothstep(0.025, 0.15, overlap);
  float cut = 1.0 - smoothstep(-0.13, -0.003, UV.y);
  float straw_tone = mix(smoothstep(0.045, 0.55, grain), weather, 0.40);
  vec3 clean = mix(vec3(.147,.108,.061),vec3(.56,.449,.283),straw_tone);
  vec3 aged = mix(vec3(.151,.137,.103),vec3(.51,.445,.335),straw_tone);
  float aged_amount=clamp(smoothstep(.18,.76,weather)*.46+roof_run*.18+roof_age*.29,0.0,1.0);
  vec3 straw=mix(clean,aged,aged_amount);
  float soot=1.0-smoothstep(.77,1.19,roof_run+(weather-.5)*.18);
  vec3 stems=mix(vec3(.128,.094,.063),vec3(.52,.449,.33),smoothstep(.12,.63,grain));
  float fray=smoothstep(-.116,-.033,UV.y+(weather-.50)*.044);
  stems*=.75+.25*fray+strand*.049;
  ALBEDO=mix(straw*(.88+.12*soot)*(1.0-lip*.16+strand*.077),stems,cut*.75);
  ROUGHNESS = clamp(0.96 - grain * 0.11, 0.85, 0.98);
  SPECULAR = 0.14;
  if (!settlement_detail) {
   float close_detail = 1.0 - smoothstep(12.0, 37.0, length(VERTEX));
   float relief = has_hut_height_map && close_detail > 0.0
                ? textureGrad(hut_height_map, coordinates, dx, dy).r : grain;
   NORMAL = material_relief_normal(VERTEX, NORMAL, close_detail * (relief * 0.012 + strand * 0.0025 - lip * 0.007));
  }
 } else if (settlement_detail) {
  vec3 straw = reed_sample(vec2(3.0, 9.0), UV);
  float tone = 0.94 + sin(surface_world.x * 1.08 + surface_world.z * 0.69) * 0.06;
  ALBEDO = (straw * vec3(0.78, 0.74, 0.64) + vec3(0.028, 0.018, 0.010)) * tone;
  ROUGHNESS = 0.90;
  SPECULAR = 0.17;
 } else {
 vec2 position = vec2(surface_world.x + 0.51 * surface_world.z + 0.32 * surface_world.y,
                      surface_world.z - 0.27 * surface_world.x + 0.81 * surface_world.y) * 0.94;
 vec2 cell = floor(position);
 vec2 blend = smoothstep(vec2(0.11), vec2(0.89), fract(position));
 vec3 color = reed_sample(cell, UV) * (1.0 - blend.x) * (1.0 - blend.y)
            + reed_sample(cell + vec2(1.0, 0.0), UV) * blend.x * (1.0 - blend.y)
            + reed_sample(cell + vec2(0.0, 1.0), UV) * (1.0 - blend.x) * blend.y
            + reed_sample(cell + vec2(1.0, 1.0), UV) * blend.x * blend.y;
 float wear = 0.93 + 0.07 * sin(surface_world.x * 0.33 + surface_world.z * 0.41);
 float mottling = sin(surface_world.x * 1.12 + sin(surface_world.z * 2.22))
                * sin(surface_world.y * 2.78 - surface_world.z * 1.29);
 float grain = dot(color, vec3(0.22, 0.70, 0.08));
 float visible_detail = 1.0 - smoothstep(18.0, 72.0, length(VERTEX));
 float strands = sin(UV.x * 365.0 + sin(UV.y * 18.0) * 0.37);
 float strand_footprint = fwidth(UV.x) * 365.0;
 strands *= 1.0 - smoothstep(0.48, 1.85, strand_footprint);
 float texture_height = grain * 0.032 + strands * 0.0018;
 NORMAL = material_relief_normal(VERTEX, NORMAL, visible_detail * texture_height);
 vec3 weathering = mix(vec3(0.82, 0.84, 0.86), vec3(1.22, 1.12, 0.95), smoothstep(0.15, 0.62, grain));
 ALBEDO = color * reed_tint.rgb * weathering * wear * (1.0 + 0.14 * mottling)
        * (1.0 + visible_detail * (0.24 * (grain - 0.42) + 0.078 * strands));
 ROUGHNESS = clamp(0.92 - grain * 0.10, 0.78, 0.95);
 SPECULAR = 0.20;
 }
}
