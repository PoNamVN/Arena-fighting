shader_type spatial;

uniform vec4 metal_color : source_color = vec4(0.6, 0.67, 0.74, 1.0);
uniform float metalness = 0.85;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float grain = fract(sin(dot(floor(local_position * 5.0), vec3(12.9898, 78.233, 45.164))) * 43758.5453);
	if (dissolve > 0.0 && grain < dissolve) { discard; }
	ALBEDO = metal_color.rgb;
	METALLIC = metalness;
	ROUGHNESS = 0.3;
	if (dissolve > 0.0 && grain < dissolve + 0.07) {
		EMISSION = vec3(2.0, 0.6, 0.08);
	}
}
