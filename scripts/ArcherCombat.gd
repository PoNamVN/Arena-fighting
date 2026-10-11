class_name ArcherCombat
extends Node

## Forest hunter: charged bow shots, homing fish/hawk Z, seeking X and forest escape.
const MAX_CHARGE: float = 1.2
const RANGE: float = 24.0
const CARRIED_ARROW_SPEED_RATIO := .9
const RECOVERY: float = 0.40
const COUNTER_RETREAT_DISTANCE: float = 3.2
const COUNTER_RETREAT_DURATION: float = 0.32
var seeking_active: bool = false
var seeking_elapsed: float = 0.0
var seeking_shots: int = 0
var seeking_target: Node3D
var dash_active: bool = false
var dash_elapsed: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var stealth_remaining: float = 0.0
var _stealth_meshes: Array[GeometryInstance3D] = []
var _stealth_surfaces: Array[Dictionary] = []
var _escape_effect: CPUParticles3D
var _seeking_material: StandardMaterial3D
var counter_active: bool = false
var counter_elapsed: float = 0.0
var counters_fired: int = 0
var _counter_target: Node3D
var _retreat_direction: Vector3 = Vector3.BACK
var hawk_skill: ArcherHawkSkill
const ARROW_SCENE: PackedScene = preload("res://assets/models/hunter_arrow.glb")
const BOW_SCENE: PackedScene = preload("res://assets/models/hunter_bow.glb")
var bait_ultimate: ArcherBaitUltimate
var actor: PlayerController
var charging: bool = false
var sky_aiming: bool = false
var _sky_pitch_rest: float = 0.0
var reticle_hud: ArcherReticleHUD
var charge_time: float = 0.0
var recovery_remaining: float = 0.0
var locked_target: Node3D
var shots_fired: int = 0
var hits_landed: int = 0
var _arrows: Array[Dictionary] = []
var _bow: Node3D
var _bow_attachment: BoneAttachment3D = null
var _is_bow_aim_parented: bool = false
const BOW_HAND_OFFSET: Vector3 = Vector3(0.02, 0.04, -0.01)
const BOW_HAND_ROTATION: Vector3 = Vector3(-0.35, 0.05, 2.95)
var _nocked_arrow: Node3D
const ArcherVFXManagerScript = preload("res://scripts/ArcherVFXManager.gd")
const ArcherCapePhysicsScript = preload("res://scripts/ArcherCapePhysics.gd")

var _strings: Array[MeshInstance3D] = []
var _label: Label
var _bar: ProgressBar
var _marker: MeshInstance3D
var _release_sound: AudioStreamPlayer3D
var _volley_trail_mesh: CylinderMesh
var _counter_trail_material: StandardMaterial3D
var _volley_trail_material: StandardMaterial3D
var _basic_trail_material: StandardMaterial3D
var _crit_trail_material: StandardMaterial3D
var vfx_manager: Node = null
var cape_physics: Node = null
var _pose_bones: Dictionary = {}
var _pose_rests: Dictionary = {}
var _pose_hands: Dictionary = {}
var _pose_elbows: Dictionary = {}
var _pose_delta: float = 1.0 / 60

func _ready() -> void:
	process_priority = 100
	if actor._skeleton:
		for side: String in ["L", "R"]:
			for bone: String in ["upper_arm.", "forearm.", "hand."]:
				var name: String = bone + side
				var index: int = actor._skeleton.find_bone(name)
				if index >= 0:
					_pose_bones[name] = index
					_pose_rests[name] = actor._skeleton.get_bone_global_rest(index)
			if _pose_rests.has("hand." + side):
				_pose_hands[side] = _pose_rests["hand." + side].origin
				_pose_elbows[side] = _pose_rests["forearm." + side].origin
	actor.block_damage_reduction = 0.65
	actor.shield_break_stun_duration = 0.65
	actor.dodge_controller.perfect_dodge_registered.connect(_record_counter_attacker)
	var hawk_data := AbilityData.new()
	hawk_data.id = "archer_hawk_fish"
	hawk_data.display_name = "Mồi cá — Diều hâu"
	hawk_data.stamina_cost = 25
	hawk_data.cooldown = 24
	hawk_data.damage = 24
	hawk_data.range = RANGE
	actor.ability_system.equip_ability("skill_1", hawk_data)
	hawk_skill = ArcherHawkSkill.new()
	hawk_skill.actor = actor
	hawk_skill.process_priority = 110
	add_child(hawk_skill)
	for spec: Array in [["skill_2", "archer_seeking_arrows", "Tên truy đuổi", 30.0, 8.0], ["skill_3", "archer_forest_escape", "Ẩn bước rừng", 25.0, 10.0]]:
		var ability: AbilityData = AbilityData.new()
		ability.id = spec[1]
		ability.display_name = spec[2]
		ability.stamina_cost = spec[3]
		ability.cooldown = spec[4]
		ability.damage = 14.0 if spec[0] == "skill_2" else 0.0
		ability.range = RANGE
		actor.ability_system.equip_ability(spec[0], ability)
	var ultimate: AbilityData = AbilityData.new()
	ultimate.id = "archer_trex_bait"
	ultimate.display_name = "Bữa săn T-rex"
	ultimate.stamina_cost = 100.0
	ultimate.requires_full_stamina = true
	ultimate.damage = 90.0
	ultimate.range = RANGE
	actor.ability_system.equip_ability("ultimate",ultimate)
	bait_ultimate = ArcherBaitUltimate.new()
	bait_ultimate.actor = actor
	add_child(bait_ultimate)
	_volley_trail_mesh = CylinderMesh.new()
	_volley_trail_mesh.top_radius = 0.008
	_volley_trail_mesh.bottom_radius = 0.008
	_volley_trail_mesh.height = 0.85
	_volley_trail_mesh.radial_segments = 6
	_volley_trail_material = StandardMaterial3D.new()
	_volley_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_volley_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_volley_trail_material.albedo_color = Color(0.65, 1.0, 0.24, 0.55)
	_counter_trail_material = _volley_trail_material.duplicate() as StandardMaterial3D
	_counter_trail_material.albedo_color = Color(1.0, 0.72, 0.16, 0.8)
	_seeking_material = _volley_trail_material.duplicate() as StandardMaterial3D
	_seeking_material.albedo_color = Color(0.25, 0.8, 1.0, 0.85)
	_basic_trail_material = _volley_trail_material.duplicate() as StandardMaterial3D
	_basic_trail_material.albedo_color = Color(0.25, 0.95, 0.55, 0.75)
	_crit_trail_material = _volley_trail_material.duplicate() as StandardMaterial3D
	_crit_trail_material.albedo_color = Color(1.0, 0.88, 0.22, 0.95)

	vfx_manager = ArcherVFXManagerScript.new()
	vfx_manager.name = "ArcherVFXManager"
	add_child(vfx_manager)
	vfx_manager.setup(self, actor)

	cape_physics = ArcherCapePhysicsScript.new()
	cape_physics.name = "ArcherCapePhysics"
	add_child(cape_physics)
	cape_physics.setup(actor)

	_bow = BOW_SCENE.instantiate() as Node3D
	_bow.name = "HunterBow"
	_ensure_bow_attachment()
	if _bow_attachment:
		_bow_attachment.add_child(_bow)
		_bow.position = BOW_HAND_OFFSET
		_bow.rotation = BOW_HAND_ROTATION
		_is_bow_aim_parented = false
	else:
		actor.visuals.add_child(_bow)
		_bow.position = Vector3(0.3, 0.9, 0)
		_bow.rotation = Vector3.ZERO
		_is_bow_aim_parented = true
	_nocked_arrow = ARROW_SCENE.instantiate() as Node3D
	_bow.add_child(_nocked_arrow)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.8, 0.73, 0.52)
	for i: int in range(2):
		var string: MeshInstance3D = MeshInstance3D.new()
		var cylinder: CylinderMesh = CylinderMesh.new()
		cylinder.top_radius = 0.003
		cylinder.bottom_radius = 0.003
		cylinder.height = 1.0
		cylinder.radial_segments = 6
		string.mesh = cylinder
		string.material_override = material
		_bow.add_child(string)
		_strings.append(string)
	_marker = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.53
	ring.outer_radius = 0.57
	ring.rings = 24
	ring.ring_segments = 6
	_marker.mesh = ring
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.6, 1.0, 0.25)
	_marker.material_override = ring_material
	actor.add_child(_marker)
	_marker.top_level = true
	_marker.visible = false
	_release_sound = AudioStreamPlayer3D.new()
	_release_sound.stream = preload("res://assets/audio/hunter_bow_release.wav")
	_release_sound.volume_db = -8.0
	actor.add_child(_release_sound)
	if not actor.external_controlled:
		_build_hud()
	_escape_effect = CPUParticles3D.new()
	_escape_effect.name = "ForestEscapeLeaves"
	_escape_effect.emitting = false
	_escape_effect.amount = 20
	_escape_effect.lifetime = 0.65
	_escape_effect.one_shot = true
	_escape_effect.explosiveness = 0.85
	_escape_effect.direction = Vector3.UP
	_escape_effect.spread = 80.0
	_escape_effect.initial_velocity_min = 1.0
	_escape_effect.initial_velocity_max = 3.5
	_escape_effect.gravity = Vector3(0, -4, 0)
	_escape_effect.scale_amount_min = 0.06
	_escape_effect.scale_amount_max = 0.14
	var leaf: PrismMesh = PrismMesh.new()
	leaf.size = Vector3(1, 0.15, 0.5)
	_escape_effect.mesh = leaf
	var leaf_material: StandardMaterial3D = StandardMaterial3D.new()
	leaf_material.albedo_color = Color(0.35, 0.8, 0.12)
	leaf_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_escape_effect.material_override = leaf_material
	actor.add_child(_escape_effect)
	_escape_effect.top_level = true
	_collect_stealth_meshes(actor.visuals)
	_update_bow()

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ultimate") and not event.is_echo():
		bait_ultimate.begin()
	elif event.is_action_pressed("skill_1") and not event.is_echo():
		start_hawk()
	elif event.is_action_pressed("skill_2") and not event.is_echo():
		start_seeking()
	elif event.is_action_pressed("skill_3") and not event.is_echo():
		start_escape()
	elif event.is_action_pressed("attack") and not event.is_echo():
		if actor.is_counter_window_active():
			start_counter()
		else:
			start_charge()
	elif event.is_action_released("attack"):
		release_arrow()
	elif event.is_action_pressed("block"):
		start_block()
	elif event.is_action_released("block"):
		actor._release_block()
	elif event.is_action_pressed("dodge") and not event.is_echo():
		actor._try_dodge()

func start_charge() -> bool:
	if bait_ultimate.input_busy() or charging or hawk_skill.casting or seeking_active or dash_active or actor.is_control_impaired() or counter_active or actor.is_shield_broken or actor.is_shield_stunned or recovery_remaining > 0.0 or not actor.controls_enabled or actor.is_dead:
		return false
	if actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN] or actor._knockback_timer > 0.0:
		return false
	end_stealth()
	charging = true
	charge_time = 0.0
	if _hawk_shooting_window():
		_enter_sky_aim()
	locked_target = null if sky_aiming else _find_target()
	return true

func _hawk_shooting_window() -> bool:
	return is_instance_valid(hawk_skill.capture) and hawk_skill.capture.phase in [HawkCarryEffect.Phase.LIFT, HawkCarryEffect.Phase.CARRY]

func _enter_sky_aim() -> void:
	if sky_aiming: return
	sky_aiming = true
	_sky_pitch_rest = actor._camera_pitch
	actor._camera_pitch = deg_to_rad(50.0)
	actor._update_camera()

func _manual_aim_direction() -> Vector3:
	var origin := actor.global_position + Vector3(0, 1.35, 0)
	var camera := actor.camera
	var end := camera.global_position - camera.global_basis.z * RANGE
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, end, 1 | actor.combat.target_collision_mask)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return ((hit.position if not hit.is_empty() else end) - origin).normalized()

func start_hawk() -> bool:
	return hawk_skill.begin()

func _can_skill() -> bool:
	return not actor.is_control_impaired() and not bait_ultimate.input_busy() and actor.controls_enabled and not actor.is_dead and not actor.is_shield_broken and not actor.is_shield_stunned and not charging and not hawk_skill.casting and not seeking_active and not counter_active and not dash_active and recovery_remaining <= 0.0 and actor._knockback_timer <= 0.0 and actor.combat_state in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN]

func start_seeking() -> bool:
	if not _can_skill():
		return false
	var target: Node3D = _find_seeking_target()
	# Do not spend a targeting skill on empty space or through a wall.
	if not is_instance_valid(target) or not actor.ability_system.cast_ability("skill_2"):
		return false
	end_stealth()
	seeking_target = target
	locked_target = target
	seeking_active = true
	seeking_elapsed = 0.0
	seeking_shots = 0
	return true

func _find_seeking_target() -> Node3D:
	# Z already marked this enemy: X may keep that lock above or behind the caster.
	var carried := hawk_skill.target
	if _homing_target_alive(carried) and carried.get("hawk_carry") and carried.hawk_carry.active():
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.35, carried.global_position + Vector3.UP * .9, 1)
		ray.exclude = [actor.get_rid(), (carried as CollisionObject3D).get_rid()]
		if actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return carried
	return _find_target()

func start_escape() -> bool:
	# C can cancel charge/Z/guard, but not dodge, Counter or hit stun.
	if bait_ultimate.input_busy() or not actor.controls_enabled or actor.is_dead or actor.is_shield_broken or actor.is_shield_stunned or actor.is_control_impaired() or dash_active or counter_active or actor._knockback_timer > 0.0 or actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN, PlayerController.CombatState.BLOCK]:
		return false
	if not actor.ability_system.cast_ability("skill_3"):
		return false
	interrupt()
	actor._release_block()
	var input: Vector3 = actor.external_move_direction if actor.external_controlled else Basis(Vector3.UP, actor._camera_yaw) * Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_forward", "move_backward"))
	dash_direction = input.normalized() if input.length_squared() > 0.01 else Basis(Vector3.UP, actor._camera_yaw) * Vector3.FORWARD
	dash_direction.y = 0.0
	dash_direction = dash_direction.normalized()
	dash_active = true
	dash_elapsed = 0.0
	stealth_remaining = 2.5
	_set_stealth_visual(true)
	_escape_effect.global_position = actor.global_position + Vector3(0, 0.6, 0)
	_escape_effect.restart()
	if vfx_manager:
		vfx_manager.trigger_escape_whirlwind(actor.global_position + Vector3(0, 0.2, 0))
	return true

func process_escape_movement(delta: float) -> void:
	var step: float = minf(delta, 0.25 - dash_elapsed)
	actor.velocity.x = dash_direction.x * 20.0 * step / delta
	actor.velocity.z = dash_direction.z * 20.0 * step / delta
	actor.velocity.y -= actor.gravity * delta
	actor.move_and_slide()
	dash_elapsed += delta
	if dash_elapsed >= 0.25:
		dash_active = false
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		recovery_remaining = 0.20

func _collect_stealth_meshes(node: Node) -> void:
	if node is GeometryInstance3D:
		_stealth_meshes.append(node as GeometryInstance3D)
	if node is MeshInstance3D and node.mesh:
		for index: int in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(index)
			if original is StandardMaterial3D or original is ShaderMaterial:
				var faded: StandardMaterial3D = StandardMaterial3D.new()
				if original is StandardMaterial3D:
					faded = original.duplicate() as StandardMaterial3D
				elif original is ShaderMaterial:
					var alb: Variant = original.get_shader_parameter("albedo_color")
					faded.albedo_color = alb if alb is Color else Color(0.3, 0.5, 0.3, 1.0)
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				faded.albedo_color.a = 0.22
				faded.cull_mode = BaseMaterial3D.CULL_DISABLED
				_stealth_surfaces.append({"mesh": node, "index": index, "original": node.get_surface_override_material(index), "faded": faded})
	for child: Node in node.get_children():
		_collect_stealth_meshes(child)

func apply_archer_look() -> void:
	if actor and actor.has_method("apply_archer_look"):
		actor.apply_archer_look()

func update_cape(delta: float) -> void:
	if actor and actor.has_method("update_cape"):
		actor.update_cape(delta)

func trigger_hit_flash(color: Color = Color(1.0, 0.85, 0.85, 0.8), duration: float = 0.15) -> void:
	if actor and actor.has_method("trigger_archer_hit_flash"):
		actor.trigger_archer_hit_flash(color, duration)

func _set_stealth_visual(active: bool) -> void:
	# Local silhouette remains readable; enemies must respect targetability.
	for mesh: GeometryInstance3D in _stealth_meshes:
		mesh.transparency = 0.0
	# Material alpha also works in GL Compatibility, which ignores geometry fade.
	for surface: Dictionary in _stealth_surfaces:
		surface.mesh.set_surface_override_material(surface.index, surface.faded if active else surface.original)

func end_stealth() -> void:
	stealth_remaining = 0.0
	_set_stealth_visual(false)

func is_hidden() -> bool:
	return stealth_remaining > 0.0

func _homing_target_alive(target: Variant) -> bool:
	return is_instance_valid(target) and target != actor and target is CollisionObject3D and (target as CollisionObject3D).collision_layer & actor.combat.target_collision_mask != 0 and target.has_method("take_damage") and not (target is PlayerController and (target.is_dead or not target.is_targetable())) and not (target is TrainingDummy and target.is_dead())

func start_block() -> bool:
	if bait_ultimate.input_busy() or not actor.controls_enabled or actor.is_dead or actor.is_shield_broken or actor.is_shield_stunned or counter_active or dash_active or actor.combat_state == PlayerController.CombatState.DODGE:
		return false
	interrupt()
	return actor.transition_to(PlayerController.CombatState.BLOCK)

func _record_counter_attacker(payload: Variant) -> void:
	_counter_target = null
	var position: Vector3 = PlayerController.NO_ATTACKER_POS
	if payload is AttackPayload:
		_counter_target = payload.attacker
		position = payload.attacker_pos
	elif payload is Dictionary:
		_counter_target = payload.get("attacker", null) as Node3D
		position = payload.get("attacker_pos", position)
	if is_instance_valid(_counter_target):
		return
	# Older attacks carry position only. Resolve the source, not a nearer bystander.
	if position == PlayerController.NO_ATTACKER_POS:
		return
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = RANGE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = actor.global_position
	query.collision_mask = actor.combat.target_collision_mask
	query.exclude = [actor.get_rid()]
	var nearest: float = 4.0
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var candidate: Node3D = hit.collider as Node3D
		if candidate:
			var distance: float = candidate.global_position.distance_squared_to(position)
			if distance < nearest:
				_counter_target = candidate
				nearest = distance

func start_counter() -> bool:
	if bait_ultimate.input_busy() or not actor.controls_enabled or actor.is_dead or actor.is_control_impaired() or counter_active or actor.is_shield_broken or actor.is_shield_stunned or not actor.is_counter_window_active():
		return false
	if not is_instance_valid(_counter_target) or _counter_target == actor:
		return false
	if not _counter_target is CollisionObject3D or (_counter_target as CollisionObject3D).collision_layer & actor.combat.target_collision_mask == 0:
		return false
	if (_counter_target is PlayerController and _counter_target.is_dead) or (_counter_target is TrainingDummy and _counter_target.is_dead()):
		return false
	var origin: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	var offset: Vector3 = _counter_target.global_position + Vector3(0, 0.9, 0) - origin
	if offset.length() > RANGE or offset.length() < 0.01:
		return false
	interrupt()
	end_stealth()
	actor.dodge_controller.cancel_dodge()
	if not actor.transition_to(PlayerController.CombatState.COUNTER):
		return false
	actor.dodge_controller.consume_counter_window()
	var direction: Vector3 = offset.normalized()
	_retreat_direction = -Vector3(direction.x, 0, direction.z).normalized()
	actor._camera_yaw = atan2(-direction.x, -direction.z)
	actor.camera_pivot.rotation.y = actor._camera_yaw
	actor.visuals.rotation.y = actor._camera_yaw
	counter_active = true
	counter_elapsed = 0.0
	actor.velocity.y = 3.6 if actor.is_on_floor() else actor.velocity.y
	_spawn_arrow(direction, 38.0, 50.0, false, 20.0, true)
	_release_sound.pitch_scale = 0.65
	counters_fired += 1
	return true

func process_counter_movement(delta: float) -> void:
	var step: float = minf(delta, COUNTER_RETREAT_DURATION - counter_elapsed)
	actor.velocity.x = _retreat_direction.x * COUNTER_RETREAT_DISTANCE / COUNTER_RETREAT_DURATION * step / delta
	actor.velocity.z = _retreat_direction.z * COUNTER_RETREAT_DISTANCE / COUNTER_RETREAT_DURATION * step / delta
	actor.velocity.y -= actor.gravity * delta
	actor.move_and_slide()
	counter_elapsed += delta
	if counter_elapsed >= COUNTER_RETREAT_DURATION:
		counter_active = false
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		recovery_remaining = 0.30
		actor.transition_to(PlayerController.CombatState.IDLE)

func interrupt() -> void:
	if bait_ultimate and bait_ultimate.phase == ArcherBaitUltimate.Phase.AIM:
		bait_ultimate.stop()
	cancel_charge()
	if dash_active:
		dash_active = false
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
	if seeking_active:
		seeking_active = false
		seeking_target = null
		recovery_remaining = maxf(recovery_remaining, 0.35)
	if counter_active:
		counter_active = false
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		if actor.combat_state == PlayerController.CombatState.COUNTER:
			actor.transition_to(PlayerController.CombatState.IDLE)
		recovery_remaining = maxf(recovery_remaining, 0.30)
	if hawk_skill:
		hawk_skill.interrupt()

func cancel_charge() -> void:
	charging = false
	if sky_aiming:
		actor._camera_pitch = _sky_pitch_rest
	sky_aiming = false
	actor._update_camera()
	charge_time = 0.0
	locked_target = null
	if _marker:
		_marker.visible = false

func clear_projectiles() -> void:
	for arrow: Dictionary in _arrows:
		if is_instance_valid(arrow.node):
			arrow.node.queue_free()
	_arrows.clear()

func reset() -> void:
	interrupt()
	if hawk_skill: hawk_skill.stop()
	if bait_ultimate:
		bait_ultimate.stop()
	end_stealth()
	clear_projectiles()
	if _escape_effect:
		_escape_effect.emitting = false
	recovery_remaining = 0.0
	_counter_target = null

func release_arrow() -> bool:
	if not charging:
		return false
	if not actor.controls_enabled or actor.is_dead or actor._knockback_timer > 0.0:
		cancel_charge()
		return false
	# Revalidate at release: no stale lock through a wall or onto a dead target.
	if sky_aiming or _hawk_shooting_window() or not _target_valid(locked_target):
		locked_target = null
	var origin: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	var direction: Vector3 = -actor.camera.global_basis.z if actor.camera else -actor.visuals.global_basis.z
	if sky_aiming or _hawk_shooting_window():
		direction = _manual_aim_direction()
	if is_instance_valid(locked_target):
		direction = (locked_target.global_position + Vector3(0, 0.9, 0) - origin).normalized()
	var ratio: float = clampf(charge_time / MAX_CHARGE, 0.0, 1.0)
	var is_crit: bool = ratio >= 0.98
	_spawn_arrow(direction, lerpf(18.0, 34.0, ratio), lerpf(12.0, 36.0, ratio), true, 15.0, false, null, 0.0, is_crit)
	_release_sound.pitch_scale = lerpf(1.2, 0.85, ratio)
	cancel_charge()
	recovery_remaining = RECOVERY
	return true

func _spawn_arrow(direction: Vector3, speed: float, damage: float, basic: bool, shield_damage: float, counter: bool = false, homing: Node3D = null, orbit_phase: float = 0.0, is_crit: bool = false) -> void:
	var origin: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	var arrow: Node3D = ARROW_SCENE.instantiate() as Node3D
	actor.add_child(arrow)
	arrow.top_level = true
	arrow.global_position = origin
	arrow.look_at(origin + direction, Vector3.UP)
	if counter:
		arrow.scale = Vector3(3.0, 3.0, 2.4)
	elif is_crit:
		arrow.scale = Vector3(1.35, 1.35, 1.5)

	# Dynamic visual trail for ALL arrows
	var trail: MeshInstance3D = MeshInstance3D.new()
	trail.mesh = _volley_trail_mesh
	if is_crit:
		trail.material_override = _crit_trail_material
	elif basic:
		trail.material_override = _basic_trail_material
	else:
		trail.material_override = _seeking_material if is_instance_valid(homing) else (_counter_trail_material if counter else _volley_trail_material)
	trail.rotation.x = PI * 0.5
	trail.position.z = 0.42
	arrow.add_child(trail)

	# Trigger muzzle shockwave ring
	if vfx_manager:
		vfx_manager.trigger_muzzle_flash(origin, direction)

	# Sweep starts at the chest, including the muzzle segment. Never spawn past walls.
	_arrows.append({"node": arrow, "direction": direction, "speed": speed, "damage": damage, "distance": 0.0, "basic": basic, "shield_damage": shield_damage, "homing": homing, "spiral": is_instance_valid(homing), "guide": origin, "age": 0.0, "phase": orbit_phase, "goal": homing.global_position + Vector3(0, 0.9, 0) if is_instance_valid(homing) else origin + direction * RANGE, "is_crit": is_crit})
	if _arrows.size() > 12:
		var oldest: Dictionary = _arrows.pop_front()
		oldest.node.queue_free()
	if actor.spectacle:
		actor.spectacle.shooting()
	shots_fired += 1
	_release_sound.pitch_scale = 1.3 if not basic else 1.0
	_release_sound.play()

func _physics_process(delta: float) -> void:
	if not actor.controls_enabled or actor.is_dead or actor.is_control_impaired():
		reset()
		return
	if stealth_remaining > 0.0:
		stealth_remaining = maxf(0.0, stealth_remaining - delta)
		if stealth_remaining <= 0.0:
			end_stealth()
	if seeking_active:
		seeking_elapsed += delta
		if not _homing_target_alive(seeking_target) or actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN] or actor._knockback_timer > 0.0 or not actor._is_mouse_captured:
			seeking_active = false
			recovery_remaining = 0.35
		else:
			while seeking_shots < 3 and seeking_elapsed >= 0.28:
				var offset: Vector3 = seeking_target.global_position + Vector3(0, 0.9, 0) - (actor.global_position + Vector3(0, 1.35, 0))
				var direction: Vector3 = offset.normalized()
				_spawn_arrow(direction, 20.0, 14.0, false, 8.0, false, seeking_target, TAU * float(seeking_shots) / 3.0)
				seeking_shots += 1
			if seeking_shots == 3:
				seeking_active = false
				recovery_remaining = 0.35
	recovery_remaining = maxf(0.0, recovery_remaining - delta)
	if charging:
		var mouse_ok: bool = actor._is_mouse_captured or DisplayServer.get_name() == "headless"
		if actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN] or actor._knockback_timer > 0.0 or not mouse_ok:
			cancel_charge()
		else:
			charge_time = minf(MAX_CHARGE, charge_time + delta)
			if _hawk_shooting_window():
				_enter_sky_aim()
			if sky_aiming:
				locked_target = null
			elif not _target_valid(locked_target):
				locked_target = _find_target()
			if is_instance_valid(locked_target):
				var to_target: Vector3 = locked_target.global_position - actor.global_position
				var yaw: float = atan2(-to_target.x, -to_target.z)
				actor._camera_yaw = lerp_angle(actor._camera_yaw, yaw, minf(1.0, delta * 8.0))
				actor.camera_pivot.rotation.y = actor._camera_yaw
				actor.visuals.rotation.y = actor._camera_yaw
	for i: int in range(_arrows.size() - 1, -1, -1):
		var data: Dictionary = _arrows[i]
		var node: Node3D = data.node
		var step_count: int = maxi(1, ceili(delta / (1.0 / 120.0))) if data.spiral else 1
		var hit: Dictionary = {}
		var incoming: Vector3 = node.global_position
		for substep: int in range(step_count):
			var dt: float = delta / float(step_count)
			var tracking: Variant = data.get("homing", null)
			var target: Node3D = tracking if is_instance_valid(tracking) else null
			var held := false
			if _homing_target_alive(target):
				data.goal = target.global_position + Vector3(0, 0.9, 0)
				var aerial: bool = target.get("hawk_carry") != null and target.hawk_carry.phase in [HawkCarryEffect.Phase.LIFT, HawkCarryEffect.Phase.CARRY]
				held = aerial
				if aerial:
					var carry: HawkCarryEffect = target.hawk_carry
					data.speed = TAU * carry.orbit_radius * HawkCarryEffect.ORBIT_SPEED_MULTIPLIER / HawkCarryEffect.CIRCLE_SECONDS * CARRIED_ARROW_SPEED_RATIO
					data.flight_range = data.speed * (HawkCarryEffect.CIRCLE_SECONDS + 4.0)
					data.follow_until_drop = true
					if carry.phase == HawkCarryEffect.Phase.CARRY:
						# Chase behind the hawk instead of cutting across its orbit into the victim.
						data.goal = carry.orbit_position(maxf(0, carry.elapsed - .4 - data.age * (1.0 - CARRIED_ARROW_SPEED_RATIO))) + Vector3.UP * .9
				var desired: Vector3 = (data.goal - data.guide).normalized()
				var angle: float = data.direction.angle_to(desired)
				data.direction = data.direction.slerp(desired, minf(1.0, deg_to_rad(1080.0 if data.get("follow_until_drop", false) else 110.0) * dt / maxf(angle, 0.001))).normalized()
			else:
				data.homing = null
			var from: Vector3 = node.global_position
			var flight_range: float = data.get("flight_range", RANGE)
			var travel: float = minf(data.speed * dt, flight_range - float(data.distance))
			data.distance += travel
			data.age += dt
			var to: Vector3 = from + data.direction * travel
			if data.spiral:
				data.guide += data.direction * travel
				# Three synchronized helices,120 degrees apart. Open from the muzzle,
				# hold a wide orbit, then taper into the target over the final3.2m.
				var remaining: float = data.guide.distance_to(data.goal)
				var radius: float = 0.95 * smoothstep(0.0, 1.6, data.distance) * smoothstep(0.35, 3.2, remaining)
				var right: Vector3 = data.direction.cross(Vector3.UP).normalized()
				if right.length_squared() < 0.01:
					right = Vector3.RIGHT
				var up: Vector3 = right.cross(data.direction).normalized()
				var phase: float = data.phase + data.age * TAU * 2.4
				to = data.guide + (right * cos(phase) + up * sin(phase)) * radius
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1 | actor.combat.target_collision_mask)
			query.exclude = [actor.get_rid()]
			# Z owns the held victim; X can hit it once release begins the fall.
			if held: query.exclude = [actor.get_rid(), (target as CollisionObject3D).get_rid()]
			hit = actor.get_world_3d().direct_space_state.intersect_ray(query)
			incoming = from
			if not hit.is_empty():
				break
			if to.distance_squared_to(from) > 0.000001:
				node.look_at(to + (to - from).normalized(), Vector3.UP)
			node.global_position = to
			if data.spiral:
				_draw_spiral_trail(data, from, to)
			if data.distance >= flight_range:
				break
		if not hit.is_empty():
			_impact(hit.collider, data.damage, incoming, hit.position, data.basic, data.shield_damage)
			node.queue_free()
			_arrows.remove_at(i)
		elif data.distance >= float(data.get("flight_range", RANGE)):
			node.queue_free()
			_arrows.remove_at(i)

func _draw_spiral_trail(data: Dictionary, from: Vector3, to: Vector3) -> void:
	if not data.has("trail_segments"):
		data.trail_segments = []
		data.trail_segments.resize(28)
		data.trail_index = 0
		data.trail_count = 0
		var trail: MultiMeshInstance3D = MultiMeshInstance3D.new()
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		trail.material_override = _seeking_material
		var batch: MultiMesh = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _volley_trail_mesh
		batch.instance_count = 28
		batch.visible_instance_count = 0
		trail.multimesh = batch
		data.node.add_child(trail)
		trail.top_level = true
		trail.global_transform = Transform3D.IDENTITY
		data.trail_batch = batch
	var offset: Vector3 = to - from
	if offset.length_squared() <= 0.000001:
		return
	var transform: Transform3D = Transform3D(Basis(Quaternion(Vector3.UP, offset.normalized())) * Basis.from_scale(Vector3(2.5, offset.length() / 0.85, 2.5)), (to + from) * 0.5)
	data.trail_segments[data.trail_index] = transform
	data.trail_batch.set_instance_transform(data.trail_index, transform)
	data.trail_count = mini(28, data.trail_count + 1)
	data.trail_batch.visible_instance_count = data.trail_count
	data.trail_index = (data.trail_index + 1) % 28

func _impact(target: Object, damage: float, incoming_position: Vector3, position: Vector3, basic: bool = true, shield_damage: float = 15.0) -> void:
	var actual: float = 0.0
	var blocked: bool = false
	if target is PlayerController:
		var receiver: PlayerController = target as PlayerController
		var before: float = receiver.health_component.current_health
		blocked = receiver.is_blocking and actor.combat.is_attack_inside_block_cone(receiver, incoming_position, receiver.block_cone_deg)
		var payload: AttackPayload = AttackPayload.new(damage, incoming_position, shield_damage, true)
		payload.attacker = actor
		receiver.take_damage(payload, incoming_position)
		actual = before - receiver.health_component.current_health
	elif target is TrainingDummy:
		var receiver: TrainingDummy = target as TrainingDummy
		var before: float = receiver.current_hp
		blocked = receiver.is_blocking and not receiver.is_shield_broken and actor.combat.is_attack_inside_block_cone(receiver, incoming_position, receiver.block_cone_deg)
		receiver.take_damage(damage * (1.0 - receiver.block_damage_reduction) if blocked else damage, incoming_position, blocked)
		if blocked:
			receiver.apply_shield_damage(shield_damage)
		actual = before - receiver.current_hp
	if actual > 0.0:
		hits_landed += 1
		if basic:
			actor.stamina_component.add_stamina(actor.stamina_component.attack_stamina_gain)
		actor.combat.hit_landed.emit(target, actual, blocked)
		actor.combat.spawn_damage_number(position, actual, blocked, shield_damage if blocked else 0.0)
		if actor.combat_feedback:
			actor.combat_feedback.trigger_hit_feedback(target, actual)
		if blocked:
			actor.combat.trigger_block_impact(position, (position - incoming_position).normalized())
		else:
			actor.combat.trigger_hit_impact(position, (position - incoming_position).normalized())
		if vfx_manager:
			vfx_manager.trigger_arrow_impact(position, (position - incoming_position).normalized(), damage >= 28.0)

func _target_valid(target: Node3D) -> bool:
	if not is_instance_valid(target) or target == actor or not target is CollisionObject3D or not target.has_method("take_damage"):
		return false
	if (target as CollisionObject3D).collision_layer & actor.combat.target_collision_mask == 0:
		return false
	if target is PlayerController and (target.is_dead or not target.is_targetable()):
		return false
	if target is TrainingDummy and target.is_dead():
		return false
	var from: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	var to: Vector3 = target.global_position + Vector3(0, 0.9, 0)
	var offset: Vector3 = to - from
	if offset.length() > RANGE or offset.length() < 0.01:
		return false
	var forward: Vector3 = Basis(Vector3.UP, actor._camera_yaw) * Vector3.FORWARD
	var flat: Vector3 = Vector3(offset.x, 0, offset.z).normalized()
	if forward.dot(flat) < cos(deg_to_rad(55.0)):
		return false
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	ray.exclude = [actor.get_rid(), (target as CollisionObject3D).get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _find_target() -> Node3D:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = RANGE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = actor.global_position
	query.collision_mask = actor.combat.target_collision_mask
	query.exclude = [actor.get_rid()]
	var best: Node3D
	var nearest: float = INF
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var candidate: Node3D = hit.collider as Node3D
		if _target_valid(candidate):
			var distance: float = actor.global_position.distance_squared_to(candidate.global_position)
			if distance < nearest:
				best = candidate
				nearest = distance
	return best

func _process(_delta: float) -> void:
	_pose_delta = _delta
	if actor.spectacle and (charging or seeking_active or hawk_skill.casting):
		actor.spectacle.wake()
	_update_bow()
	if vfx_manager:
		var bow_pos: Vector3 = _nocked_arrow.global_position if is_instance_valid(_nocked_arrow) else (_bow.global_position if _bow else actor.global_position + Vector3(0, 1.35, 0))
		vfx_manager.update_charge_vfx(charging, charge_time / MAX_CHARGE, bow_pos)
	if _label:
		_label.visible = actor.controls_enabled and not actor.is_dead
		_bar.visible = _label.visible and charging
		_bar.value = charge_time / MAX_CHARGE * 100.0
		_label.text = ("COUNTER · TÊN LỚN + BẬT LÙI" if counter_active else ("PERFECT DODGE · PHẢN CÔNG SẴN SÀNG" if actor.is_counter_window_active() else ("ĐỠ BẰNG CUNG" if actor.is_blocking else ("MỒI CÁ · DIỀU HÂU" if hawk_skill.casting else ("ĐÃ KHÓA MỤC TIÊU" if charging and is_instance_valid(locked_target) else ("NGẮM TỰ DO" if charging else ""))))))
	if _label and bait_ultimate.active():
		_label.text += "\n" + bait_ultimate.status()
	if _label and sky_aiming:
		_label.text = "NGẮM LÊN TRỜI · THẢ CHUỘT TRÁI ĐỂ BẮN"
	elif _label and _hawk_shooting_window():
		_label.text += "\nGIỮ CHUỘT TRÁI · NGẮM LÊN TRỜI"
	if _label and seeking_active:
		_label.text += "\nTRUY ĐUỔI · KHÓA MỤC TIÊU · %d/3" % seeking_shots
	if _label and dash_active:
		_label.text += "\nẨN BƯỚC RỪNG"
	if _label and is_hidden():
		_label.text += "\nTÀNG HÌNH · %.1fs" % stealth_remaining
	_marker.visible = (charging or seeking_active) and is_instance_valid(locked_target)
	if _marker.visible:
		_marker.global_position = locked_target.global_position + Vector3(0, 0.05, 0)
		_marker.scale = Vector3.ONE * (1.15 if seeking_active else 1.0)

func _ensure_bow_attachment() -> void:
	if _bow_attachment == null and actor and actor._skeleton:
		_bow_attachment = BoneAttachment3D.new()
		_bow_attachment.name = "BowHandAttachment"
		_bow_attachment.bone_name = "hand.L"
		actor._skeleton.add_child(_bow_attachment)

func _update_bow() -> void:
	if actor.hawk_carry and actor.hawk_carry.active(): return
	_ensure_bow_attachment()
	var releasing: bool = recovery_remaining > (RECOVERY - 0.15)
	var aiming: bool = charging or hawk_skill.casting or seeking_active or counter_active or actor.is_blocking or bait_ultimate.input_busy() or releasing
	var ratio: float = charge_time / MAX_CHARGE if charging else (1.0 if releasing else 0.0)
	if seeking_active:
		ratio = clampf(seeking_elapsed / 0.28, 0.0, 1.0)
	if hawk_skill.casting:
		ratio = clampf(hawk_skill.elapsed / .3, 0, 1)
	if aiming:
		if not _is_bow_aim_parented:
			if _bow_attachment and _bow.get_parent() == _bow_attachment:
				_bow.reparent(actor.visuals, true)
			_is_bow_aim_parented = true
		if actor.is_blocking:
			_bow.position = Vector3(0.00, 1.35, -0.36)
			_bow.rotation = Vector3(0, 0, PI * 0.5)
		elif actor.is_third_person:
			# Third-person archery posture:
			# Left hand holds bow forward at natural reach, canted ~20 deg right
			_bow.position = Vector3(0.02, 1.35, -0.38)
			_bow.rotation = Vector3(deg_to_rad(3.0), deg_to_rad(-6.0), deg_to_rad(-20.0))
		else:
			# First-person archery posture:
			# Bow frames the lower right foreground, canted ~24 deg right, clear sightline down arrow
			_bow.position = Vector3(0.12, 1.35, -0.40)
			_bow.rotation = Vector3(deg_to_rad(2.0), deg_to_rad(-4.0), deg_to_rad(-24.0))
	else:
		if _is_bow_aim_parented:
			if _bow_attachment and is_instance_valid(_bow_attachment):
				if _bow.get_parent() != _bow_attachment:
					_bow.reparent(_bow_attachment, false)
				_bow.position = BOW_HAND_OFFSET
				_bow.rotation = BOW_HAND_ROTATION
				_is_bow_aim_parented = false
			else:
				_bow.position = Vector3(0.3, 0.9, 0)
				_bow.rotation = Vector3.ZERO
		elif not _bow_attachment:
			_bow.position = Vector3(0.3, 0.9, 0)
			_bow.rotation = Vector3.ZERO
	if counter_active:
		ratio = maxf(0.0, 1.0 - counter_elapsed / 0.12)
	if (sky_aiming or (_hawk_shooting_window() and releasing)) and not actor.is_blocking:
		var pitch := asin(clampf(_manual_aim_direction().y, -1.0, 1.0))
		var tilt := Basis(Vector3.RIGHT, pitch)
		_bow.position = Vector3(0, 1.35, 0) + tilt * (_bow.position - Vector3(0, 1.35, 0))
		_bow.basis = tilt * _bow.basis
	if bait_ultimate.input_busy():
		ratio = 0.75
	var draw_dist: float = 0.26
	_nocked_arrow.visible = aiming and not actor.is_blocking and not counter_active and not bait_ultimate.input_busy() and not releasing
	var nock_local_z: float = 0.10 if releasing else (0.10 + ratio * draw_dist)
	_nocked_arrow.position = Vector3(0, 0, nock_local_z)
	var middle: Vector3 = Vector3(0, 0, nock_local_z)
	for i: int in range(2):
		var tip: Vector3 = Vector3(0, 0.58 if i == 0 else -0.58, 0.10)
		var offset: Vector3 = middle - tip
		_strings[i].position = (tip + middle) * 0.5
		_strings[i].quaternion = Quaternion(Vector3.UP, offset.normalized())
		_strings[i].scale = Vector3(1, offset.length(), 1)
	# Pose the two arms after locomotion animation; keep lower-body walking intact.
	# Skeleton local space has CharacterModel.rotation.y = PI, so +Z is FORWARD and +X is LEFT (-X is RIGHT).
	if aiming and actor._skeleton:
		if actor.is_blocking:
			# Blocking: Bow held horizontally across chest; both hands brace the bow limbs in front
			_pose_arm("L", Vector3(0.18, 1.34, 0.36), Vector3(0.35, 1.28, 0.18))
			_pose_arm("R", Vector3(-0.18, 1.34, 0.36), Vector3(-0.35, 1.28, 0.18))
		elif actor.is_third_person:
			# Third-person: Left hand directly grips bow handle
			var grip_skel: Vector3 = actor._skeleton.to_local(_bow.global_position)
			_pose_arm("L", grip_skel, Vector3(0.26, 1.25, 0.18))

			# Right hand directly tracks the arrow nock and bowstring:
			var nock_skel: Vector3 = actor._skeleton.to_local(_nocked_arrow.global_position)
			if releasing:
				nock_skel.z -= 0.04 # Follow-through release backwards

			# Right elbow pulls back dynamically with draw ratio:
			var elbow_r_x: float = -0.35
			var elbow_r_y: float = lerpf(1.25, 1.30, ratio)
			var elbow_r_z: float = lerpf(0.12, -0.40, ratio)
			_pose_arm("R", nock_skel, Vector3(elbow_r_x, elbow_r_y, elbow_r_z))
		else:
			# First-person: Left hand holds bow handle framing right side
			var grip_skel: Vector3 = actor._skeleton.to_local(_bow.global_position)
			_pose_arm("L", grip_skel, Vector3(0.18, 1.22, 0.22))

			# Right hand drawing nock:
			var nock_skel: Vector3 = actor._skeleton.to_local(_nocked_arrow.global_position)
			if releasing:
				nock_skel.z -= 0.04

			# Keep right elbow low and back in First Person so it NEVER obstructs the camera view!
			var elbow_r := Vector3(-0.35, 1.15, -0.35)
			_pose_arm("R", nock_skel, elbow_r)
	elif actor._skeleton:
		actor._skeleton.clear_bones_global_pose_override()

func _pose_arm(side: String, hand_position: Vector3, elbow: Vector3) -> void:
	if not _pose_bones.has("hand." + side):
		return
	var blend: float = 1.0 - exp(-16.0 * _pose_delta)
	_pose_hands[side] = (_pose_hands[side] as Vector3).lerp(hand_position, blend)
	_pose_elbows[side] = (_pose_elbows[side] as Vector3).lerp(elbow, blend)
	var upper_rest: Transform3D = _pose_rests["upper_arm." + side]
	var forearm_rest: Transform3D = _pose_rests["forearm." + side]
	var hand_rest: Transform3D = _pose_rests["hand." + side]
	var reach: Vector3 = _pose_hands[side] - upper_rest.origin
	var first_length: float = upper_rest.origin.distance_to(forearm_rest.origin)
	var second_length: float = forearm_rest.origin.distance_to(hand_rest.origin)
	var distance: float = clampf(reach.length(), absf(first_length - second_length) + 0.001, first_length + second_length - 0.001)
	var direction: Vector3 = reach.normalized()
	var hint: Vector3 = _pose_elbows[side] - upper_rest.origin
	var perpendicular: Vector3 = (hint - direction * hint.dot(direction)).normalized()
	if perpendicular.length_squared() < 0.001:
		perpendicular = direction.cross(Vector3.UP).normalized()
	var along: float = (first_length * first_length - second_length * second_length + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, first_length * first_length - along * along))
	var actual_elbow: Vector3 = upper_rest.origin + direction * along + perpendicular * height
	var goal: Vector3 = upper_rest.origin + direction * distance

	var dir_upper: Vector3 = (actual_elbow - upper_rest.origin).normalized()
	var upper_basis: Basis = Basis(Quaternion(upper_rest.basis.y.normalized(), dir_upper)) * upper_rest.basis
	actor._skeleton.set_bone_global_pose_override(_pose_bones["upper_arm." + side], Transform3D(upper_basis, upper_rest.origin), 1.0, true)

	var dir_forearm: Vector3 = (goal - actual_elbow).normalized()
	var forearm_basis: Basis = Basis(Quaternion(forearm_rest.basis.y.normalized(), dir_forearm)) * forearm_rest.basis
	actor._skeleton.set_bone_global_pose_override(_pose_bones["forearm." + side], Transform3D(forearm_basis, actual_elbow), 1.0, true)

func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	reticle_hud = ArcherReticleHUD.new()
	reticle_hud.name = "ArcherReticleHUD"
	layer.add_child(reticle_hud)
	reticle_hud.setup(self, actor)
	_label = Label.new()
	layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -380
	_label.offset_right = 380
	_label.offset_top = -210
	_label.offset_bottom = -150
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = ProgressBar.new()
	layer.add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -140
	_bar.offset_right = 140
	_bar.offset_top = -145
	_bar.offset_bottom = -125
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.33, 0.8, 0.15)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.10, 0.04, 0.9)
	background.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", background)
