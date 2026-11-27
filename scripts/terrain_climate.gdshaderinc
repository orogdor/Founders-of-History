uniform sampler2D climate_map : filter_linear, repeat_disable;
uniform bool climate_ready=false;

vec3 ground_climate(vec2 cell,bool overview) {
	if (!climate_ready) return vec3(0.0);
	vec2 size=vec2(textureSize(climate_map,0));
	return texture(climate_map,cell/size+(overview?vec2(.5):vec2(.5)/size)).rgb;
}

float climate_dry(vec3 climate) {
	return smoothstep(.27,.91,climate.r);
}

float climate_snow(vec3 climate,float slope,float texture_variation) {
	float cover=smoothstep(.11,.98,climate.g+(texture_variation-.51)*.31);
	return cover*(1.0-smoothstep(.14,.59,slope));
}

vec3 desert_grains(vec3 climate,float bright,float rock) {
	vec3 quartz=mix(vec3(.33,.245,.151),vec3(.65,.501,.304),bright);
	vec3 sandstone=mix(vec3(.29,.159,.102),vec3(.56,.344,.205),bright);
	return mix(quartz,sandstone,climate.b)*mix(.92,1.04,rock);
}

vec3 snow_grains(float bright,float crust) {
	return mix(vec3(.48,.565,.625),vec3(.76,.81,.81),bright)*mix(.91,1.03,crust);
}
