shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength=0.0;
uniform float flow=0.0;
void fragment() {
 float edge=pow(max(0.0,sin(UV.y*3.14159265)),1.2);
 float envelope=smoothstep(.01,.12,UV.x)*(1.0-smoothstep(.85,1.0,UV.x));
 float streak=pow(max(0.0,sin((UV.x-flow*.22+COLOR.r*.16)*28.0)),2.0);
 ALBEDO=mix(vec3(.65,.69,.71),vec3(.94,.95,.94),streak);
 ALPHA=strength*edge*envelope*(.14+.65*streak);
}
