shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float split=0.0;
uniform float flow=0.0;
uniform float opacity=.5;
uniform float layer=0.0;
uniform vec3 origin=vec3(0);
uniform sampler2D noise_texture : filter_linear_mipmap, repeat_enable;
varying vec3 relative_position;
void vertex() {
 vec3 centre=MODEL_MATRIX[3].xyz;
 vec3 world=centre+INV_VIEW_MATRIX[0].xyz*VERTEX.x+INV_VIEW_MATRIX[1].xyz*VERTEX.y;
 relative_position=world-origin;
 VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1)).xyz;
}
void fragment() {
 vec2 p=(UV-.5)*2.0;
 float n=texture(noise_texture,UV*1.6+vec2(flow*.014+layer*.37,layer*.51)).r;
 n=mix(n,texture(noise_texture,UV*3.3+vec2(-flow*.01,layer*.21)).r,.22);
 float density=1.0-smoothstep(.12,1.0,length(p)+(.5-n)*.32);
 float r=length(relative_position.xz);
 float angle=atan(relative_position.z,relative_position.x);
 float curl=sin(angle*5.0+flow+layer)*split*.65;
 float opening=smoothstep(split*8.0-.5+curl,split*8.0+2.5+curl,r);
 ALBEDO=mix(vec3(.42,.46,.49),vec3(.82,.84,.85),n*.6+UV.y*.3);
 ALPHA=opacity*density*opening;
}
