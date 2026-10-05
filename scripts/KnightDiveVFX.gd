extends Node3D
## X presentation only. GPU dust uses the shared pool; airflow nodes are built
## once per Knight and reused. This component never owns damage or movement.
signal effect_spawned(event: StringName, effect: StringName, instance: Node3D)
const AIR_SHADER = preload("res://assets/shaders/knight_dive_air.gdshader")
const AIR_COUNTS: Array[int] = [32,56,80]
const BUDGETS: Array[int] = [180,280,380]
static var stream_mesh: ArrayMesh
static var annulus: ArrayMesh
static var warmed: bool = false
static var warming: bool = false
var actor: PlayerController
var manager: Node
var skeleton: Skeleton3D
var feet: PackedInt32Array = PackedInt32Array()
var hips: int = -1
var ground_query: PhysicsRayQueryParameters3D
var ground_y: float = 0.0
var ground_color: Color = Color("c9b48a")
var casting: bool = false
var landed: bool = false
var mode: int = 0 # 0=off, 1=takeoff, 2=dive, 3=impact tail
var clock: float = 0.0
var fade: float = 0.0
var direction: Vector3 = Vector3.DOWN
var wind: Node3D
var streaks: GPUParticles3D
var stream_material: ShaderMaterial
var air_rings: Array[MeshInstance3D] = []
var air_materials: Array[ShaderMaterial] = []
var ground_root: Node3D
var ground_rings: Array[MeshInstance3D] = []
var ground_materials: Array[ShaderMaterial] = []
var ground_age: float = 1.0
var ground_power: float = 1.0
var leases: Array[Dictionary] = []

func _ready() -> void:
 actor = get_parent() as PlayerController
 manager = get_node_or_null("/root/VFXManager")
 skeleton = actor._skeleton
 if skeleton:
  hips = skeleton.find_bone("hips")
  for name in ["foot.L","foot.R"]: feet.append(skeleton.find_bone(name))
 ground_query = PhysicsRayQueryParameters3D.new()
 ground_query.collision_mask = 1
 ground_query.exclude = [actor.get_rid()]
 process_priority = 115
 _build_air()
 if manager:
  manager.quality_changed.connect(_quality_changed)
  manager.enabled_changed.connect(_enabled_changed)
 _quality_changed(manager.quality if manager else 1)
 set_process(false)
 call_deferred("warmup")

static func _make_stream() -> ArrayMesh:
 var vertices: PackedVector3Array = PackedVector3Array()
 var uv: PackedVector2Array = PackedVector2Array()
 var indices: PackedInt32Array = PackedInt32Array()
 for lane in 14:
  var angle: float = TAU * lane / 14.0
  for segment in 25:
   var t: float = segment/24.0
   var radius: float = .10 + sin(t*PI)*.66 + .18*t
   var twist: float = angle + t*.65
   var radial: Vector3 = Vector3(cos(twist),sin(twist),0)
   var centre: Vector3 = radial*radius + Vector3(0,0,-1.25+t*3.8)
   var width: float = (.018+.008*(lane%3))*sin(PI*t)
   for side in [-1.0,1.0]:
    vertices.append(centre+radial*width*side)
    uv.append(Vector2(t,.0 if side<0 else 1.0))
   if segment<24:
    var i: int = lane*50+segment*2
    indices.append_array(PackedInt32Array([i,i+1,i+2,i+1,i+3,i+2]))
 var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var result: ArrayMesh = ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result

static func _make_annulus() -> ArrayMesh:
 var vertices: PackedVector3Array = PackedVector3Array()
 var uv: PackedVector2Array = PackedVector2Array()
 var indices: PackedInt32Array = PackedInt32Array()
 for segment in 65:
  var angle: float = TAU*segment/64.0
  for edge in 2:
   var radius: float = .90 if edge==0 else 1.0
   vertices.append(Vector3(cos(angle)*radius,sin(angle)*radius,0))
   uv.append(Vector2(segment/64.0,float(edge)))
  if segment<64:
   var i: int = segment*2
   indices.append_array(PackedInt32Array([i,i+1,i+2,i+1,i+3,i+2]))
 var arrays: Array = [];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var result: ArrayMesh = ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return result

func _ring(parent: Node3D) -> MeshInstance3D:
 var ring: MeshInstance3D = MeshInstance3D.new()
 ring.mesh=annulus;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material: ShaderMaterial = ShaderMaterial.new();material.shader=AIR_SHADER
 material.set_shader_parameter("ring",true);ring.material_override=material
 parent.add_child(ring)
 return ring

func _build_air() -> void:
 if not stream_mesh: stream_mesh=_make_stream()
 if not annulus: annulus=_make_annulus()
 wind=Node3D.new();wind.name="SpearAirflow";add_child(wind);wind.top_level=true;wind.hide()
 var mesh: MeshInstance3D = MeshInstance3D.new();mesh.mesh=stream_mesh
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 stream_material=ShaderMaterial.new();stream_material.shader=AIR_SHADER;mesh.material_override=stream_material
 wind.add_child(mesh)
 for i in 3:
  var ring: MeshInstance3D = _ring(wind)
  air_rings.append(ring);air_materials.append(ring.material_override)
 streaks=GPUParticles3D.new();streaks.name="AirSplinters";streaks.amount=80;streaks.lifetime=.24
 streaks.emitting=false;streaks.local_coords=false;streaks.fixed_fps=30
 streaks.visibility_aabb=AABB(Vector3(-5,-5,-5),Vector3(10,10,10))
 streaks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var motion: ParticleProcessMaterial = ParticleProcessMaterial.new()
 motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_RING
 motion.emission_ring_axis=Vector3.BACK;motion.emission_ring_radius=.6;motion.emission_ring_inner_radius=.35
 motion.emission_ring_height=1.0;motion.direction=Vector3.BACK;motion.spread=10
 motion.initial_velocity_min=7;motion.initial_velocity_max=12;motion.gravity=Vector3.ZERO
 motion.particle_flag_align_y=true;motion.scale_min=.65;motion.scale_max=1.2
 var gradient: Gradient = Gradient.new()
 gradient.offsets=PackedFloat32Array([0,.12,.7,1]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.5),Color(1,1,1,.25),Color(1,1,1,0)])
 var ramp: GradientTexture1D = GradientTexture1D.new();ramp.gradient=gradient;motion.color_ramp=ramp
 streaks.process_material=motion
 var sliver: BoxMesh = BoxMesh.new();sliver.size=Vector3(.009,.20,.009)
 var material: StandardMaterial3D = StandardMaterial3D.new()
 material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material.vertex_color_use_as_albedo=true;material.albedo_color=Color(.85,.85,.80,.7)
 material.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED;sliver.material=material
 streaks.draw_pass_1=sliver;wind.add_child(streaks)
 ground_root=Node3D.new();ground_root.name="GroundAirPressure";add_child(ground_root);ground_root.top_level=true;ground_root.hide()
 for i in 2:
  var ring: MeshInstance3D = _ring(ground_root)
  ground_rings.append(ring);ground_materials.append(ring.material_override)

func warmup() -> void:
 if warmed or warming or DisplayServer.get_name()=="headless":return
 warming=true
 var viewport: SubViewport = SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var camera: Camera3D = Camera3D.new();viewport.add_child(camera);camera.position=Vector3(2,1,4);camera.look_at(Vector3.ZERO);camera.current=true
 var sample: Node3D = wind.duplicate() as Node3D;viewport.add_child(sample);sample.top_level=false;sample.transform=Transform3D.IDENTITY;sample.show()
 (sample.get_node("AirSplinters") as GPUParticles3D).emitting=true
 stream_material.set_shader_parameter("strength",.4)
 for material in air_materials:material.set_shader_parameter("strength",.2)
 for i in 3:await RenderingServer.frame_post_draw
 viewport.get_texture().get_image();viewport.queue_free();warming=false;warmed=true
 if mode==0:stream_material.set_shader_parameter("strength",0.0)

func _quality_changed(value: int) -> void:
 if streaks:streaks.amount_ratio=AIR_COUNTS[clampi(value,0,2)]/80.0

func _enabled_changed(value: bool) -> void:
 if not value:stop(true)

func _sample_ground() -> void:
 ground_y=actor.global_position.y
 ground_query.from=actor.global_position+Vector3.UP*.5
 ground_query.to=actor.global_position-Vector3.UP*8.0
 var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ground_query)
 if hit.is_empty():return
 ground_y=hit.position.y
 var receiver: Node = hit.collider as Node
 if receiver.has_meta("ground_color"):
  ground_color=receiver.get_meta("ground_color");return
 var meshes: Array[Node] = receiver.find_children("*","MeshInstance3D",true,false)
 if meshes.is_empty() and receiver.get_parent():meshes=receiver.get_parent().find_children("*","MeshInstance3D",true,false)
 var area: float = -1.0
 for mesh: MeshInstance3D in meshes:
  if not mesh.mesh or actor.is_ancestor_of(mesh):continue
  var bounds: AABB = mesh.global_transform*mesh.mesh.get_aabb()
  if not bounds.grow(.05).has_point(hit.position) or bounds.size.x*bounds.size.z<=area:continue
  var material: Material = mesh.material_override if mesh.material_override else mesh.get_active_material(0)
  if material is StandardMaterial3D:
   ground_color=material.albedo_color;area=bounds.size.x*bounds.size.z

func _foot(side: int) -> Vector3:
 var at: Vector3 = actor.global_position
 if skeleton and side<feet.size() and feet[side]>=0:at=skeleton.global_transform*skeleton.get_bone_global_pose(feet[side]).origin
 at.y=ground_y
 return at

func _prune() -> void:
 for i in range(leases.size()-1,-1,-1):
  var item: Dictionary = leases[i]
  if not is_instance_valid(item.effect) or not item.effect.active or item.effect.lease_id!=item.lease:leases.remove_at(i)

func _spawn(event: StringName, name: StringName, at: Vector3, params: Dictionary) -> Node3D:
 if not manager or not manager.warmup_complete or not manager.enabled:return null
 var quality: int = manager.quality
 params.particle_limit=BUDGETS[quality]-AIR_COUNTS[quality]
 params.actor=actor;params.color=ground_color;params.ground_y=ground_y
 var effect: Node3D = manager.try_spawn(name,at,params)
 if effect:
  _prune();leases.append({"effect":effect,"lease":effect.lease_id})
  effect_spawned.emit(event,name,effect)
 return effect

func prepare() -> void:
 stop(true);_sample_ground();casting=true;landed=false;clock=0

func launch() -> void:
 if not casting:return
 mode=1;clock=0;direction=Vector3.UP;set_process(true)
 for side in 2:
  _spawn(&"launch",&"HeavyDust",_foot(side),{"scale":1.05,"amount_scale":1.0,"particle_lifetime":.40,"direction":Vector3.UP,"spread":80.0,"speed_min":1.4,"speed_max":3.0})
  _spawn(&"launch",&"DustPuff",_foot(side),{"scale":1.05,"amount_scale":.6,"particle_lifetime":.40,"direction":Vector3.UP,"speed_min":1.0,"speed_max":2.4})
 _spawn(&"launch",&"DustRing",actor.global_position,{"radius":1.5,"amount_scale":1.0,"particle_lifetime":.40})
 _spawn(&"launch",&"Debris",actor.global_position,{"amount_scale":.65,"particle_lifetime":.6,"speed_min":2.2,"speed_max":4.5})
 _ground_wave(actor.global_position,1.9)

func aim() -> void:
 mode=0;wind.hide();streaks.emitting=false

func dive(forward: Vector3) -> void:
 if not casting:return
 mode=2;clock=0;direction=forward.normalized();fade=1;set_process(true)
 streaks.restart();streaks.emitting=manager!=null and manager.enabled

func impact() -> void:
 if not casting or landed:return
 landed=true;mode=3;fade=.16;streaks.emitting=false;_sample_ground()
 var at: Vector3 = actor.global_position;at.y=ground_y
 _spawn(&"impact",&"DustRing",at,{"radius":3.5,"amount_scale":1.0,"particle_lifetime":.9})
 _spawn(&"impact",&"Debris",at,{"scale":1.2,"amount_scale":1.0,"particle_lifetime":1.45,"speed_min":3.0,"speed_max":6.2})
 for side in [-1.0,1.0]:
  _spawn(&"impact",&"DustPuff",at+Vector3(side*.55,0,0),{"scale":1.6,"amount_scale":.5,"particle_lifetime":.8,"speed_min":1.0,"speed_max":2.0})
 for i in 5:
  var angle: float = TAU*i/5.0
  var outward: Vector3 = Vector3(cos(angle),.22,sin(angle)).normalized()
  _spawn(&"impact",&"HeavyDust",at+Vector3(cos(angle),0,sin(angle))*.65,{"scale":1.3,"amount_scale":[.65,.7,.8][manager.quality if manager else 1],"particle_lifetime":.9,"direction":outward,"spread":25.0,"speed_min":1.1,"speed_max":2.2})
 _ground_wave(at,3.5)
 if manager:manager.camera_recoil(actor,1)
 set_process(true)

func _ground_wave(at: Vector3, radius: float) -> void:
 ground_age=0;ground_power=radius
 at.y=ground_y+.045
 ground_root.global_transform=Transform3D(Basis(Quaternion(Vector3.BACK,Vector3.UP)),at);ground_root.show()

func _process(delta: float) -> void:
 if not manager or not manager.enabled or actor.is_dead or actor.is_control_impaired():stop(true);return
 clock+=delta;ground_age+=delta
 if ground_age<.65:
  for i in 2:
   var t: float = clampf((ground_age-i*.07)/.5,0,1)
   ground_rings[i].scale=Vector3.ONE*lerpf(.12,ground_power,1-pow(1-t,2))
   ground_materials[i].set_shader_parameter("strength",sin(PI*t)*(.36-i*.09))
   ground_materials[i].set_shader_parameter("flow",t)
 else:ground_root.hide()
 var strength: float = 0.0
 if mode==1:strength=.32*(1.0-smoothstep(.0,.35,clock))
 elif mode==2:strength=.64*smoothstep(0,.08,clock)
 elif mode==3:
  fade=maxf(0,fade-delta);strength=.64*fade/.16
  if fade<=0:mode=0
 if strength>.005:
  var at: Vector3 = actor.global_position+Vector3.UP*1.15
  if skeleton and hips>=0:
   at=skeleton.global_transform*skeleton.get_bone_global_pose(hips).origin
   if mode==2:at+=direction*.15
  var up: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.UP))>.95 else Vector3.UP
  wind.global_transform=Transform3D(Basis.looking_at(direction,up),at);wind.show()
  stream_material.set_shader_parameter("strength",strength)
  stream_material.set_shader_parameter("flow",clock*2.1)
  for i in 3:
   var t: float = fposmod(clock*2.5+i/3.0,1.0)
   air_rings[i].position.z=lerpf(-.95,1.7,t)
   air_rings[i].scale=Vector3.ONE*lerpf(.20,.92,t)
   air_materials[i].set_shader_parameter("strength",strength*.3*sin(PI*t))
   air_materials[i].set_shader_parameter("flow",clock)
 else:wind.hide()
 if mode==0 and ground_age>=.65:set_process(false)

func stop(interrupted: bool = true) -> void:
 casting=false;mode=0
 if wind:wind.hide()
 if streaks:streaks.emitting=false
 if interrupted:
  ground_age=1
  if ground_root:ground_root.hide()
  for item in leases:
   if is_instance_valid(manager) and is_instance_valid(item.effect) and item.effect.active and item.effect.lease_id==item.lease:manager.release(item.effect)
  leases.clear();set_process(false)
 else:set_process(ground_age<.65)

func active_particles() -> int:
 _prune()
 var count: int = AIR_COUNTS[manager.quality] if manager and wind.visible else 0
 for item in leases:count+=item.effect.effective_particles()
 return count

func _exit_tree() -> void:
 stop(true)
