shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 tunic_color : source_color = vec4(0.239216, 0.231373, 0.411765, 1.0);
uniform vec2 hem_offset = vec2(0.0);
uniform mat3 cloth_basis = mat3(1.0);
uniform vec3 leg_start[4];
uniform vec3 leg_end[4];
uniform vec4 leg_radius = vec4(0.13, 0.13, 0.11, 0.11);
uniform bool cloth_enabled = true;

vec3 avoid_leg(vec3 point, vec3 a, vec3 b, float radius, vec3 fallback) {
 vec3 axis = b - a;
 float t = clamp(dot(point - a, axis) / max(dot(axis, axis), 0.00001), 0.0, 1.0);
 vec3 closest = a + axis * t;
 vec3 away = point - closest;
 float distance_to_leg = length(away);
 if (distance_to_leg < radius) {
  return closest + (distance_to_leg > 0.0001 ? away / distance_to_leg : fallback) * radius;
 }
 return point;
}

void vertex() {
 // Exported alpha is a cloth mask, not transparency. All other vertices have zero.
 float mask = clamp(COLOR.a, 0.0, 1.0);
 if (cloth_enabled && mask > 0.001) {
  vec3 offset = cloth_basis * vec3(hem_offset.x, 0.0, hem_offset.y);
  VERTEX += offset * mask * mask;
  vec3 fallback = normalize(cloth_basis * vec3(0.0, 0.0, 1.0));
  // Two short passes prevent projecting out of one leg into the other.
  for (int pass_index = 0; pass_index < 2; pass_index++) {
   for (int i = 0; i < 4; i++) {
    VERTEX = avoid_leg(VERTEX, leg_start[i], leg_end[i], leg_radius[i], fallback);
   }
  }
 }
}

void fragment() {
 ALBEDO = tunic_color.rgb;
 ROUGHNESS = 0.95;
 METALLIC = 0.0;
 SPECULAR = 0.5;
}
