shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float shade_floor : hint_range(0.0, 1.0) = 0.30;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 flash_color : source_color = vec4(0.0);

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex.rgb;
	ROUGHNESS = 0.75;
	SPECULAR = 0.2;

	// View-space fresnel rim lighting
	float NdotV = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.60, 0.95, NdotV) * rim_strength;

	// Flash color uniform added to EMISSION
	EMISSION = rim_color.rgb * rim + flash_color.rgb * flash_color.a;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float light_step = smoothstep(-0.02, 0.06, NdotL);
	float toon_factor = mix(shade_floor, 1.0, light_step);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * toon_factor;
}
