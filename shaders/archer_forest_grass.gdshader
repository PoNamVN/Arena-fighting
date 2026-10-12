shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform vec3 hunter_position;
uniform vec3 travel_direction = vec3(0.0, 0.0, -1.0);
uniform float hunter_active = 0.0;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float height = max(0.0, VERTEX.y - root.y);
	float tip = clamp(height / 1.25, 0.0, 1.0);
	vec2 forward = normalize(travel_direction.xz + vec2(0.00001));
	vec2 side = vec2(-forward.y, forward.x);
	vec2 offset = root.xz - hunter_position.xz;
	float lateral = dot(offset, side);
	float longitudinal = dot(offset, forward);
	float passage = (1.0 - smoothstep(0.25, 1.1, abs(lateral)))
		* (1.0 - smoothstep(0.45, 1.6, abs(longitudinal))) * hunter_active;
	// Reversing travel flips both side and lateral, preserving the same open corridor.
	vec2 opening = side * (lateral < 0.0 ? -1.0 : 1.0);
	VERTEX.xz += opening * passage * tip * tip * 0.8;
	VERTEX.y -= passage * tip * tip * 0.32;
	float breeze = sin(TIME * 1.7 + root.x * 0.65 + root.z * 0.9 + INSTANCE_CUSTOM.x);
	VERTEX.xz += vec2(0.065, 0.045) * breeze * tip * tip;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.25));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	BACKLIGHT = COLOR.rgb * 0.3;
}
