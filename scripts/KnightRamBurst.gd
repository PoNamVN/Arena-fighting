extends Node3D
## Two reusable annuli: compressed air, not a glowing disc. No depth reads.
var rings:Array[MeshInstance3D]=[]
var materials:Array[ShaderMaterial]=[]
var age:=1.0
var direction:=Vector3.FORWARD
var origin:=Vector3.ZERO
static var geometry:ArrayMesh
static var air_shader:Shader
static var warmed:=false
static var warming:=false
func _ready() -> void:
 top_level=true
 if not geometry:
  var verts:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
  for segment in 65:
   var angle:=TAU*segment/64.0
   for edge in 2:
    var radius:=.83 if edge==0 else 1.0
    verts.append(Vector3(cos(angle)*radius,sin(angle)*radius,0))
    uv.append(Vector2(float(segment)/64.0,float(edge)))
   if segment<64:
    var i:=segment*2
    indices.append_array(PackedInt32Array([i,i+1,i+2,i+1,i+3,i+2]))
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=verts;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
  geometry=ArrayMesh.new();geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  air_shader=Shader.new()
  air_shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float opacity=0.0;
uniform float age=0.0;
void fragment(){
 float soft=pow(max(0.0,sin(UV.y*3.14159)),2.0);
 float wisps=0.48+0.52*smoothstep(-0.55,0.6,sin(UV.x*37.699-age*8.0));
 ALBEDO=vec3(0.84,0.84,0.80);
 ALPHA=opacity*soft*wisps;
}"""
 for i in 2:
  var ring:=MeshInstance3D.new();ring.mesh=geometry
  var material:=ShaderMaterial.new();material.shader=air_shader
  ring.material_override=material;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(ring);rings.append(ring);materials.append(material)
 hide()
 call_deferred("warmup")
func warmup() -> void:
 if warmed or warming or DisplayServer.get_name()=="headless":return
 warming=true
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(64,64);viewport.own_world_3d=true
 viewport.msaa_3d=get_viewport().msaa_3d
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(viewport)
 var camera:=Camera3D.new();viewport.add_child(camera);camera.position.z=3;camera.current=true
 var sample:=MeshInstance3D.new();sample.mesh=geometry
 var material:=ShaderMaterial.new();material.shader=air_shader;material.set_shader_parameter("opacity",.4)
 sample.material_override=material;sample.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 viewport.add_child(sample)
 for i in 3:await RenderingServer.frame_post_draw
 viewport.get_texture().get_image()
 warmed=true;warming=false;viewport.queue_free()
func burst(at:Vector3,forward:Vector3) -> void:
 origin=at;direction=forward.normalized();age=0
 global_transform=Transform3D(Basis.looking_at(direction,Vector3.UP),at)
 show();update_burst(0)
func update_burst(delta:float) -> void:
 age+=delta
 if age>=.55:
  hide();return
 global_position=origin+direction*minf(age*3.0,.9)
 for i in 2:
  var t:=clampf((age-i*.07)/.34,0,1)
  var radius:=lerpf(.28,3.0,1-pow(1-t,2))
  rings[i].scale=Vector3.ONE*radius
  rings[i].visible=age>=i*.07 and t<1
  materials[i].set_shader_parameter("opacity",sin(PI*t)*.65*(1-i*.25))
  materials[i].set_shader_parameter("age",t)
func clear() -> void:
 age=1;hide()
