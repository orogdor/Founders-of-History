shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glow_color : source_color=vec4(1.0,.71,.40,1.0);
uniform float power=0.0;
uniform float flicker=1.0;

void fragment() {
 vec2 offset=UV*2.0-1.0;
 float distance_squared=dot(offset,offset);
 float phase=COLOR.r*6.28319;
 float change=.92+flicker*(.08*sin(phase+TIME*8.2)+.041*sin(phase*1.93-TIME*13.7));
 float falloff=exp(-distance_squared*mix(4.3,2.7,COLOR.g))*(1.0-smoothstep(.52,1.0,distance_squared));
 ALBEDO=glow_color.rgb;
 ALPHA=power*change*falloff*.105;
}
