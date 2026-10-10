shader_type spatial;
render_mode cull_disabled;
uniform float growth = 0.0;
uniform float flow = 0.0;
void vertex() {
 float sprout = smoothstep(INSTANCE_CUSTOM.x, INSTANCE_CUSTOM.x + .25, growth);
 float stem = max(VERTEX.y, 0.0);
 sprout *= INSTANCE_CUSTOM.z;
 VERTEX *= sprout;
 VERTEX.x += sin(flow * 1.6 + INSTANCE_CUSTOM.y * 6.28318 + stem * 2.0) * stem * .08 * sprout;
}
void fragment() {
 ALBEDO = COLOR.rgb;
 ROUGHNESS = .85;
 BACKLIGHT = COLOR.rgb * .12;
}
