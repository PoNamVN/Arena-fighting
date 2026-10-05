class_name WhirlingBladeVFX
extends Node3D
## Presentation only; the existing ACTIVE event owns all damage timing.
signal effect_spawned(effect: StringName, instance: Node3D)
const TRAIL_SLOTS: int = 32
const TRAIL_LIFE: float = .15
const AIR_COUNTS: Array[int] = [16,28,40]
const BUDGETS: Array[int] = [180,280,300]
const SHADER = preload("res://assets/shaders/knight_blade_sweep.gdshader")
var actor: PlayerController
var manager: Node
var base_socket: Marker3D
var tip_socket: Marker3D
var batch: MultiMesh
var air: GPUParticles3D
var air_motion: ParticleProcessMaterial
var ages: PackedFloat32Array = PackedFloat32Array()
var cursor: int = 0
var clock: float = 0
var duration: float = 0
var emitting: bool = false
var previous_base: Vector3
var previous_tip: Vector3
var previous_valid: bool = false
var ground_y: float = 0
var ground_color: Color = Color("c9b48a")
var query: PhysicsRayQueryParameters3D
var leases: Array[Dictionary] = []
var hits: int = 0
static var warmed: bool = false
static var warming: bool = false

func _ready() -> void:
 actor=get_parent().get_parent() as PlayerController
 manager=get_node_or_null("/root/VFXManager")
 base_socket=actor.find_child("Socket_SwordBase",true,false) as Marker3D
 tip_socket=actor.find_child("Socket_SwordTip",true,false) as Marker3D
 top_level=true;global_transform=Transform3D.IDENTITY
 process_priority=120
 ages.resize(TRAIL_SLOTS);ages.fill(TRAIL_LIFE)
 batch=MultiMesh.new();batch.transform_format=MultiMesh.TRANSFORM_3D;batch.use_colors=true
 var quad: QuadMesh=QuadMesh.new();quad.size=Vector2.ONE
 batch.mesh=quad;batch.instance_count=TRAIL_SLOTS
 var mesh: MultiMeshInstance3D=MultiMeshInstance3D.new();mesh.multimesh=batch
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var material: ShaderMaterial=ShaderMaterial.new();material.shader=SHADER;mesh.material_override=material
 add_child(mesh)
 for i in TRAIL_SLOTS:batch.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),Vector3.ZERO));batch.set_instance_color(i,Color(1,1,1,0))
 air=GPUParticles3D.new();air.amount=40;air.lifetime=.18;air.emitting=false;air.local_coords=false;air.fixed_fps=30
 air.visibility_aabb=AABB(Vector3(-5,-3,-5),Vector3(10,6,10));air.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 air_motion=ParticleProcessMaterial.new();air_motion.direction=Vector3.RIGHT;air_motion.spread=16
 air_motion.initial_velocity_min=2;air_motion.initial_velocity_max=4;air_motion.gravity=Vector3(0,-.6,0)
 air_motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;air_motion.emission_sphere_radius=.07;air_motion.particle_flag_align_y=true
 var gradient: Gradient=Gradient.new();gradient.offsets=PackedFloat32Array([0,.15,1]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.45),Color(1,1,1,0)])
 var ramp: GradientTexture1D=GradientTexture1D.new();ramp.gradient=gradient;air_motion.color_ramp=ramp;air.process_material=air_motion
 var shard: BoxMesh=BoxMesh.new();shard.size=Vector3(.009,.14,.009)
 var shard_material: StandardMaterial3D=StandardMaterial3D.new();shard_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 shard_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;shard_material.vertex_color_use_as_albedo=true;shard_material.albedo_color=Color(.86,.83,.75,.55);shard_material.no_depth_test=false
 shard.material=shard_material;air.draw_pass_1=shard;add_child(air)
 query=PhysicsRayQueryParameters3D.new();query.collision_mask=1;query.exclude=[actor.get_rid()]
 (get_parent() as PlayerCombat).hit_landed.connect(_on_hit)
 if manager:manager.quality_changed.connect(_quality_changed);manager.enabled_changed.connect(_enabled_changed)
 _quality_changed(manager.quality if manager else 1)
 visible=false;set_process(false);call_deferred("warmup")

func warmup() -> void:
 if warmed or warming or DisplayServer.get_name()=="headless":return
 warming=true
 var viewport: SubViewport=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var camera: Camera3D=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,0,3);camera.current=true
 var sample: MeshInstance3D=MeshInstance3D.new();sample.mesh=batch.mesh;sample.material_override=get_child(0).material_override;viewport.add_child(sample)
 var particles: GPUParticles3D=air.duplicate() as GPUParticles3D;viewport.add_child(particles);particles.emitting=true
 for i in 3:await RenderingServer.frame_post_draw
 viewport.get_texture().get_image();viewport.queue_free();warmed=true;warming=false

func _quality_changed(value: int) -> void:
 air.amount_ratio=AIR_COUNTS[clampi(value,0,2)]/40.0

func _enabled_changed(value: bool) -> void:
 if not value:stop()

func _ground(origin: Vector3) -> void:
 ground_y=origin.y;query.from=origin+Vector3.UP*.5;query.to=origin-Vector3.UP*4
 var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(query)
 if hit.is_empty():return
 ground_y=hit.position.y
 var body: Node=hit.collider
 if body.has_meta("ground_color"):ground_color=body.get_meta("ground_color");return
 var meshes: Array[Node]=body.find_children("*","MeshInstance3D",true,false)
 if meshes.is_empty() and body.get_parent():meshes=body.get_parent().find_children("*","MeshInstance3D",true,false)
 var area: float=-1
 for mesh: MeshInstance3D in meshes:
  if not mesh.mesh or actor.is_ancestor_of(mesh):continue
  var bounds: AABB=mesh.global_transform*mesh.mesh.get_aabb()
  if not bounds.grow(.05).has_point(hit.position) or bounds.size.x*bounds.size.z<=area:continue
  var material: Material=mesh.material_override if mesh.material_override else mesh.get_active_material(0)
  if material is StandardMaterial3D:ground_color=material.albedo_color;area=bounds.size.x*bounds.size.z

func _spawn(name: StringName, at: Vector3, params: Dictionary) -> void:
 if not manager or not manager.enabled or not manager.warmup_complete:return
 params.color=Color(1.0,.83,.56) if name==&"Sparks" else ground_color;params.ground_y=ground_y;params.actor=actor
 params.particle_limit=BUDGETS[manager.quality]-AIR_COUNTS[manager.quality]
 var effect: Node3D=manager.try_spawn(name,at,params)
 if effect:leases.append({"effect":effect,"lease":effect.lease_id});effect_spawned.emit(name,effect)

func trigger(origin: Vector3, radius: float, active_duration: float) -> void:
 stop()
 if manager and not manager.enabled:return
 clock=0;duration=active_duration;hits=0;emitting=true;previous_valid=false;_ground(origin)
 global_transform=Transform3D.IDENTITY;show();set_process(true)
 var at: Vector3=origin;at.y=ground_y
 _spawn(&"DustRing",at,{"radius":radius,"amount_scale":.9,"particle_lifetime":.6})
 var skeleton: Skeleton3D=actor.get_node("Visuals/CharacterModel/Gladiator_Armature/Skeleton3D") as Skeleton3D
 for name in ["foot.L","foot.R"]:
  var foot: Vector3=skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin;foot.y=ground_y
  _spawn(&"DustPuff",foot,{"scale":.85,"amount_scale":.5,"particle_lifetime":.45})
 for side in [-1.0,1.0]:
  _spawn(&"HeavyDust",at+actor.visuals.global_basis.x*side*.42,{"scale":.85,"amount_scale":.6,"particle_lifetime":.5,"direction":actor.visuals.global_basis.x*side+Vector3.UP*.15,"speed_min":1.5,"speed_max":2.6})
 _spawn(&"Debris",at,{"amount_scale":.5,"particle_lifetime":.75,"speed_min":1.4,"speed_max":2.4})
 air.restart();air.emitting=true

func _on_hit(target: Node, _damage: float, _blocked: bool) -> void:
 if not emitting or hits>=4 or not actor.active_ability_action or actor.active_ability_action.data.id!="whirling_blade" or not target is Node3D:return
 hits+=1
 var point: Vector3=(target as Node3D).global_position+Vector3.UP*.95
 var outward: Vector3=(point-actor.global_position).normalized()
 _spawn(&"Sparks",point,{"amount_scale":.6,"direction":outward,"speed_min":3.0,"speed_max":5.0})

func _process(delta: float) -> void:
 if not is_instance_valid(actor) or actor.is_dead or (manager and not manager.enabled):stop();return
 clock+=delta
 for i in TRAIL_SLOTS:
  ages[i]+=delta
  var color: Color=Color(.90,.87,.77,maxf(0,1-ages[i]/TRAIL_LIFE)*.65)
  batch.set_instance_color(i,color)
 if clock>=duration:emitting=false;air.emitting=false
 if emitting and base_socket and tip_socket:
  var b: Vector3=base_socket.global_position;var t: Vector3=tip_socket.global_position
  air.global_position=b.lerp(t,.82)
  if previous_valid:
   var current: Vector3=b.lerp(t,.76);var last: Vector3=previous_base.lerp(previous_tip,.76)
   var movement: Vector3=current-last;var across: Vector3=((t-b)+(previous_tip-previous_base))*.30
   if movement.length()>.003 and movement.length()<1.5:
    batch.set_instance_transform(cursor,Transform3D(Basis(across,movement,across.cross(movement).normalized()),(current+last)*.5))
    ages[cursor]=0;cursor=(cursor+1)%TRAIL_SLOTS;air_motion.direction=movement.normalized()
  previous_base=b;previous_tip=t;previous_valid=true
 if clock>=duration+TRAIL_LIFE:hide();set_process(false)

func active_particles() -> int:
 var count: int=AIR_COUNTS[manager.quality] if manager and air.emitting else 0
 for item in leases:
  if is_instance_valid(item.effect) and item.effect.active and item.effect.lease_id==item.lease:count+=item.effect.effective_particles()
 return count

func stop() -> void:
 emitting=false;previous_valid=false;hide();set_process(false)
 if air:air.emitting=false
 if batch:
  ages.fill(TRAIL_LIFE)
  for i in TRAIL_SLOTS:batch.set_instance_color(i,Color(1,1,1,0))
 for item in leases:
  if is_instance_valid(manager) and is_instance_valid(item.effect) and item.effect.active and item.effect.lease_id==item.lease:manager.release(item.effect)
 leases.clear()

func _exit_tree() -> void:stop()
