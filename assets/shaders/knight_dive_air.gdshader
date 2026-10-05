shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength = 0.0;
uniform float flow = 0.0;
uniform bool ring = false;
void fragment() {
 float edge = pow(max(0.0, sin(UV.y * 3.14159265)), 1.5);
 float alpha;
 if (ring) {
  float broken = smoothstep(-0.3, 0.45, sin(UV.x * 31.4159 + flow * 3.0));
  alpha = edge * broken;
 } else {
  float band = pow(max(0.0, sin((UV.x - flow + UV.y * 0.13) * 16.0)), 3.0);
  alpha = edge * sin(UV.x * 3.14159) * (0.12 + 0.88 * band);
 }
 ALBEDO = vec3(0.88, 0.88, 0.83);
 ALPHA = strength * alpha;
}
