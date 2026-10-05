shader_type spatial;
uniform vec4 metal_color : source_color = vec4(.64,.67,.72,1);
uniform float metalness = .92;
uniform float dissolve : hint_range(0,1) = 0;
uniform float fall_speed = 0;
uniform float impact_heat = 0;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
 float grain=fract(sin(dot(floor(local_position*7.0),vec3(12.9898,78.233,45.164)))*43758.5453);
 float cut=dissolve*26.0-grain*.7;
 if(dissolve>0.0 && local_position.y<cut){discard;}
 float brush=sin(local_position.y*72.0+sin(local_position.x*13.0)*.3);
 float fuller=(1.0-smoothstep(.12,.25,abs(local_position.x)))*smoothstep(2.0,4.0,local_position.y)*(1.0-smoothstep(18.0,19.5,local_position.y));
 ALBEDO=metal_color.rgb*(.94+.06*grain)*(1.0-fuller*.24);
 METALLIC=metalness;
 ROUGHNESS=clamp(.36+.008*brush+.06*(1.0-metalness),.23,.5);
 RIM=.18;RIM_TINT=.1;
 float edge=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),5.0);
 float hot=impact_heat*(1.0-smoothstep(0.0,2.5,local_position.y));
 EMISSION=vec3(.84,.86,.89)*edge*fall_speed*.22+vec3(1.0,.42,.09)*hot*.8;
}
