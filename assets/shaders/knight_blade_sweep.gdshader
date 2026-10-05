shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
 float edge=pow(max(0.0,sin(UV.x*3.14159265)),.7);
 float head=1.0-smoothstep(.65,1.0,UV.y);
 ALBEDO=tint.rgb;
 ALPHA=tint.a*edge*(.25+.75*head);
}
