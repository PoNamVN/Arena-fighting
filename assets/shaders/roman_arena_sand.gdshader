shader_type spatial;
render_mode cull_disabled;
uniform float paving_strength : hint_range(0.0,1.0)=1.0;
varying vec3 world;
float hash21(vec2 p){p=fract(p*vec2(123.34,345.45));p+=dot(p,p+34.345);return fract(p.x*p.y);}
float noise21(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1)),f.x),f.y);}
float line_segment(vec2 p,vec2 a,vec2 b,float width){vec2 v=b-a;return 1.0-smoothstep(width,width+.015,length(p-a-v*clamp(dot(p-a,v)/dot(v,v),0.0,1.0)));}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float r=length(p);
 float broad=noise21(p*.17);
 float weather=noise21(p*1.3);
 float grain=hash21(floor(p*45.0));
 float dunes=sin(p.x*7.1+p.y*2.4+sin(p.y*.42)*1.8);
 float ripple=dunes*.027*smoothstep(.32,.72,broad);
 vec3 sand=mix(vec3(.53,.39,.22),vec3(.66,.52,.33),broad)*(1.0+ripple+(grain-.5)*.022);
 // Offset joints distinguish paving blocks; detail is entirely in the material.
 vec2 tile=p/vec2(1.35,.85);tile.x+=mod(floor(tile.y),2.0)*.5;
 vec2 cell=fract(tile);vec2 edge=min(cell,1.0-cell);
 float seam=1.0-smoothstep(.008,.024,min(edge.x,edge.y));
 float stain=noise21(p*.63);
 vec3 stone=mix(vec3(.45,.39,.30),vec3(.64,.57,.43),hash21(floor(tile))*.65+weather*.35);
 stone*=1.0-seam*.34;stone*=.94+stain*.10;
 vec2 oct=abs(p);
 float apothem=max(dot(oct,vec2(.9238795,.3826834)),dot(oct,vec2(.3826834,.9238795)));
 float paving=smoothstep(18.35,18.48,apothem)*(1.0-smoothstep(21.1,21.25,apothem));
 float ring=(1.0-smoothstep(.20,.25,abs(r-6.8)));
 float ring_edge=1.0-smoothstep(.025,.050,abs(abs(r-6.8)-.18));
 vec3 albedo=mix(sand,stone,clamp(paving+ring,0.0,1.0)*paving_strength);
 albedo=mix(albedo,vec3(.40,.32,.21),ring_edge*.45*paving_strength);
 // Greek-key inlay follows the eight-sided paving border, with worn, muted colour.
 float angle=atan(p.y,p.x);
 vec2 key=vec2(fract((angle+3.14159265)*48.0/6.2831853),(apothem-19.1)/.72);
 float stripe=step(0.0,key.y)*step(key.y,1.0);
 float pattern=max(line_segment(key,vec2(0,.18),vec2(.82,.18),.04),line_segment(key,vec2(.82,.18),vec2(.82,.80),.04));
 pattern=max(pattern,line_segment(key,vec2(.82,.80),vec2(.22,.80),.04));
 pattern=max(pattern,line_segment(key,vec2(.22,.80),vec2(.22,.43),.04));
 pattern=max(pattern,line_segment(key,vec2(.22,.43),vec2(.57,.43),.04));
 float wear=smoothstep(.15,.4,weather);
 albedo=mix(albedo,vec3(.33,.27,.19),pattern*stripe*wear*paving*.65*paving_strength);
 // Thin chipped coping at the inner walkway edge; no raised collision seam.
 float coping=1.0-smoothstep(.055,.095,abs(apothem-18.52));
 albedo=mix(albedo,vec3(.70,.61,.44),coping*.5*paving_strength);
 ALBEDO=albedo;
 ROUGHNESS=mix(.98,.87,paving);
}
