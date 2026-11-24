const mat2 TERRAIN_ROTATION = mat2(vec2(0.846,0.533),vec2(-0.533,0.846));
const mat2 TERRAIN_SECONDARY_ROTATION = mat2(vec2(0.601,-0.799),vec2(0.799,0.601));
const float TERRAIN_SECONDARY_SCALE = 0.271;

vec2 terrain_primary_uv(vec2 world) {
	vec2 bend = vec2(cloud_noise(world*0.073+vec2(23.4,9.0)),cloud_noise(world*0.073+vec2(47.1,61.5)));
	return TERRAIN_ROTATION*(world*0.51) + bend*2.35;
}

vec2 terrain_secondary_uv(vec2 world) {
	vec2 bend = vec2(cloud_noise(world*0.109+vec2(21.1,77.3)),cloud_noise(world*0.109+vec2(37.8,14.9)));
	return TERRAIN_SECONDARY_ROTATION*(world*TERRAIN_SECONDARY_SCALE) + bend*1.47;
}

float terrain_layer_mix(vec2 world) {
	return 0.30 + 0.41*cloud_noise(world*0.037+vec2(126.2,40.1));
}
