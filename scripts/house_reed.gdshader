shader_type spatial;
render_mode cull_disabled, diffuse_burley;

#include "res://scripts/material_relief.gdshaderinc"

uniform sampler2D reed_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 reed_tint : source_color = vec4(0.46, 0.42, 0.36, 1.0);
varying vec3 surface_world;

void vertex() {
 surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
