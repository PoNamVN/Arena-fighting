extends Node3D
## Ambient cloud bank. One draw surface, no collisions or particles.
## Inherits pause: ultimate freeze stops both drift and noise evolution.
@export_range(65,150,1) var altitude:float=88.0
@export_range(0,2,.05) var drift_speed:float=.7
@export_range(0,1,.05) var opacity:float=.68
var elapsed:float=0.0
var material:ShaderMaterial
var batch:MultiMesh
var clouds:MultiMeshInstance3D
var _manager:Node

func _ready()->void:
 var noise:=FastNoiseLite.new();noise.seed=731;noise.frequency=.035;noise.fractal_octaves=3
 var smoke:=NoiseTexture2D.new();smoke.width=128;smoke.height=128;smoke.seamless=true;smoke.normalize=true;smoke.noise=noise
 material=ShaderMaterial.new();material.shader=preload("res://assets/shaders/arena_sky_clouds.gdshader")
 material.set_shader_parameter("noise_texture",smoke)
 material.set_shader_parameter("wind",Vector2(drift_speed,drift_speed*.25714286))
 material.set_shader_parameter("field_center",global_position)
 material.set_shader_parameter("opacity",opacity)
 batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_custom_data=true
 var quad:=QuadMesh.new();quad.size=Vector2.ONE;batch.mesh=quad;batch.instance_count=30
 var rng:=RandomNumberGenerator.new();rng.seed=64108
 var centres:Array[Vector3]=[]
 for bank in 10:
  var angle:float=bank*TAU/10.0+rng.randf_range(-.16,.16)
  var radius:float=rng.randf_range(24,75)
  centres.append(Vector3(cos(angle)*radius,altitude+rng.randf_range(0,12),sin(angle)*radius))
 for i in 30:
  var puff:int=i/10
  var position:Vector3=centres[i%10]+Vector3(puff*7.0-7.0,rng.randf_range(-2,2),puff*3.0-3.0)
  var size:=Vector3(rng.randf_range(22,32),rng.randf_range(11,16),1)
  batch.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(size),position))
  batch.set_instance_custom_data(i,Color(float(i),rng.randf_range(.8,1),0,1))
 clouds=MultiMeshInstance3D.new();clouds.name="CloudBatch";clouds.multimesh=batch;clouds.material_override=material
 clouds.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 clouds.custom_aabb=AABB(Vector3(-116,altitude-14,-116),Vector3(232,44,232))
 add_child(clouds)
 _manager=get_node_or_null("/root/VFXManager")
 if _manager:_manager.quality_changed.connect(_quality_changed)
 _quality_changed(_manager.quality if _manager else 1)

func _process(delta:float)->void:
 elapsed+=delta;material.set_shader_parameter("elapsed",elapsed)

func _quality_changed(quality:int)->void:
 batch.visible_instance_count=[15,24,30][clampi(quality,0,2)]
