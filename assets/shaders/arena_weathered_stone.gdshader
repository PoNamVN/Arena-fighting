shader_type spatial;
varying vec3 world;
varying vec4 tint;
float hash21(vec2 p){p=fract(p*vec2(123.34,345.45));p+=dot(p,p+34.345);return fract(p.x*p.y);}
float noise21(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;tint=COLOR;}
void fragment(){
 vec2 p=world.xz+vec2(world.y*.37,world.y*.73);
 float mottling=noise21(p*1.5);
 float grain=hash21(floor(p*30.0));
 float foot=(1.0-smoothstep(.1,1.2,world.y))*.13;
 vec3 stone=pow(tint.rgb,vec3(2.2))*(.92+mottling*.12+(grain-.5)*.02);
 ALBEDO=mix(stone,stone*vec3(.86,.78,.63),foot);
 ROUGHNESS=.9;
}
