extends "res://vfx/common/common_effect.gd"
## Opaque clumps with baked face shading with shrink-out: faceted smoke, no alpha overdraw stack.
static var clump:ArrayMesh
func _build_particles() -> void:
 super._build_particles()
 if not clump:
  var phi:float=(1.0+sqrt(5.0))*.5
  var points:Array[Vector3]=[Vector3(-1,phi,0),Vector3(1,phi,0),Vector3(-1,-phi,0),Vector3(1,-phi,0),Vector3(0,-1,phi),Vector3(0,1,phi),Vector3(0,-1,-phi),Vector3(0,1,-phi),Vector3(phi,0,-1),Vector3(phi,0,1),Vector3(-phi,0,-1),Vector3(-phi,0,1)]
  var faces:PackedInt32Array=PackedInt32Array([0,11,5,0,5,1,0,1,7,0,7,10,0,10,11,1,5,9,5,11,4,11,10,2,10,7,6,7,1,8,3,9,4,3,4,2,3,2,6,3,6,8,3,8,9,4,9,5,2,4,11,6,2,10,8,6,7,9,8,1])
  var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray()
  for face in range(0,faces.size(),3):
   var a:=points[faces[face]].normalized()*.5
   var b:=points[faces[face+1]].normalized()*.5
   var c:=points[faces[face+2]].normalized()*.5
   var normal:Vector3=(b-a).cross(c-a).normalized()
   vertices.append_array(PackedVector3Array([a,c,b]))
   normals.append_array(PackedVector3Array([normal,normal,normal]))
   var shade:float=.62+.38*maxf(0,normal.dot(Vector3(-.4,.8,-.3).normalized()))
   colors.append_array(PackedColorArray([Color(shade,shade,shade),Color(shade,shade,shade),Color(shade,shade,shade)]))
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors
  clump=ArrayMesh.new();clump.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new()
 material.vertex_color_use_as_albedo=true
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 material.roughness=1.0
 material.cull_mode=BaseMaterial3D.CULL_BACK
 var mesh:=clump.duplicate() as ArrayMesh
 mesh.surface_set_material(0,material)
 particles.draw_pass_1=mesh
 particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 motion.scale_min=.22;motion.scale_max=.58
 motion.damping_min=1.6;motion.damping_max=2.8
 motion.gravity=Vector3(0,.55,0)
 motion.turbulence_enabled=false
 motion.angular_velocity_min=-90;motion.angular_velocity_max=90
 var curve:=Curve.new()
 curve.add_point(Vector2(0,.12));curve.add_point(Vector2(.12,.95))
 curve.add_point(Vector2(.45,1.2));curve.add_point(Vector2(.78,.75));curve.add_point(Vector2(1,0))
 var texture:=CurveTexture.new();texture.curve=curve;motion.scale_curve=texture
 var shades:=Gradient.new()
 shades.colors=PackedColorArray([Color(.7,.69,.65),Color(1.12,1.08,1.0)])
 var ramp:=GradientTexture1D.new();ramp.gradient=shades;motion.color_initial_ramp=ramp
