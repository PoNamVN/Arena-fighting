shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength = 0.0;
uniform float flow = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void fragment() {
 float vertical = smoothstep(0.0, .18, UV.y) * (1.0 - smoothstep(.7, 1.0, UV.y));
 float cloud = noise(vec2(UV.x * 12.0, UV.y * 2.0 - flow * .025));
 float rays = smoothstep(.25, .85, cloud);
 float feather = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.7);
 ALBEDO = vec3(1.0, .96, .83);
 EMISSION = vec3(1.0, .91, .70) * strength * .8;
 ALPHA = strength * vertical * feather * (.008 + rays * .065);
}
