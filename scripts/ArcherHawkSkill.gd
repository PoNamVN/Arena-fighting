class_name ArcherHawkSkill
extends Node

enum Phase { IDLE, STARTUP, FLIGHT, CAPTURE, EXIT, REBOUND }
var actor: PlayerController
var phase := Phase.IDLE
var elapsed := 0.0
var target: Node3D
var projectile: Node3D
var hawk: Node3D
var capture: HawkCarryEffect
var direction := Vector3.FORWARD
var travelled := 0.0
var casts := 0
var shots := 0
var grabs := 0
var landings := 0
var _exit_origin := Vector3.ZERO
var _animation: AnimationPlayer
var _skeleton: Skeleton3D
var _trail: MultiMeshInstance3D
var _trail_index := 0
var _trail_count := 0
var _effects: Array[Dictionary] = []
var _cry: AudioStreamPlayer3D
var _flap: AudioStreamPlayer3D
var _splash: AudioStreamPlayer3D
var _fish_tail: Node3D
var _wing_trails: Array[MultiMeshInstance3D] = []
var _wing_positions: Array[Vector3] = []
var _wing_index := 0
var _wing_count := 0
var _rebound_origin := Vector3.ZERO
var _fish_ring: MeshInstance3D
var _fish_ring_material: StandardMaterial3D
var _dive_gust_spawned := false

func _ready() -> void:
	_cry = _sound("res://assets/audio/hawk_z_cry.wav", -13)
	_flap = _sound("res://assets/audio/hawk_z_flap.wav", -18)
	_splash = _sound("res://assets/audio/hawk_z_splash.wav", -16)

func _sound(path: String, volume: float) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load(path)
	sound.volume_db = volume
	actor.add_child(sound)
	return sound

var casting: bool:
	get: return phase == Phase.STARTUP

func active() -> bool:
	return phase != Phase.IDLE

func begin() -> bool:
	if active() or not actor.archer_combat._can_skill(): return false
	var candidate := actor.archer_combat._find_target()
	if not is_instance_valid(candidate) or not candidate.get("hawk_carry") or not candidate.hawk_carry.eligible(): return false
	if not actor.ability_system.cast_ability("skill_1"): return false
	target = candidate
	phase = Phase.STARTUP
	elapsed = 0
	travelled = 0
	casts += 1
	return true

func interrupt() -> void:
	# Once released the fish/hawk is independent of the caster's ordinary recovery.
	if casting:
		actor.archer_combat.recovery_remaining = .25
		stop()

func _physics_process(delta: float) -> void:
	if not active(): return
	if actor.is_dead or not actor.controls_enabled:
		stop()
		return
	var room := actor.get_parent()
	if room is PracticeArena and room.round_state != PracticeArena.RoundState.FIGHT:
		stop()
		return
	elapsed += delta
	match phase:
		Phase.STARTUP:
			if actor.is_control_impaired() or actor._knockback_timer > 0:
				interrupt()
			elif elapsed >= .3:
				_launch()
		Phase.FLIGHT:
			_fly(delta)
		Phase.CAPTURE:
			if not is_instance_valid(capture) or not capture.active():
				carry_finished()
		Phase.EXIT:
			hawk.global_position = _exit_origin + Vector3(0, elapsed * 7, -elapsed * 8)
			_update_wing_trails()
			if elapsed >= .55: stop()
		Phase.REBOUND:
			var t := minf(1, elapsed / .28)
			projectile.global_position = _rebound_origin - direction * t * .6 + Vector3.UP * sin(t * PI) * .2
			projectile.rotation.z = t * PI
			if t >= 1: stop()

func _process(_delta: float) -> void:
	# Bone animation updates during process; align the visual after that, not one physics frame early.
	if phase == Phase.CAPTURE and is_instance_valid(capture) and capture.active():
		if _skeleton: _skeleton.force_update_all_bone_transforms()
		_update_hawk()

func _launch() -> void:
	if not actor.archer_combat._target_valid(target):
		stop()
		return
	projectile = _fish()
	actor.add_child(projectile)
	projectile.top_level = true
	projectile.global_position = actor.global_position + Vector3(0, 1.35, 0)
	direction = (target.global_position + Vector3.UP * .9 - projectile.global_position).normalized()
	projectile.look_at(projectile.global_position + direction)
	_fish_tail = projectile.find_child("FishTail*", true, false) as Node3D
	_trail = _new_trail(projectile)
	_trail_index = 0
	_trail_count = 0
	phase = Phase.FLIGHT
	elapsed = 0
	shots += 1
	actor.archer_combat.shots_fired += 1
	actor.archer_combat.recovery_remaining = .25
	actor.archer_combat._release_sound.play()
	if actor.spectacle: actor.spectacle.shooting()

func _fish() -> Node3D:
	return preload("res://assets/models/hunter_fish_arrow.glb").instantiate() as Node3D

func _new_trail(parent: Node3D) -> MultiMeshInstance3D:
	var trail := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	var mesh := CylinderMesh.new()
	mesh.top_radius = .014
	mesh.bottom_radius = .008
	mesh.height = 1
	mesh.radial_segments = 5
	batch.mesh = mesh
	batch.instance_count = 24
	batch.visible_instance_count = 0
	trail.multimesh = batch
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(.5, .9, .8, .45)
	trail.material_override = material
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(trail)
	trail.top_level = true
	trail.global_transform = Transform3D.IDENTITY
	return trail

func _segment(trail: MultiMeshInstance3D, index: int, count: int, from: Vector3, to: Vector3) -> void:
	var offset := to - from
	if offset.length_squared() < .000001: return
	trail.multimesh.set_instance_transform(index, Transform3D(Basis(Quaternion(Vector3.UP, offset.normalized())) * Basis.from_scale(Vector3(1, offset.length(), 1)), (from + to) * .5))
	for age in range(count):
		trail.multimesh.set_instance_color((index - age + 24) % 24, Color(1, 1, 1, pow(1 - float(age) / count, 2)))
	trail.multimesh.visible_instance_count = count
	trail.visible = get_tree().root.get_node("VFXManager").enabled

func _fly(delta: float) -> void:
	if actor.archer_combat._homing_target_alive(target):
		var wanted := (target.global_position + Vector3.UP * .9 - projectile.global_position).normalized()
		var angle := direction.angle_to(wanted)
		direction = direction.slerp(wanted, minf(1, deg_to_rad(100) * delta / maxf(.001, angle))).normalized()
	var from := projectile.global_position
	var travel := minf(22 * delta, 24 - travelled)
	var to := from + direction * travel
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | actor.combat.target_collision_mask)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	travelled += travel
	if not hit.is_empty():
		_impact(hit.collider, from, hit.position)
		return
	projectile.global_position = to
	projectile.look_at(to + direction)
	_trail_count = mini(24, _trail_count + 1)
	_segment(_trail, _trail_index, _trail_count, from, to)
	_trail_index = (_trail_index + 1) % 24
	if is_instance_valid(_fish_tail): _fish_tail.rotation.y = sin(elapsed * 28) * .18
	if travelled >= 24 or elapsed >= 1.5: stop()

func _impact(receiver: Object, incoming: Vector3, point: Vector3) -> void:
	if receiver != target or not actor.archer_combat._homing_target_alive(target):
		stop()
		return
	var direct := false
	var was_blocked := false
	if receiver is PlayerController:
		var payload := AttackPayload.new(4, incoming, 10, true)
		payload.attacker = actor
		payload.blocked_damage_override = 0
		payload.triggers_hit_reaction = false
		receiver.take_damage(payload, incoming)
		was_blocked = payload.outcome == &"blocked"
		direct = payload.outcome == &"hit" and not receiver.is_dead
	elif receiver is TrainingDummy:
		var blocked: bool = receiver.is_blocking and not receiver.is_shield_broken and actor.combat.is_attack_inside_block_cone(receiver, incoming, receiver.block_cone_deg)
		was_blocked = blocked
		if blocked:
			receiver.apply_shield_damage(10)
			actor.combat.trigger_block_impact(point, -direction)
		else:
			receiver.take_damage(4)
			direct = not receiver.is_dead() and not receiver.health_component.ability_invulnerable and not receiver.health_component.training_invulnerable
	if not direct or not receiver.hawk_carry.begin(self):
		if was_blocked and is_instance_valid(projectile):
			phase = Phase.REBOUND
			elapsed = 0
			_rebound_origin = point
			projectile.global_position = point
			if _trail: _trail.hide()
			_splash.global_position = point
			_splash.play()
			_effect(&"HawkWind", point, {"color": Color(.5, .85, 1, .6)})
		else:
			stop()
		return
	actor.archer_combat.end_stealth()
	capture = receiver.hawk_carry
	grabs += 1
	projectile.global_position = receiver.global_position + Vector3.UP * 1.35
	phase = Phase.CAPTURE
	elapsed = 0
	hawk = Node3D.new()
	hawk.add_child(preload("res://assets/models/forest_hawk.glb").instantiate())
	actor.add_child(hawk)
	hawk.top_level = true
	_animation = hawk.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeletons := hawk.find_children("*", "Skeleton3D", true, false)
	_skeleton = skeletons[0] as Skeleton3D if not skeletons.is_empty() else null
	if _animation and _animation.has_animation("carry_flap"):
		_animation.get_animation("carry_flap").loop_mode = Animation.LOOP_LINEAR
	for i in range(2):
		var wind_trail := _new_trail(hawk)
		var wind_mesh := wind_trail.multimesh.mesh as CylinderMesh
		wind_mesh.top_radius = .07
		wind_mesh.bottom_radius = .025
		(wind_trail.material_override as StandardMaterial3D).albedo_color = Color(.7, .9, 1, .65)
		_wing_trails.append(wind_trail)
		_wing_positions.append(Vector3.ZERO)
	_wing_index = 0
	_wing_count = 0
	# Keep nearby talons/fish out of the carried victim's FPS camera, while other cameras see them.
	for visual: Node3D in [hawk, projectile]:
		for mesh: GeometryInstance3D in visual.find_children("*", "GeometryInstance3D", true, false):
			mesh.layers = HawkCarryEffect.CARRIED_BODY_LAYER
	_trail.hide()
	_create_fish_ring()
	_dive_gust_spawned = false
	hawk.hide()
	_cry.global_position = receiver.global_position + Vector3.UP * 7
	_cry.play()
	_update_hawk()

func _create_fish_ring() -> void:
	_fish_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .97
	ring.outer_radius = 1.025
	ring.rings = 64
	ring.ring_segments = 6
	_fish_ring.mesh = ring
	_fish_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fish_ring.layers = HawkCarryEffect.CARRIED_BODY_LAYER
	_fish_ring_material = StandardMaterial3D.new()
	_fish_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fish_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fish_ring_material.albedo_color = Color(.05, .55, 1, .85)
	_fish_ring_material.emission_enabled = true
	_fish_ring_material.emission = Color(.05, .4, 1)
	_fish_ring_material.emission_energy_multiplier = 2.0
	_fish_ring.material_override = _fish_ring_material
	actor.add_child(_fish_ring)
	_fish_ring.top_level = true

func _update_hawk() -> void:
	var y := 2.3
	var dive_progress := 1.0
	if capture.phase == HawkCarryEffect.Phase.MARKED:
		var swim_seconds := HawkCarryEffect.MARK_SECONDS - HawkCarryEffect.DIVE_SECONDS
		dive_progress = clampf((capture.elapsed - swim_seconds) / HawkCarryEffect.DIVE_SECONDS, 0, 1)
		if capture.elapsed >= swim_seconds and not hawk.visible: _play_hawk("dive")
		y += 7 * (1 - smoothstep(0, 1, dive_progress))
		hawk.visible = capture.elapsed >= swim_seconds
		var fish_angle := TAU * capture.elapsed / swim_seconds
		var fish_center := capture.actor.global_position + Vector3.UP * 1.05
		projectile.global_position = fish_center + Vector3(cos(fish_angle), sin(fish_angle * 2) * .08, sin(fish_angle))
		projectile.look_at(projectile.global_position + Vector3(-sin(fish_angle), 0, cos(fish_angle)))
		if _fish_tail: _fish_tail.rotation.y = sin(capture.elapsed * 38) * .3
		_fish_ring.global_position = fish_center
		_fish_ring.visible = get_tree().root.get_node("VFXManager").enabled
		_fish_ring_material.albedo_color.a = .25 + .65 * (.5 + .5 * sin(capture.elapsed * TAU * 8))
		if dive_progress >= .75 and not _dive_gust_spawned:
			_dive_gust_spawned = true
			_effect(&"HawkWind", capture.origin + Vector3.UP * .08, {"ground": true, "strength": 1.0})
	else:
		hawk.show()
		projectile.hide()
		if _fish_ring: _fish_ring.hide()
	hawk.global_position = capture.actor.global_position + Vector3.UP * y
	hawk.rotation.x = .6 * (1 - dive_progress) if capture.phase == HawkCarryEffect.Phase.MARKED else 0
	if capture.phase == HawkCarryEffect.Phase.MARKED and dive_progress >= .7: _play_hawk("grab")
	if capture.phase == HawkCarryEffect.Phase.CARRY:
		hawk.rotation.y = PI - capture.orbit_angle
		hawk.rotation.z = -.12
	# Align both talons to the inverted victim's animated ankles using the animated rig, without parenting the actor.
	if capture.phase in [HawkCarryEffect.Phase.LIFT, HawkCarryEffect.Phase.CARRY]:
		var skeleton := _skeleton
		if skeleton:
			var left := skeleton.find_bone("foot.L")
			var right := skeleton.find_bone("foot.R")
			if left >= 0 and right >= 0:
				var claw_center := skeleton.to_global((skeleton.get_bone_global_pose(left).origin + skeleton.get_bone_global_pose(right).origin) * .5)
				hawk.global_position += capture.grip_position() - claw_center
	if capture.phase in [HawkCarryEffect.Phase.FALL, HawkCarryEffect.Phase.RECOVER]:
		projectile.hide()
		hawk.global_position.y = capture.fall_start + 2.3
	_update_wing_trails()

func _play_hawk(name: String) -> void:
	if _animation and _animation.has_animation(name) and _animation.current_animation != name:
		_animation.play(name, .05)

func _update_wing_trails() -> void:
	for i in range(_wing_trails.size()):
		# Skinned mesh node origins are fixed; use the deformed feather bone instead.
		var skeleton := _skeleton
		if not skeleton: continue
		var index := skeleton.find_bone("feathers.L" if i == 0 else "feathers.R")
		if index < 0: continue
		var point := skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
		if _wing_count > 0: _segment(_wing_trails[i], _wing_index, mini(24, _wing_count), _wing_positions[i], point)
		_wing_positions[i] = point
	_wing_index = (_wing_index + 1) % 24
	_wing_count += 1

func _effect(name: StringName, point: Vector3, params: Dictionary = {}) -> void:
	var effect: Node3D = get_tree().root.get_node("VFXManager").spawn(name, point, params)
	if effect: _effects.append({"node": effect, "lease": effect.lease_id})

func carry_phase_changed(next: int) -> void:
	match next:
		HawkCarryEffect.Phase.LIFT:
			if _fish_ring: _fish_ring.hide()
			if projectile: projectile.hide()
			hawk.show()
			_play_hawk("lift")
			_flap.pitch_scale = 1
			_flap.global_position = target.global_position + Vector3.UP * 2
			_flap.play()
			_effect(&"HawkWind", capture.origin + Vector3.UP * .08, {"ground": true, "strength": 1.4})
		HawkCarryEffect.Phase.CARRY: _play_hawk("carry_flap")
		HawkCarryEffect.Phase.FALL:
			_play_hawk("release")
			_effect(&"HawkWind", target.global_position, {"color": Color(.75, .9, 1, .5)})
			var ray := PhysicsRayQueryParameters3D.create(target.global_position, target.global_position - Vector3.UP * (HawkCarryEffect.HEIGHT + 8), 1)
			ray.exclude = [(target as CollisionObject3D).get_rid()]
			var floor_hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if not floor_hit.is_empty():
				_effect(&"HawkMark", floor_hit.position + Vector3.UP * .07, {"mark": true, "color": Color(1, .7, .25, .8)})

func landed(point: Vector3, damage: float) -> void:
	landings += 1
	actor.combat.spawn_damage_number(point + Vector3.UP, damage, false, 0)
	_effect(&"HawkLanding", point + Vector3.UP * .07, {"ground": true, "strength": .55, "color": Color(.85, .75, .55, .5)})
	_flap.global_position = point
	_flap.pitch_scale = .65
	_flap.play()

func carry_finished() -> void:
	capture = null
	if phase == Phase.IDLE: return
	if not is_instance_valid(hawk):
		stop()
		return
	_exit_origin = hawk.global_position
	phase = Phase.EXIT
	elapsed = 0
	_play_hawk("exit")

func stop() -> void:
	phase = Phase.IDLE
	if is_instance_valid(capture): capture.clear()
	capture = null
	phase = Phase.IDLE
	for node: Node3D in [projectile, hawk, _fish_ring]:
		if is_instance_valid(node): node.queue_free()
	projectile = null
	hawk = null
	_fish_ring = null
	_fish_ring_material = null
	target = null
	_animation = null
	_skeleton = null
	_trail = null
	_wing_trails.clear()
	_wing_positions.clear()
	for entry: Dictionary in _effects:
		if is_instance_valid(entry.node): entry.node.finish(entry.lease)
	_effects.clear()
	for sound: AudioStreamPlayer3D in [_cry, _flap, _splash]:
		if is_instance_valid(sound): sound.stop()

func _exit_tree() -> void:
	stop()
