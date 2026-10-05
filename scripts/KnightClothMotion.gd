extends Node
## Presentation only: never writes actor velocity, bones, animation or combat state.
const CLOTH_SHADER: Shader = preload("res://assets/shaders/knight_cloth.gdshader")
const MAX_OFFSET := 0.09
@export var model_path: NodePath = NodePath("Visuals/CharacterModel")
@export var motion_enabled := true
## Look-dev must install the override before its parent caches the Before/After materials.
@export var bind_on_ready := false
var model: Node3D
var body: MeshInstance3D
var skeleton: Skeleton3D
var material: ShaderMaterial
var hem_offset := Vector2.ZERO
var hem_speed := Vector2.ZERO
var _last_position := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _last_heading := 0.0
var _sample_ready := false
var _hips := -1
var _leg_ids: Array[int] = []
var _starts := PackedVector3Array()
var _ends := PackedVector3Array()

func _ready() -> void:
 process_priority = 120
 if bind_on_ready:
  bind_model()
 else:
  call_deferred("bind_model")

func bind_model() -> void:
 model = get_parent().get_node_or_null(model_path) as Node3D
 if not model:
  set_process(false)
  return
 skeleton = model.get_node_or_null("Gladiator_Armature/Skeleton3D") as Skeleton3D
 if not skeleton:
  set_process(false)
  return
 body = skeleton.get_node_or_null("Gladiator_Mesh") as MeshInstance3D
 if not body or not body.mesh:
  set_process(false)
  return
 var tunic_surface := -1
 for surface in body.mesh.get_surface_count():
  var original := body.mesh.surface_get_material(surface)
  if original and "Tunic" in original.resource_name:
   var colors: PackedColorArray = body.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
   if colors.is_empty():
    set_process(false)
    return
   tunic_surface = surface
   break
 if tunic_surface < 0:
  set_process(false)
  return
 var previous := body.get_active_material(tunic_surface) as StandardMaterial3D
 material = ShaderMaterial.new()
 material.shader = CLOTH_SHADER
 material.resource_name = "Mat_Gladiator_Tunic.001"
 if previous:
  material.set_shader_parameter("tunic_color", previous.albedo_color)
 body.set_surface_override_material(tunic_surface, material)
 body.extra_cull_margin = maxf(body.extra_cull_margin, 0.25)
 _hips = skeleton.find_bone("hips")
 for name in [&"thigh.L", &"thigh.R", &"shin.L", &"shin.R", &"foot.L", &"foot.R"]:
  _leg_ids.append(skeleton.find_bone(name))
 if _hips < 0 or _leg_ids.has(-1):
  set_process(false)
  return
 _starts.resize(4)
 _ends.resize(4)
 reset_motion()
 _update_uniforms()

func reset_motion() -> void:
 hem_offset = Vector2.ZERO
 hem_speed = Vector2.ZERO
 _sample_ready = false
 _last_velocity = Vector3.ZERO
 if material:
  material.set_shader_parameter("hem_offset", hem_offset)

func step_spring(local_velocity: Vector3, local_acceleration: Vector3, turn_speed: float, delta: float) -> void:
 var target := Vector2(-local_velocity.x, -local_velocity.z) * 0.012
 target -= Vector2(local_acceleration.x, local_acceleration.z).limit_length(80.0) * 0.0012
 target.x -= clampf(turn_speed, -12.0, 12.0) * 0.004
 target = target.limit_length(MAX_OFFSET)
 # Fixed upper step size keeps the damped spring stable at low or varying FPS.
 var remaining := minf(delta, 0.1)
 while remaining > 0.000001:
  var dt := minf(remaining, 1.0 / 120.0)
  hem_speed += ((target - hem_offset) * 90.0 - hem_speed * 12.0) * dt
  hem_offset += hem_speed * dt
  if hem_offset.length() > MAX_OFFSET:
   hem_offset = hem_offset.limit_length(MAX_OFFSET)
   hem_speed -= hem_offset.normalized() * maxf(hem_speed.dot(hem_offset.normalized()), 0.0)
  remaining -= dt

func _process(delta: float) -> void:
 if not is_instance_valid(body) or not material:
  set_process(false)
  return
 if delta <= 0.0:
  return
 var hips_world := skeleton.global_transform * skeleton.get_bone_global_pose(_hips)
 var heading := atan2(hips_world.basis.z.x, hips_world.basis.z.z)
 if not motion_enabled or delta > 0.1 or (_sample_ready and hips_world.origin.distance_to(_last_position) > 2.0):
  reset_motion()
 elif _sample_ready:
  var velocity := ((hips_world.origin - _last_position) / delta).limit_length(25.0)
  var acceleration := ((velocity - _last_velocity) / delta).limit_length(80.0)
  var inverse := hips_world.basis.orthonormalized().inverse()
  step_spring(inverse * velocity, inverse * acceleration, angle_difference(_last_heading, heading) / delta, delta)
  _last_velocity = velocity
 _last_position = hips_world.origin
 _last_heading = heading
 _sample_ready = true
 _update_uniforms()

func _update_uniforms() -> void:
 var to_mesh := body.global_transform.affine_inverse() * skeleton.global_transform
 var hip_basis := (to_mesh.basis * skeleton.get_bone_global_pose(_hips).basis).orthonormalized()
 for i in 4:
  var start_id: int = _leg_ids[i]
  var end_id: int = _leg_ids[i + 2]
  _starts[i] = to_mesh * skeleton.get_bone_global_pose(start_id).origin
  _ends[i] = to_mesh * skeleton.get_bone_global_pose(end_id).origin
 material.set_shader_parameter("hem_offset", hem_offset)
 material.set_shader_parameter("cloth_basis", hip_basis)
 material.set_shader_parameter("leg_start", _starts)
 material.set_shader_parameter("leg_end", _ends)
 material.set_shader_parameter("cloth_enabled", motion_enabled)
