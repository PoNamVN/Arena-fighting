shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float radius = 1.0;
uniform float width = 3.0;
uniform float height = 2.0;
uniform float opacity = 0.0;
uniform float flow = 0.0;
uniform sampler2D noise_texture : filter_linear, repeat_enable;
void vertex() {
 float r = radius + (UV.y - .5) * width;
 VERTEX.xz *= max(.1, r);
 VERTEX.y = .15 + sin(UV.y * 3.14159265) * height;
}
void fragment() {
 float n = texture(noise_texture, vec2(UV.x * 8.0 - flow * .16, UV.y * 1.2 + flow * .32)).r;
 float curl = sin(UV.x * 62.83185 + flow * 3.0) * .045;
 float rim = exp(-pow((UV.y - .53 + curl) / .10, 2.0));
 float wisps = smoothstep(.48, .72, n);
 float edge = sin(UV.y * 3.14159265);
 ALBEDO = vec3(.82, .85, .84);
 ALPHA = smoothstep(.5, 2.5, length(VERTEX)) * opacity * edge * (rim * .22 * smoothstep(.32, .64, n) + wisps * .10);
}
