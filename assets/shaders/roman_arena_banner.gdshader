shader_type spatial;
render_mode cull_disabled;
uniform float flutter_time=0.0;
void vertex(){VERTEX.z+=sin(flutter_time*1.4+VERTEX.x*.6+VERTEX.y*2.1)*.10*UV.y*UV.y;}
void fragment(){ALBEDO=COLOR.rgb*vec3(.65,.55,.55);ROUGHNESS=.95;}
