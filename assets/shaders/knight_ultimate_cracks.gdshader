shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float spread=0.0;
uniform float opacity=1.0;
uniform vec3 ground_color=vec3(.6,.56,.48);
uniform vec2 arena_min=vec2(-1000.0);
uniform vec2 arena_max=vec2(1000.0);
uniform int plane_count=0;
uniform vec4 arena_planes[8];
varying vec3 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
void fragment() {
 if(any(lessThan(world_position.xz,arena_min)) || any(greaterThan(world_position.xz,arena_max))) discard;
 for(int i=0;i<plane_count;i++) { if(dot(arena_planes[i].xyz,world_position)>arena_planes[i].w) discard; }
 ALBEDO=mix(ground_color*.13,ground_color*.68,COLOR.g);
 ALPHA=opacity*(1.0-smoothstep(spread-.02,spread+.02,COLOR.r));
}
