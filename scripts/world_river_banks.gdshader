shader_type spatial;
render_mode cull_disabled, depth_draw_never;

#include "res://scripts/water_surface.gdshaderinc"

varying vec2 bank_world;

void vertex() {
	bank_world=VERTEX.xz*25.0;
}

void fragment() {
	float damp=water_noise(bank_world*.44);
	float sediment=water_noise(bank_world*.13+vec2(8.2,41.3));
	ALBEDO=COLOR.rgb*(.85+.23*damp+sediment*.11);
	ALPHA=COLOR.a*mix(.67,.90,sediment);
	ROUGHNESS=mix(.96,.82,COLOR.a);
}
