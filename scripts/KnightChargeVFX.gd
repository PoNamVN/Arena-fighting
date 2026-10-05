extends Node
## Z presentation only. Invoked by existing phase/movement/impact hooks.
var actor: CharacterBody3D
var manager: Node
var skeleton: Skeleton3D
var _feet := PackedInt32Array()
var _shield_edge := Vector3.ZERO
var _ground_query: PhysicsRayQueryParameters3D
var ground_y := 0.0
var ground_color := Color("c9b48a")
var casting := false
var trailing := false
var _trail_clock := 0.0
var _trail_side := 0
var wind: MeshInstance3D
var _flow_clock := 0.0
var _recoil_clock := 0.0
var _recoil_pending := false
var _impact_clock := 0.0
var _shield_recoil := false
var _shield_recoil_start := Transform3D.IDENTITY
var _leases: Array[Dictionary] = []
var air_burst:Node3D
var _terminal_impact:=false
var _settle_clock:=-1.0
var _settle_at:=Vector3.ZERO
signal effect_spawned(event: StringName, effect: StringName, instance: Node3D)

func _ready() -> void:
 actor = get_parent() as CharacterBody3D
 manager = get_node_or_null("/root/VFXManager")
 skeleton = actor.visuals.find_child("Skeleton3D",true,false) as Skeleton3D
 if skeleton:
  for bone in ["foot.L","foot.R"]:
   _feet.append(skeleton.find_bone(bone))
 _ground_query = PhysicsRayQueryParameters3D.new()
 _ground_query.collision_mask = 1
 _ground_query.exclude = [actor.get_rid()]
 if actor._z_shield_mesh and actor._z_shield_mesh.mesh:
  var maximum := -INF
  for surface in actor._z_shield_mesh.mesh.get_surface_count():
   var vertices: PackedVector3Array = actor._z_shield_mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for vertex in vertices:
    var local: Vector3 = actor._z_shield_mesh.transform * vertex
    if local.x > maximum:
     maximum = local.x
     _shield_edge = local
 if actor._z_shield_mesh:
  wind = preload("res://scripts/KnightShieldWind.gd").new()
  wind.name = "ShieldAirflow"
  actor._z_shield_visual_root.add_child(wind)
  wind.configure(actor._z_shield_mesh)
 air_burst=preload("res://scripts/KnightRamBurst.gd").new()
 air_burst.name="ShieldPressureWave"
 add_child(air_burst)
 set_process(true)

func _sample_ground() -> void:
 ground_y = actor.global_position.y
 _ground_query.from = actor.global_position+Vector3.UP*0.4
 _ground_query.to = actor.global_position-Vector3.UP*2.0
 var hit := actor.get_world_3d().direct_space_state.intersect_ray(_ground_query)
 if hit.is_empty():
  return
 ground_y = hit.position.y
 var collider := hit.collider as Node
 if not collider:
  return
 if collider.has_meta("ground_color"):
  ground_color = collider.get_meta("ground_color")
  return
 var receiver := collider
 if receiver.find_children("*","MeshInstance3D",true,false).is_empty():
  receiver = collider.get_parent()
 var area := -1.0
 for mesh: MeshInstance3D in receiver.find_children("*","MeshInstance3D",true,false):
  if not mesh.mesh or actor.is_ancestor_of(mesh):
   continue
  var bounds: AABB = mesh.global_transform*mesh.mesh.get_aabb()
  var candidate := bounds.size.x*bounds.size.z
  if candidate <= area or not bounds.grow(0.03).has_point(hit.position):
   continue
  var mat: Material = mesh.material_override if mesh.material_override else mesh.get_active_material(0)
  if mat is StandardMaterial3D:
   ground_color = mat.albedo_color
   area = candidate

func _foot(side: int) -> Vector3:
 var result := actor.global_position
 if skeleton and side < _feet.size() and _feet[side] >= 0:
  result = skeleton.global_transform*skeleton.get_bone_global_pose(_feet[side]).origin
 result.y = ground_y
 return result

func _prune() -> void:
 for i in range(_leases.size()-1,-1,-1):
  var item := _leases[i]
  if not is_instance_valid(item.effect) or not item.effect.active or item.effect.lease_id != item.lease:
   _leases.remove_at(i)

func active_trails() -> int:
 _prune()
 var count := 0
 for item in _leases:
  if item.event == &"trail": count += 1
 return count

func _spawn(event: StringName, effect: StringName, at: Vector3, params: Dictionary) -> Node3D:
 if not manager or not manager.warmup_complete or not actor.is_inside_tree():
  return null
 # Z uses a bounded presentation budget; other skills keep their default limits.
 params.particle_limit=[240,400,600][manager.quality]
 params.actor = actor
 params.ground_y = ground_y
 if effect != &"Sparks":
  params.color = ground_color
 var instance: Node3D = manager.try_spawn(effect,at,params)
 if instance:
  _prune()
  _leases.append({"effect":instance,"lease":instance.lease_id,"event":event})
  effect_spawned.emit(event,effect,instance)
 return instance

func start() -> void:
 stop(true,false)
 _sample_ground()
 _terminal_impact=false
 _settle_clock=-1.0
 casting = true
 trailing = true
 _trail_clock = 0.05
 _trail_side = 0
 _flow_clock = 0.0
 _recoil_clock = 0.0
 _recoil_pending = false
 _impact_clock = 0.0
 for side in 2:
  _spawn(&"start",&"DustPuff",_foot(side),{"scale":0.65,"amount_scale":0.45,"particle_lifetime":0.4})
 _spawn(&"start",&"DustRing",actor.global_position,{"scale":1.0,"radius":1.15,"amount_scale":0.65,"particle_lifetime":0.45})

func tick(delta: float, direction: Vector3) -> void:
 air_burst.update_burst(delta)
 if not casting:
  return
 if _settle_clock>=0.0:
  _settle_clock-=delta
  if _settle_clock<0.0:
   for side in [-1.0,1.0]:
    _spawn(&"settle",&"HeavyDust",_settle_at+direction.cross(Vector3.UP)*side*.65,{"scale":1.7,"amount_scale":.45,"particle_lifetime":.85,"alpha":.65,"direction":Vector3.UP,"speed_min":.15,"speed_max":.6})
 _flow_clock += delta
 _impact_clock = maxf(0.0,_impact_clock-delta)
 _recoil_clock = maxf(0.0,_recoil_clock-delta)
 if _shield_recoil and actor._z_shield_visual_root:
  var elapsed := 1.0-_recoil_clock/0.15
  var kick := sin(PI*elapsed)
  var transform := _shield_recoil_start
  transform.origin.z += 0.075*kick
  transform.basis = Basis(Vector3.RIGHT,deg_to_rad(6.0)*kick)*transform.basis
  actor._z_shield_visual_root.transform = transform
  actor._fit_z_shield_pose()
  if _recoil_clock <= 0.0:
   _shield_recoil = false
 var speed := Vector2(actor.velocity.x,actor.velocity.z).length()
 if wind:
  wind.update_flow(maxf(smoothstep(1.0,12.0,speed),_recoil_clock/.15 if _terminal_impact else 0.0),_flow_clock)
 if actor.anim_player:
  if _recoil_pending and _recoil_clock <= 0.0:
   _recoil_pending = false
   if not _terminal_impact:actor.anim_player.play("Knight_Z_Charge",0.06)
  if actor.anim_player.current_animation == "Knight_Z_Charge":
   actor.anim_player.speed_scale = clampf(speed/9.0,0.7,1.65)
 if not trailing:return
 _trail_clock -= delta
 if _trail_clock > 0.000001:
  return
 # At most one burst per update, never catch up with a long-frame burst flood.
 _trail_clock = maxf(0.001,_trail_clock+0.05)
 if active_trails() >= 8:
  return
 _spawn(&"trail",&"DustPuff",_foot(_trail_side),{"scale":0.52,"amount_scale":0.26,"particle_lifetime":0.36,"direction":-direction,"spread":20.0,"speed_min":0.7,"speed_max":1.2})
 _trail_side = 1-_trail_side

func impact(direction: Vector3,terminal:bool=false) -> void:
 if not casting:
  return
 # Multiple contacts in one physics frame share a single impact burst.
 if _impact_clock > 0.0:
  return
 _terminal_impact=terminal
 if terminal:trailing=false
 _impact_clock = 0.18
 _recoil_clock = 0.15
 _recoil_pending = true
 if actor._z_shield_visual_root and actor.active_ability_action and actor.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE:
  _shield_recoil_start = actor._z_shield_visual_root.transform
  _shield_recoil = true
 if actor.anim_player:
  actor.anim_player.speed_scale = 1.0
  actor.anim_player.play("Knight_Z_Impact",0.025)
 var at := actor.global_position
 if actor._z_shield_visual_root:
  at = actor._z_shield_visual_root.global_position
 at.y = ground_y
 if air_burst and actor._z_shield_visual_root:
  var shield_bounds:AABB=actor._z_shield_mesh.transform*actor._z_shield_mesh.mesh.get_aabb()
  var face:Vector3=actor._z_shield_visual_root.global_transform*Vector3(0,0,shield_bounds.end.z)
  air_burst.burst(face,direction)
 _settle_clock=.08;_settle_at=at
 # Three sizes of stone/soil establish weight before the dust fills the volume.
 for layer in [{"size":2.2,"up":.9,"low":3.5,"high":6.0,"spread":35.0},{"size":1.4,"up":.4,"low":4.0,"high":7.0,"spread":50.0},{"size":.8,"up":.08,"low":5.0,"high":8.0,"spread":60.0}]:
  _spawn(&"impact",&"Debris",at,{"scale":layer.size,"amount_scale":.9,"direction":(direction+Vector3.UP*layer.up).normalized(),"spread":layer.spread,"speed_min":layer.low,"speed_max":layer.high})
 if actor._z_shield_visual_root:
  var edge:Vector3=actor._z_shield_visual_root.global_transform*_shield_edge
  _spawn(&"impact",&"Sparks",edge,{"scale":2.0,"amount_scale":1.4,"direction":(direction+Vector3.UP*.3).normalized(),"spread":65.0,"speed_min":5.0,"speed_max":8.0,"color":Color(1,.82,.5)})
 _spawn(&"impact",&"DustRing",at,{"radius":3.2,"amount_scale":1.3,"particle_lifetime":.65,"scale":1.15,"alpha":.7})
 for angle in [-.85,-.5,-.15,.15,.5,.85]:
  var out:=direction.rotated(Vector3.UP,angle)
  _spawn(&"impact",&"HeavyDust",at+out*.15+Vector3.UP*.05,{"scale":1.4,"amount_scale":1.0,"particle_lifetime":.85,"direction":(out+Vector3.UP*.15).normalized(),"spread":26.0,"speed_min":2.8,"speed_max":5.2})
 for side in [-1.0,1.0]:
  _spawn(&"impact",&"DustPuff",at+direction.cross(Vector3.UP)*side*.35,{"scale":1.4,"amount_scale":.45,"particle_lifetime":.65,"alpha":.65,"direction":Vector3.UP,"speed_min":.5,"speed_max":1.2})
 _spawn(&"impact",&"Shockwave",at,{"radius":3.0})
 _spawn(&"impact",&"GroundDecal",at,{"radius":1.25,"scale":1.0})
 # Camera impulse is owned by the actual hit; hit-stop remains disabled.

func stop(cancelled: bool, emit_stop: bool = true) -> void:
 var was_casting := casting
 _settle_clock=-1.0
 if cancelled and air_burst:air_burst.clear()
 if _shield_recoil and actor and actor._z_shield_visual_root:
  actor._z_shield_visual_root.transform = _shield_recoil_start
 _shield_recoil = false
 if wind:
  wind.update_flow(0.0,_flow_clock)
 _recoil_clock = 0.0
 _recoil_pending = false
 if cancelled and actor and actor.anim_player and actor.anim_player.current_animation.begins_with("Knight_Z_"):
  actor.anim_player.stop()
  actor.anim_player.speed_scale = 1.0
  if actor.is_inside_tree():
   actor._update_locomotion_animations()
 casting = false
 trailing = false
 if cancelled and manager:
  for item in _leases:
   if is_instance_valid(item.effect) and item.effect.lease_id == item.lease:
    manager.release(item.effect)
  _leases.clear()
 if was_casting and emit_stop and actor and actor.is_inside_tree():
  _spawn(&"stop",&"DustPuff",_foot(0).lerp(_foot(1),0.5),{"scale":0.6,"amount_scale":0.35,"particle_lifetime":0.32})

func _process(delta:float) -> void:
 if not casting and air_burst.visible:air_burst.update_burst(delta)

func _exit_tree() -> void:
 stop(true,false)
