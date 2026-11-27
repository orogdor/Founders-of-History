const mat2 TERRAIN_ROTATION = mat2(vec2(0.846,0.533),vec2(-0.533,0.846));
const mat2 TERRAIN_SECONDARY_ROTATION = mat2(vec2(0.601,-0.799),vec2(0.799,0.601));
const float TERRAIN_PRIMARY_SCALE = 0.635;
const float TERRAIN_SECONDARY_SCALE = 0.238;

// Both projections bend continuously in world space, keeping their texture
// alignment across streamed tile boundaries and camera origin changes.
vec2 terrain_bend(vec2 world, vec2 offset) {
	return vec2(cloud_noise(world + offset), cloud_noise(world + offset.yx + vec2(18.4, 41.6))) - 0.5;
}

vec2 terrain_primary_uv(vec2 world) {
	vec2 broad = terrain_bend(world*0.034, vec2(23.4,9.0));
	vec2 fine = terrain_bend(world*0.103, vec2(68.5,11.4));
	return TERRAIN_ROTATION*(world*TERRAIN_PRIMARY_SCALE) + broad*2.64 + fine*0.91;
}

vec2 terrain_secondary_uv(vec2 world) {
	vec2 bend = terrain_bend(world*0.054, vec2(21.1,77.3));
	return TERRAIN_SECONDARY_ROTATION*(world*TERRAIN_SECONDARY_SCALE) + bend*1.71;
}

float terrain_layer_mix(vec2 world) {
	float mask = cloud_noise(world*0.14+vec2(126.2,40.1))*0.68
	           + cloud_noise(world*0.046+vec2(24.2,103.7))*0.32;
	return mix(0.11,0.92,smoothstep(0.28,0.73,mask));
}
