shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment() {
	float streak = sin(UV.x * 28.0 + UV.y * 17.0 - TIME * 6.0) * sin(UV.y * 25.0 + TIME * 4.0);
	float veins = smoothstep(0.35, 0.9, streak);
	float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.0);
	ALBEDO = mix(vec3(1.0, 0.12, 0.015), vec3(1.0, 0.85, 0.25), veins) * (1.0 - edge * 0.25);
}
