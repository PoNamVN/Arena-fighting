shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.25, 0.65, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.65;
uniform float style = 0.0;

float line(float d, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(d));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float aa = max(fwidth(r) * 1.5, 0.003);
	float outer = line(r - 0.90, 0.012, aa);
	float inner = line(r - 0.73, 0.007, aa);
	float ticks = line(sin(a * 24.0), 0.12, aa * 20.0) * smoothstep(0.76, 0.79, r) * (1.0 - smoothstep(0.86, 0.88, r));
	float arcs = line(r - 0.61, 0.015, aa) * smoothstep(-0.2, 0.25, sin(a * 6.0 + TIME * 1.8));
	float star = line(abs(p.x * cos(0.523599) + p.y * sin(0.523599)) + abs(p.y * cos(0.523599) - p.x * sin(0.523599)) - 0.61, 0.007, aa);
	float core = line(r - 0.32, 0.008, aa);
	float sigil = outer + inner + ticks + arcs + star * 0.65 + core;
	float wave = outer + inner * 0.6 + exp(-abs(r - 0.86) * 28.0) * 0.16;
	float value = mix(sigil, wave, step(0.5, style));
	if (style > 1.5) {
		float sweep = smoothstep(-0.35, 0.65, sin(a * 3.0 - TIME * 13.0));
		value = line(r - 0.85, 0.04, aa) * sweep + line(r - 0.69, 0.012, aa) * (1.0 - sweep) * 0.6;
	}
	value *= 1.0 - smoothstep(0.96, 1.0, r);
	ALBEDO = tint.rgb * (0.8 + clamp(value, 0.0, 1.0) * 0.2);
	ALPHA = clamp(value, 0.0, 1.0) * opacity * tint.a;
}
