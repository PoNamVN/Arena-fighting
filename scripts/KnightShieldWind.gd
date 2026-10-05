extends MeshInstance3D
## One prebuilt mesh, reused across every Z. Shield-space streamlines deflect
## around the real kite bounds, then sweep backward. No screen/depth reads.
var material: ShaderMaterial
func configure(shield: MeshInstance3D) -> void:
 var bounds: AABB = shield.transform * shield.mesh.get_aabb()
 var width := bounds.size.x * 0.5
 var height := bounds.size.y * 0.5
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 for lane in 10:
  var side := -1.0 if lane < 5 else 1.0
  var level := float(lane % 5 - 2) * height * 0.36
  for segment in 33:
   var t := float(segment)/32.0
   var x := side * width * (0.12 + 1.03*sin(minf(t*2.4,PI*0.5)) + t*0.55)
   var y := level + sin(t*PI)*height*0.12
   var z := bounds.end.z + 0.42 - t*1.85
   var centre := Vector3(x,y,z)
   var ribbon_width := (0.013 + 0.004*float(lane%2)) * sin(PI*t)
   vertices.append(centre+Vector3.UP*ribbon_width)
   vertices.append(centre-Vector3.UP*ribbon_width)
   uv.append(Vector2(t,float(lane)*0.173))
   uv.append(Vector2(t,float(lane)*0.173+0.025))
   if segment < 32:
    var base := lane*66+segment*2
    indices.append_array(PackedInt32Array([base,base+2,base+1,base+1,base+2,base+3]))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=indices
 var built := ArrayMesh.new()
 built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh=built
 var shader := Shader.new()
 shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float strength = 0.0;
uniform float flow = 0.0;
void fragment(){
 float streak = pow(max(0.0,sin((UV.x-flow+UV.y)*18.84956)), 5.0);
 float taper = sin(UV.x*3.14159);
 ALBEDO=vec3(0.83,0.84,0.82);
 ALPHA=strength*taper*(0.045+0.40*streak);
}"""
 material=ShaderMaterial.new()
 material.shader=shader
 material_override=material
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 hide()
func update_flow(strength: float,clock: float) -> void:
 material.set_shader_parameter("strength",clampf(strength,0.0,1.0))
 material.set_shader_parameter("flow",clock*2.8)
 visible=strength>0.005
