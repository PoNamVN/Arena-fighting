shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float flow = 0.0;
uniform float opacity = 0.0;
uniform float layer = 0.0;
uniform float turbulence = 1.0;
uniform vec3 dust_color : source_color = vec3(.55, .50, .43);
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
void vertex() {
 vec3 world = MODEL_MATRIX[3].xyz + INV_VIEW_MATRIX[0].xyz * VERTEX.x * length(MODEL_MATRIX[0].xyz) + INV_VIEW_MATRIX[1].xyz * VERTEX.y * length(MODEL_MATRIX[1].xyz);
 VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}
void fragment() {
 vec2 p = (UV - .5) * 2.0;
 vec2 drift = vec2(-flow * .18 + layer * .317, flow * .11 + layer * .719);
 vec2 curl = vec2(sin(UV.y * 7.0 + flow * 2.8 + layer), cos(UV.x * 8.0 - flow * 2.1)) * .06 * turbulence;
 float n = texture(noise_texture, UV * 2.1 + drift + curl).r;
 float detail = texture(noise_texture, UV * 5.7 - drift * .65).r;
 float edge = 1.0 - smoothstep(.28, 1.02, length(p) + (.5 - n) * .36);
 float density = smoothstep(.12, .72, n * .76 + detail * .24);
 ALBEDO = dust_color * mix(.46, 1.12, n * .65 + UV.y * .35);
 ALPHA = opacity * edge * (.45 + .55 * density);
}
