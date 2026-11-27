shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://scripts/painted_relief.gdshaderinc"

uniform sampler2D leaf_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D bark_color : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 tree_position;
varying vec3 tree_facing;

void vertex() {
	tree_position = VERTEX;
	tree_facing = NORMAL;
}

void fragment() {
	vec3 facing = abs(tree_facing);
	vec2 side = vec2(facing.x > facing.z ? tree_position.z : tree_position.x, tree_position.y);
	if (COLOR.a > 0.5) {
		vec2 planar = mix(side,tree_position.xz,smoothstep(0.37,0.82,facing.y));
		vec3 leaves = texture(leaf_color, planar * 0.91).rgb;
		float brush = dot(leaves, vec3(0.27, 0.65, 0.08));
		float foliage = smoothstep(0.055,0.25,brush);
		ALBEDO = COLOR.rgb * mix(vec3(0.68,0.80,0.76),vec3(1.30,1.18,1.10),foliage);
		NORMAL = painted_relief(VERTEX,NORMAL,foliage,0.025);
		ROUGHNESS = 0.92;
		SPECULAR = 0.22;
	} else {
		vec3 bark = texture(bark_color, vec2(side.y * 0.29, side.x * 1.1)).rgb;
		float brush = dot(bark, vec3(0.30, 0.59, 0.11));
		ALBEDO = COLOR.rgb * (0.74 + 0.79 * brush);
		ROUGHNESS = 0.91;
		SPECULAR = 0.18;
	}
}
