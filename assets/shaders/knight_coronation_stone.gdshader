shader_type spatial;
uniform vec4 stone_color : source_color = vec4(.3, .3, .3, 1.0);
uniform float fracture = 0.0;
uniform float radiance = 0.0;
uniform float growth = 0.0;
varying vec3 local_position;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise(vec3 p) {
 vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x), mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
 mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x), mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { local_position = VERTEX; }
float wrap_angle(float a) { return mod(a + 3.14159265, 6.2831853) - 3.14159265; }
float jagged(float height, float seed) {
 float cell = floor(height), t = fract(height);
 return mix(hash(vec3(cell, seed, 17)), hash(vec3(cell + 1.0, seed, 17)), t) * 2.0 - 1.0;
}
// Unequal faults radiate from the blade. Branches inherit their parent's path
// before splitting, so they form connected fractures rather than stripes.
vec2 cracks(vec3 p) {
 float depth = max(8.5 - p.y, 0.0), radius = length(p.xz);
 float angle = atan(p.z, p.x), opening = 0.0, lip = 0.0;
 for (int i = 0; i < 5; i++) {
  float seed = float(i) * 13.71 + 2.9;
  float direction = float(i) * 1.256637 + (hash(vec3(seed)) - .5) * .8;
  float bend = jagged(depth * .72, seed) * .16 + jagged(depth * 2.7, seed + 4.0) * .035;
  float path = direction + bend;
  float reach = mix(4.5, 10.5, hash(vec3(seed, 7, 1)));
  float advance = smoothstep(depth - .25, depth + .25, fracture * 10.0);
  float taper = 1.0 - smoothstep(reach - 1.0, reach, depth);
  float width = mix(.085, .20, hash(vec3(seed, 9, 2))) * (.9 + .25 * jagged(depth * 1.8, seed + 8.0));
  float distance = abs(wrap_angle(angle - path)) * max(radius, .5);
  float edge = (noise(p * 8.0) - .5) * .028;
  float channel = 1.0 - smoothstep(width * .25, width + .035, distance + edge);
  opening = max(opening, channel * taper * advance);
  lip = max(lip, (1.0 - smoothstep(width, width + .13, distance + edge)) * taper * advance);
  for (int branch = 0; branch < 2; branch++) {
   float start = 1.3 + float(branch) * 2.6 + hash(vec3(seed, float(branch), 3)) * 1.5;
   float age = depth - start;
   float branch_path = path + (branch == 0 ? 1.0 : -1.0) * max(age, 0.0) * .17;
   float branch_distance = abs(wrap_angle(angle - branch_path)) * max(radius, .5);
   float branch_taper = smoothstep(-.06, .22, age) * (1.0 - smoothstep(1.4, 2.9, age));
   float thin = width * .48;
   opening = max(opening, (1.0 - smoothstep(thin * .2, thin + .018, branch_distance + edge)) * branch_taper * advance);
   lip = max(lip, (1.0 - smoothstep(thin, thin + .065, branch_distance + edge)) * branch_taper * advance);
  }
 }
 return vec2(opening, lip);
}
void fragment() {
 vec2 fault = cracks(local_position);
 float vein = fault.x * fracture;
 float grain = noise(local_position * 5.0);
 ALBEDO = stone_color.rgb * mix(.87, 1.07, grain);
 float patch = noise(local_position * .7) * .7 + noise(local_position * 3.8) * .3;
 float spread = 1.0 - smoothstep(growth * 12.0 - .6, growth * 12.0 + .4, local_position.y + patch * 1.8);
 float moss = smoothstep(.28, .60, patch) * spread * smoothstep(0.0, .15, growth);
 ALBEDO = mix(ALBEDO, mix(vec3(.08,.16,.045), vec3(.26,.36,.10), patch), moss * .88);
 // A chipped shoulder catches light; the recessed core stays dark under moss.
 ALBEDO *= 1.0 + (fault.y - fault.x) * fracture * .22;
 ALBEDO = mix(ALBEDO, stone_color.rgb * .075, vein * (1.0 - moss * .38));
 float relief = (fault.y * .018 - fault.x * .09) * fracture;
 vec3 normal = normalize(NORMAL);
 vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
 vec3 rx = cross(dy, normal), ry = cross(normal, dx);
 float determinant = dot(dx, rx);
 vec3 gradient = (rx * dFdx(relief) + ry * dFdy(relief)) * sign(determinant) / max(abs(determinant), .00001);
 NORMAL = normalize(normal - gradient * min(1.0, .6 / max(length(gradient), .001)));
 ROUGHNESS = .95;
 EMISSION = vec3(1.0, .79, .40) * vein * radiance * .3;
}
