class_name HawkCarryEffect
extends Node

enum Phase { IDLE, MARKED, LIFT, CARRY, FALL, RECOVER }
const HEIGHT := 14.0
const LIFT_SECONDS := 1.1
const CIRCLE_SECONDS := 2.2
const INVERT_SECONDS := .45
const RADIUS := 5.5
const THROW_SPEED := 3.5
var actor: Node3D
var source: Node
var phase := Phase.IDLE
var elapsed := 0.0
var total_elapsed := 0.0
var origin := Vector3.ZERO
var center := Vector3.ZERO
var fall_start := 0.0
var fall_hits := 0
var orbit_angle := 0.0
var _fall_velocity := 0.0
var _throw_velocity := Vector3.ZERO
var _visuals: Node3D
var _visual_rest := Transform3D.IDENTITY
var _bones: Dictionary = {}
var _camera_rest := Vector3.ZERO
var _camera_world_y := 0.0
var _camera_rotation_rest := Vector3.ZERO
var inversion := 0.0
var _camera_cull_rest := 0
var _body_layers: Array[Dictionary] = []
var _body_masked := false
var _air_ragdoll := false
const CARRIED_BODY_LAYER := 1 << 19

func active() -> bool:
	return phase != Phase.IDLE

func eligible() -> bool:
	if active() or _dead(): return false
	if actor is PlayerController:
		return actor.controls_enabled and not actor.is_control_impaired() and not actor.health_component.ability_invulnerable and not actor.health_component.training_invulnerable and not (actor.wizard_combat and actor.wizard_combat.storm.channeling())
	return actor is TrainingDummy and not actor.frost.active() and not actor.polymorph.active()

func begin(caster: Node) -> bool:
	if not eligible(): return false
	source = caster
	origin = actor.global_position
	center = origin - Vector3(RADIUS, 0, 0)
	elapsed = 0
	total_elapsed = 0
	fall_hits = 0
	orbit_angle = 0
	inversion = 0
	_fall_velocity = 0
	_throw_velocity = Vector3.ZERO
	actor.polymorph.cancel_actions()
	if actor is PlayerController:
		actor._knockback_timer = 0
		actor._knockback_vel = Vector3.ZERO
		actor.velocity = Vector3.ZERO
		if actor._hit_reaction_tween: actor._hit_reaction_tween.kill()
		if actor.anim_player: actor.anim_player.stop()
		process_priority = 140
		if actor._skeleton:
			actor._skeleton.clear_bones_global_pose_override()
			for index in range(actor._skeleton.get_bone_count()):
				_bones[index] = actor._skeleton.get_bone_pose_rotation(index)
		_camera_rotation_rest = actor.camera.rotation
		_camera_rest = actor.camera_pivot.position
		_camera_world_y = actor.camera_pivot.global_position.y
		_camera_cull_rest = actor.camera.cull_mask
		for mesh: GeometryInstance3D in actor.visuals.find_children("*", "GeometryInstance3D", true, false):
			_body_layers.append({"mesh": mesh, "layers": mesh.layers})
	else:
		if actor._knockback_tween: actor._knockback_tween.kill()
		if actor._flinch_tween: actor._flinch_tween.kill()
	_visuals = actor.get_node_or_null("Visuals") as Node3D
	if _visuals:
		_visuals.position = Vector3.ZERO
		_visuals.rotation.x = 0
		_visual_rest = _visuals.transform
	phase = Phase.MARKED
	return true

func _dead() -> bool:
	return not is_instance_valid(actor) or (actor.is_dead if actor is PlayerController else actor.is_dead())

func _physics_process(delta: float) -> void:
	# Players call step from their sole movement branch; static practice dummies use this.
	if actor is TrainingDummy and active(): step(delta)

func _process(delta: float) -> void:
	if not active(): return
	_pose()
	if actor is PlayerController:
		_hide_from_victim_camera(not actor.is_third_person)
		var eye_offset: float = lerpf(_camera_rest.y, 2.0 - _camera_rest.y, inversion) if not actor.is_third_person else _camera_rest.y
		var eye_y: float = actor.global_position.y + eye_offset
		actor.camera.rotation.z = _camera_rotation_rest.z + PI * inversion if not actor.is_third_person else _camera_rotation_rest.z
		_camera_world_y = lerpf(_camera_world_y, eye_y, 1 - exp(-12 * delta)) if actor.is_third_person else eye_y
		actor.camera_pivot.position.y = _camera_world_y - actor.global_position.y

func _hide_from_victim_camera(hidden: bool) -> void:
	if hidden == _body_masked: return
	_body_masked = hidden
	for item: Dictionary in _body_layers:
		if is_instance_valid(item.mesh): item.mesh.layers = CARRIED_BODY_LAYER if hidden else item.layers
	actor.camera.cull_mask = _camera_cull_rest & ~CARRIED_BODY_LAYER if hidden else _camera_cull_rest

func _set_phase(next: Phase) -> void:
	phase = next
	elapsed = 0
	if next == Phase.LIFT and actor is PlayerController and actor.ensure_ragdoll():
		# Seed the hanging pose once; the simulator owns every subsequent limb pose.
		_visuals.transform = _visual_rest * Transform3D(Basis(Vector3.FORWARD, PI), Vector3.UP * 2)
		actor._skeleton.force_update_all_bone_transforms()
		_air_ragdoll = actor.ragdoll.begin_hawk_grip()
		_visuals.transform = _visual_rest
	if is_instance_valid(source): source.carry_phase_changed(next)

func step(delta: float) -> void:
	if not active(): return
	if _dead() or not is_instance_valid(source) or (actor is PlayerController and not actor.controls_enabled):
		clear()
		return
	elapsed += delta
	total_elapsed += delta
	if total_elapsed > 6.5:
		clear()
		return
	match phase:
		Phase.MARKED:
			if elapsed >= .35: _set_phase(Phase.LIFT)
		Phase.LIFT:
			var goal := origin + Vector3.UP * HEIGHT * smoothstep(0, 1, minf(1, elapsed / LIFT_SECONDS))
			if not _move_to(goal):
				_start_fall()
			elif elapsed >= LIFT_SECONDS:
				_set_phase(Phase.CARRY)
		Phase.CARRY:
			orbit_angle = TAU * minf(1, elapsed / CIRCLE_SECONDS)
			var goal := center + Vector3(cos(orbit_angle) * RADIUS, HEIGHT, sin(orbit_angle) * RADIUS)
			if not _move_to(goal) or elapsed >= CIRCLE_SECONDS: _start_fall()
		Phase.FALL:
			_fall_velocity -= (actor.gravity if actor is PlayerController else 24.0) * delta
			if actor is PlayerController:
				actor.velocity = _throw_velocity + Vector3.UP * _fall_velocity
				actor.move_and_slide()
				if actor.is_on_floor(): _land()
			else:
				var hit := (actor as PhysicsBody3D).move_and_collide((_throw_velocity + Vector3.UP * _fall_velocity) * delta)
				if hit and hit.get_normal().y > .7: _land()
		Phase.RECOVER:
			if elapsed >= .2: clear(false)
	_pose()

func _move_to(goal: Vector3) -> bool:
	var before := actor.global_position
	var hit := (actor as PhysicsBody3D).move_and_collide(goal - actor.global_position)
	# Bounds run later too, but constrain now so the hawk/socket sees the same location.
	var bounds := actor.get_parent().find_child("ArenaPlayBounds", true, false)
	if bounds and actor is CharacterBody3D: bounds.constrain_actor(actor)
	if _air_ragdoll: actor.ragdoll.move_hawk_grip(actor.global_position - before)
	return hit == null and actor.global_position.distance_to(goal) < .12

func _start_fall() -> void:
	fall_start = actor.global_position.y
	_fall_velocity = -2
	_throw_velocity = Vector3(-sin(orbit_angle), 0, cos(orbit_angle)) * THROW_SPEED
	if _air_ragdoll: actor.ragdoll.release_hawk_grip(_throw_velocity + Vector3.UP * _fall_velocity)
	_set_phase(Phase.FALL)

func _land() -> void:
	if phase != Phase.FALL: return
	_set_phase(Phase.RECOVER)
	var damage := 20.0 * clampf((fall_start - actor.global_position.y) / HEIGHT, 0, 1)
	if damage > 0 and not _dead():
		fall_hits += 1
		if actor is PlayerController:
			var payload := AttackPayload.new(damage, PlayerController.NO_ATTACKER_POS, 0, false, false, 0)
			payload.can_be_blocked = false
			payload.attacker = source.actor
			actor.take_damage(payload)
		else:
			actor.take_damage(damage)
		if is_instance_valid(source): source.landed(actor.global_position, damage)
	if actor is PlayerController and not _dead():
		var victim: PlayerController = actor
		var tumble := _throw_velocity + Vector3.UP * .8
		var already_simulating := _air_ragdoll
		clear(false, already_simulating)
		if not already_simulating and victim.ensure_ragdoll(): victim.ragdoll.start_ragdoll(tumble, true)

func _pose() -> void:
	if not is_instance_valid(_visuals) or not active(): return
	match phase:
		Phase.LIFT: inversion = smoothstep(0, 1, minf(1, elapsed / INVERT_SECONDS))
		Phase.CARRY: inversion = 1
		Phase.FALL: inversion = 1 - smoothstep(0, 1, minf(1, elapsed / INVERT_SECONDS))
		_: inversion = 0
	if _air_ragdoll: return
	var sway := sin(total_elapsed * 5) * .04 * inversion
	# Rotate around body centre: feet end above the head without moving the physics capsule.
	_visuals.transform = _visual_rest * Transform3D(Basis(Vector3.FORWARD, PI * inversion + sway), Vector3.UP * 2 * inversion)
	if actor is PlayerController and actor._skeleton:
		var hanging := phase in [Phase.LIFT, Phase.CARRY]
		for index: int in _bones:
			var name: String = actor._skeleton.get_bone_name(index)
			var angle := 0.0
			if name.begins_with("forearm."): angle = .25 if hanging else .6
			elif name.begins_with("upper_arm."): angle = 2.6 * inversion if hanging else -.6
			elif name.begins_with("thigh."): angle = 0 if hanging else -.25
			elif name.begins_with("shin."): angle = .04 if hanging else .5
			elif name == "head": angle = -.1
			actor._skeleton.set_bone_pose_rotation(index, (_bones[index] as Quaternion) * Quaternion(Vector3.RIGHT, angle))

func grip_position() -> Vector3:
	# SkeletonModifier restores the animation pose after drawing; read the actual physics bodies.
	if _air_ragdoll and not actor.ragdoll._hawk_pins.is_empty(): return actor.ragdoll.hawk_grip_position()
	if actor is PlayerController and actor._skeleton:
		actor._skeleton.force_update_all_bone_transforms()
		var points: Array[Vector3] = []
		for name: String in ["foot.L", "foot.R"]:
			var index: int = actor._skeleton.find_bone(name)
			if index >= 0: points.append(actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(index).origin))
		if points.size() == 2: return (points[0] + points[1]) * .5
	return _visuals.to_global(Vector3(0, .1, 0)) if _visuals else actor.global_position + Vector3.UP * 2

func clear(safe_return: bool = true, preserve_ragdoll: bool = false) -> void:
	if not active(): return
	phase = Phase.IDLE
	if is_instance_valid(actor):
		if safe_return and actor.global_position.y > origin.y + .3:
			# This was collision-free when capture started; never strand a cancelled victim aloft.
			var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * .1, actor.global_position - Vector3.UP * (HEIGHT + 8), 1)
			query.exclude = [(actor as CollisionObject3D).get_rid()]
			var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
			if not floor_hit.is_empty():
				(actor as PhysicsBody3D).move_and_collide(floor_hit.position + Vector3.UP * .05 - actor.global_position)
		if actor is PlayerController:
			if _air_ragdoll and not preserve_ragdoll: actor.ragdoll.stop_ragdoll()
			actor.velocity = Vector3.ZERO
			actor._knockback_timer = 0
			if not preserve_ragdoll:
				if actor._skeleton: actor._skeleton.clear_bones_global_pose_override()
				for index: int in _bones:
					if actor._skeleton: actor._skeleton.set_bone_pose_rotation(index, _bones[index])
			actor.camera_pivot.position = _camera_rest
			actor.camera.rotation = _camera_rotation_rest
			_hide_from_victim_camera(false)
		if is_instance_valid(_visuals): _visuals.transform = _visual_rest
	var old_source := source
	source = null
	inversion = 0
	_air_ragdoll = false
	_bones.clear()
	_body_layers.clear()
	if is_instance_valid(old_source): old_source.carry_finished()
