shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 vapor_tint : source_color = vec4(0.39, 0.35, 0.32, 0.31);
uniform float phase = 0.0;
float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453);
}
float noise21(vec2 p) {
	vec2 c=floor(p);
	vec2 t=fract(p);
	t=t*t*(3.0-2.0*t);
	return mix(mix(hash21(c),hash21(c+vec2(1.0,0.0)),t.x),
		mix(hash21(c+vec2(0.0,1.0)),hash21(c+1.0),t.x),t.y);
}
void vertex() {
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
}
void fragment() {
	float y=1.0-UV.y;
	float clock=mod(TIME*0.26+phase,630.0);
	float drift=y*y*(0.21+0.06*sin(clock*1.7+y*7.0));
	float radius=mix(0.035,0.42,y);
	float taper=smoothstep(0.0,0.10,y)*(1.0-smoothstep(0.47,1.0,y));
	vec2 p=vec2(UV.x*6.5-y*1.3,y*5.2-clock);
	float grain=0.64*noise21(p)+0.23*noise21(p*2.0)+0.13*noise21(p*4.3);
	float body=1.0-smoothstep(radius*0.25,radius,abs(UV.x-0.5-drift));
	float edge=1.0-smoothstep(0.38,0.49,abs(UV.x-0.5));
	ALBEDO=vapor_tint.rgb*(0.78+grain*0.38);
	ALPHA=body*taper*edge*smoothstep(0.25,0.67,grain)*vapor_tint.a;
}

