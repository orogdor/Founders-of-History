shader_type spatial;
render_mode cull_disabled, diffuse_burley;
#include "res://scripts/painted_relief.gdshaderinc"

uniform sampler2D painted_reed : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
 vec4 reed = texture(painted_reed, UV);
 ALBEDO = reed.rgb * vec3(0.91, 0.94, 1.0);
 NORMAL = painted_relief(VERTEX, NORMAL, reed.a, 0.028);
 ROUGHNESS = 0.87;
 SPECULAR = 0.25;
}
