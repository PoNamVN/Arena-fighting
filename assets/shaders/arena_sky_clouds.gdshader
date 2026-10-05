shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D noise_texture : filter_linear_mipmap,repeat_enable;
uniform float elapsed=0.0;
uniform vec2 wind=vec2(.7,.18);
uniform float span=96.0;
uniform vec3 field_center=vec3(0);
uniform float opacity=.68;
varying float phase;
varying float density_scale;
varying float wrap_fade;
void vertex() {
 vec3 centre=MODEL_MATRIX[3].xyz;
 centre.xz=field_center.xz+mod(centre.xz-field_center.xz+wind*elapsed+span,2.0*span)-span;
 phase=INSTANCE_CUSTOM.r;
 density_scale=INSTANCE_CUSTOM.g;
 wrap_fade=1.0-smoothstep(span*.75,span,max(abs(centre.x-field_center.x),abs(centre.z-field_center.z)));
 vec3 world=centre+INV_VIEW_MATRIX[0].xyz*VERTEX.x*length(MODEL_MATRIX[0].xyz)+INV_VIEW_MATRIX[1].xyz*VERTEX.y*length(MODEL_MATRIX[1].xyz);
 VERTEX=(inverse(MODEL_MATRIX)*vec4(world,1)).xyz;
}
void fragment() {
 vec2 p=(UV-.5)*2.0;
 float n=texture(noise_texture,UV*1.6+vec2(elapsed*.004+phase*.37,phase*.51)).r;
 n=mix(n,texture(noise_texture,UV*3.3+vec2(-elapsed*.003,phase*.21)).r,.22);
 float density=1.0-smoothstep(.12,1.0,length(p)+(.5-n)*.32);
 ALBEDO=mix(vec3(.42,.46,.49),vec3(.82,.84,.85),n*.6+UV.y*.3);
 ALPHA=opacity*density*density_scale*wrap_fade;
}
