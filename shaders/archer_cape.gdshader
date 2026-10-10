shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform vec4 albedo_color : source_color = vec4(0.18, 0.36, 0.22, 1.0);
uniform vec4 trim_color : source_color = vec4(0.92, 0.85, 0.65, 1.0);
uniform float shade_floor : hint_range(0.0, 1.0) = 0.38;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.24;
uniform vec4 rim_color : source_color = vec4(0.42, 0.62, 0.48, 1.0);
uniform vec4 flash_color : source_color = vec4(0.0);

uniform float flutter_amount : hint_range(0.0, 1.0) = 0.035;
uniform float flutter_speed : hint_range(0.0, 25.0) = 4.2;
uniform vec3 drag_offset = vec3(0.0);
uniform float cloth_weight_top : hint_range(0.0, 2.0) = 1.38;
uniform float cloth_weight_bottom : hint_range(0.0, 2.0) = 0.88;
uniform float somersault_tuck : hint_range(0.0, 1.0) = 0.0;
uniform bool is_dead = false;

varying float v_edge_norm;
varying float v_dist_norm;

void vertex() {
	// Cloth weight: smooth drape falloff (0.0 at pinned shoulders -> 1.0 at flowing hem)
	float span = max(cloth_weight_top - cloth_weight_bottom, 0.001);
	float dist_y = clamp(cloth_weight_top - VERTEX.y, 0.0, span);
	float raw_weight = dist_y / span;
	float weight = pow(raw_weight, 1.25);

	v_dist_norm = raw_weight;
	float current_half_w = 0.16 + 0.035 * sin(raw_weight * 3.14159) - 0.025 * raw_weight;
	v_edge_norm = clamp(abs(VERTEX.x) / max(current_half_w, 0.01), 0.0, 1.0);

	if (!is_dead) {
		float t = TIME * flutter_speed;

		// 0. Aerodynamic Somersault Tuck (Curls cape compactly against spine during backflip)
		if (somersault_tuck > 0.001) {
			VERTEX.y += dist_y * somersault_tuck * 0.48;
			VERTEX.z += somersault_tuck * 0.040 * weight;
		}
		
		// 1. Organic multi-harmonic cloth waves flowing downward along pleats
		float wave1 = sin(dist_y * 7.5 - t * 2.3);
		float wave2 = sin(VERTEX.x * 9.0 + dist_y * 4.5 - t * 3.0) * 0.30;
		float edge = smoothstep(0.04, 0.25, abs(VERTEX.x));
		float wave_edge = cos(dist_y * 8.5 - t * 3.6 + VERTEX.x * 6.0) * (0.15 + 0.30 * edge);
		
		float cloth_flutter = (wave1 * 0.55 + wave2 + wave_edge) * flutter_amount;

		// 2. Aerodynamic Drag & Lift
		float trail_z = drag_offset.z;
		float lift_y  = drag_offset.y;
		float sway_x  = drag_offset.x;

		// Wind billow: soft parabolic outward curve when moving
		float billow_arch = (1.0 - smoothstep(0.0, 0.28, abs(VERTEX.x))) * abs(drag_offset.z) * 0.25;

		// 3. Subtle organic horizontal sway & vertical breathing
		float natural_sway_x = sin(t * 1.3 + dist_y * 1.8) * 0.012 * weight;
		float natural_lift_y = cos(t * 1.6 + dist_y * 1.4) * 0.006 * weight;

		// Apply soft displacements weighted from shoulders down to hem
		VERTEX.z += (trail_z - billow_arch + cloth_flutter) * weight;
		VERTEX.y += (lift_y + natural_lift_y) * weight;
		VERTEX.x += (sway_x + natural_sway_x) * weight;

		// Soft repulsion boundary: keeps cape from penetrating back without rigid flattening
		float back_limit = -0.125;
		if (VERTEX.z > back_limit) {
			float over = VERTEX.z - back_limit;
			VERTEX.z = back_limit + over * 0.12;
		}
	}
}

void fragment() {
	// Base gradient: fresh bright forest green on top shoulders blending down to deep rich hunter green
	vec3 base_fabric = mix(albedo_color.rgb * 1.12, albedo_color.rgb * 0.88, v_dist_norm);

	// Golden/cream embroidered trim along the outer borders and scalloped hem
	float is_trim = max(smoothstep(0.82, 0.94, v_edge_norm), smoothstep(0.92, 0.99, v_dist_norm));
	ALBEDO = mix(base_fabric, trim_color.rgb, is_trim);

	ROUGHNESS = mix(0.86, 0.70, is_trim); // Tactile cloth with silky sheen on golden embroidery
	SPECULAR = mix(0.08, 0.25, is_trim);

	// Soft velvety fabric sheen on grazing angles
	float NdotV = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fabric_sheen = pow(NdotV, 2.5) * rim_strength;

	// Emission includes flash color on hit and subtle fabric rim
	EMISSION = rim_color.rgb * fabric_sheen + flash_color.rgb * flash_color.a;
}

void light() {
	// Soft half-Lambert wrap lighting for fabric diffusion
	float wrap = 0.40;
	float wrap_NdotL = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float soft_toon = smoothstep(0.18, 0.75, wrap_NdotL);
	float toon_factor = mix(shade_floor, 1.0, soft_toon);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * toon_factor;
}
