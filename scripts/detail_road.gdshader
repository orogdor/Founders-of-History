shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://scripts/surface_relief.gdshaderinc"

uniform sampler2D road_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 road_tint : source_color = vec4(1.0);
uniform float tiles_per_meter = 0.5;
uniform float relief_depth = 0.02;
uniform float surface_roughness = 0.94;
uniform float photo_brightness = 1.0;
uniform float shoulder_variation = 0.15;
instance uniform vec2 road_uv_offset = vec2(0.0);

varying vec2 road_uv;

void vertex() {
	road_uv = (UV + road_uv_offset) * tiles_per_meter;
}

void fragment() {
	vec2 dx = dFdx(road_uv);
	vec2 dy = dFdy(road_uv);
	float distance_to_camera = length(VERTEX);
	float detail = 1.0 - smoothstep(105.0, 220.0, distance_to_camera);
	float edge = length(UV2);
	float height = 0.5;
	vec3 color = road_tint.rgb;
	NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.0;
	if (detail > 0.0) {
		height = textureGrad(road_height, road_uv, dx, dy).r;
		float depth = relief_depth * (1.0 - smoothstep(14.0, 48.0, distance_to_camera));
		vec2 shifted = road_uv - relief_direction(VIEW, TANGENT, BINORMAL, NORMAL) * (1.0 - height) * depth;
		vec3 photo = textureGrad(road_color, shifted, dx, dy).rgb;
		color = mix(color, photo * photo_brightness, detail * 0.68);
		color *= mix(1.0, 0.87 + 0.24 * height, detail);
		NORMAL_MAP = textureGrad(road_normal, shifted, dx, dy).rgb;
		NORMAL_MAP_DEPTH = detail * 0.65;
	}
	// Use the height texture to break up the shoulder without a transparent overlay.
	if (edge > 0.97 - shoulder_variation * (1.0 - height) * detail) {
		discard;
	}
	ALBEDO = color * (1.0 - 0.12 * smoothstep(0.65, 1.0, edge));
	ROUGHNESS = surface_roughness;
}
