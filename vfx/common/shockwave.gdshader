shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.4,0.35,0.25,0.6);
uniform float opacity = 0.0;
void fragment() {
 float r = length(UV);
 float edge = smoothstep(0.88,0.91,r)*(1.0-smoothstep(0.97,1.0,r));
 ALBEDO = tint.rgb;
 ALPHA = tint.a * opacity * edge;
}
