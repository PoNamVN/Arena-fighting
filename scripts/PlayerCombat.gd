class_name PlayerCombat
extends Node3D

## Signals
signal hit_landed(target: Node, damage: float, was_blocked: bool)

## Configuration
@export var attack_damage: float = 25.0
@export var normal_attack_shield_damage: float = 15.0
@export var attack_range: float = 2.2
@export var attack_radius: float = 0.85
@export var attack_cooldown: float = 0.4
@export var target_collision_mask: int = 4 # Layer 3: Targets / Dummies
@export var wall_collision_mask: int = 1 # Layer 1: Environment / Walls

## Node References
@onready var visual_slash_cue: Node3D = get_node_or_null("VisualSlashCue") as Node3D
@onready var slash_arc_vfx: SlashArcVFX = get_node_or_null("SlashArcVFX") as SlashArcVFX
@onready var hit_impact_vfx: Node3D = get_node_or_null("HitImpactVFX") as Node3D
@onready var block_impact_vfx: Node3D = get_node_or_null("BlockImpactVFX") as Node3D
@onready var shield_break_vfx: Node3D = get_node_or_null("ShieldBreakVFX") as Node3D
@onready var damage_number_pool: DamageNumberPool = get_node_or_null("DamageNumberPool") as DamageNumberPool
@onready var attack_telegraph_vfx: AttackTelegraphVFX = get_node_or_null("AttackTelegraphVFX") as AttackTelegraphVFX
@onready var slash_effect: Node3D = slash_arc_vfx if slash_arc_vfx else visual_slash_cue
@onready var player: PlayerController = get_parent() as PlayerController
@onready var combat_feedback: CombatFeedback = player.get_node_or_null("CombatFeedback") as CombatFeedback if player else null

## VFX Configuration
@export var use_legacy_slash_cue: bool = false
@export var hit_stop_duration: float = 0.0

## Internal State
var _cooldown_timer: float = 0.0
var _slash_tween: Tween
var _cached_shape: SphereShape3D
var _damage_applied_this_swing: bool = false

var combo_step: int:
	get:
		return player.combo_step if player else 1

var combo_buffer: int:
	get:
		return player.combo_buffer if player else 0


func get_combo_step() -> int:
	return player.get_combo_step() if player else 1


func get_combo_buffer() -> int:
	return player.get_combo_buffer() if player else 0


func _ready() -> void:
	if visual_slash_cue:
		visual_slash_cue.visible = false
	if slash_arc_vfx:
		slash_arc_vfx.visible = false
	if hit_impact_vfx:
		hit_impact_vfx.visible = false
	if block_impact_vfx:
		block_impact_vfx.visible = false
	if shield_break_vfx:
		shield_break_vfx.visible = false
	if not damage_number_pool:
		damage_number_pool = get_node_or_null("DamageNumberPool") as DamageNumberPool
		if not damage_number_pool:
			damage_number_pool = DamageNumberPool.new()
			damage_number_pool.name = "DamageNumberPool"
			add_child(damage_number_pool)
	if not attack_telegraph_vfx:
		attack_telegraph_vfx = get_node_or_null("AttackTelegraphVFX") as AttackTelegraphVFX
		if not attack_telegraph_vfx:
			attack_telegraph_vfx = AttackTelegraphVFX.new()
			attack_telegraph_vfx.name = "AttackTelegraphVFX"
			add_child(attack_telegraph_vfx)
	_cached_shape = SphereShape3D.new()
	_cached_shape.radius = attack_radius


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func can_attack() -> bool:
	return _cooldown_timer <= 0.0


func start_attack() -> bool:
	if not can_attack():
		return false
	_cooldown_timer = attack_cooldown
	_damage_applied_this_swing = false
	if combat_feedback:
		combat_feedback.play_audio_event("attack_started")
	return true


func trigger_attack_telegraph(direction: Vector3, windup: float = 0.35) -> void:
	if attack_telegraph_vfx:
		var origin: Vector3 = player.global_position if player else global_position
		attack_telegraph_vfx.trigger(origin, direction, windup, player)


func execute_impact() -> bool:
	if _damage_applied_this_swing:
		return false # Guard: Each attack swing can deal damage only once
	_damage_applied_this_swing = true
	if attack_telegraph_vfx:
		attack_telegraph_vfx.stop()
	_perform_attack()
	return true


func try_attack() -> bool:
	# Deprecated direct method: kept for backwards compatibility
	if start_attack():
		execute_impact()
		return true
	return false


func _perform_attack() -> void:
	var world_3d: World3D = get_world_3d()
	if not world_3d or not is_inside_tree():
		return

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if not space_state:
		return

	# Determine attack direction based on player camera (FPS) or Visuals facing direction (TPS)
	var forward_dir: Vector3 = Vector3.FORWARD
	var origin_pos: Vector3 = Vector3.ZERO
	if player:
		if player.is_third_person:
			var attack_basis: Basis = player.visuals.global_basis if player.visuals else player.global_basis
			forward_dir = -attack_basis.z.normalized()
			origin_pos = player.global_position + Vector3(0.0, 0.9, 0.0)
		else:
			var attack_basis: Basis = player.camera.global_basis if player.camera else player.global_basis
			forward_dir = -attack_basis.z.normalized()
			origin_pos = (player.camera.global_position if player.camera else player.global_position) + Vector3(0.0, -0.2, 0.0)
	else:
		forward_dir = -global_basis.z.normalized()
		origin_pos = global_position + Vector3(0.0, 0.9, 0.0)

	_trigger_visual_cue(forward_dir)

	var attack_center: Vector3 = origin_pos + forward_dir * (attack_range * 0.5)

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _cached_shape
	query.transform = Transform3D(Basis.IDENTITY, attack_center)
	query.collision_mask = target_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	if player:
		query.exclude = [player.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	if hits.is_empty():
		return

	var damaged_targets: Array[Node] = []

	for hit in hits:
		var collider: Object = hit.get("collider")
		if not collider is Node:
			continue

		var target_node: Node = collider as Node
		if target_node == player or target_node == self or target_node.is_ancestor_of(self) or self.is_ancestor_of(target_node):
			continue

		if target_node in damaged_targets:
			continue

		if not target_node.has_method("take_damage"):
			continue

		# Wall line-of-sight check: ensure no wall on Layer 1 is blocking between player and target
		var target_pos: Vector3 = (target_node as Node3D).global_position + Vector3(0.0, 0.9, 0.0) if target_node is Node3D else origin_pos
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin_pos, target_pos, wall_collision_mask
		)
		ray_query.collide_with_areas = false
		ray_query.collide_with_bodies = true

		var exclude_list: Array[RID] = []
		if player:
			exclude_list.append(player.get_rid())
		if target_node is CollisionObject3D:
			exclude_list.append((target_node as CollisionObject3D).get_rid())
		ray_query.exclude = exclude_list

		var ray_result: Dictionary = space_state.intersect_ray(ray_query)
		if not ray_result.is_empty():
			# Blocked by wall
			continue

		# Directional block check
		var is_blocked: bool = false
		var final_damage: float = attack_damage

		var target_is_blocking: bool = false
		var target_block_reduction: float = 0.85
		var block_cone: float = 120.0

		var target_is_broken: bool = false
		if "is_shield_broken" in target_node:
			target_is_broken = target_node.get("is_shield_broken")
		elif target_node.has_method("is_shield_broken"):
			target_is_broken = target_node.call("is_shield_broken")

		if not target_is_broken:
			if "is_blocking" in target_node:
				target_is_blocking = target_node.get("is_blocking")
			elif target_node.has_method("is_blocking"):
				target_is_blocking = target_node.call("is_blocking")

			if "block_damage_reduction" in target_node:
				target_block_reduction = target_node.get("block_damage_reduction")
			if "block_cone_deg" in target_node:
				block_cone = target_node.get("block_cone_deg")

			if target_is_blocking and target_node is Node3D:
				var attacker_pos: Vector3 = player.global_position if player else global_position
				if is_attack_inside_block_cone(target_node as Node3D, attacker_pos, block_cone):
					is_blocked = true
					final_damage = attack_damage * (1.0 - target_block_reduction)

		var attacker_pos: Vector3 = player.global_position if player else global_position
		target_node.call("take_damage", final_damage, attacker_pos)
		var target_broke_shield_now: bool = false
		if is_blocked:
			var prev_target_dur: float = target_node.get("shield_durability") if "shield_durability" in target_node else 100.0
			if target_node.has_method("apply_shield_damage"):
				target_node.call("apply_shield_damage", normal_attack_shield_damage)
			elif "shield_durability" in target_node:
				target_node.set("shield_durability", maxf(0.0, target_node.get("shield_durability") - normal_attack_shield_damage))
			var new_target_dur: float = target_node.get("shield_durability") if "shield_durability" in target_node else 0.0
			if prev_target_dur > 0.0 and new_target_dur <= 0.0:
				target_broke_shield_now = true

		damaged_targets.append(target_node)
		hit_landed.emit(target_node, final_damage, is_blocked)

		# VFX placement: Calculate contact point on target surface
		var to_target: Vector3 = target_pos - origin_pos
		var dist: float = to_target.length()
		var hit_dir: Vector3 = forward_dir
		if dist > 0.001:
			hit_dir = to_target.normalized()
		var contact_pos: Vector3 = target_pos - hit_dir * minf(0.35, dist * 0.5)

		if is_blocked:
			_trigger_block_impact(contact_pos, hit_dir)
			spawn_damage_number(contact_pos, final_damage, true, normal_attack_shield_damage)
			if target_broke_shield_now and not (target_node is PlayerController):
				_trigger_shield_break(contact_pos, hit_dir)
				if player and player.has_method("apply_camera_recoil"):
					player.apply_camera_recoil(2)
				if combat_feedback:
					combat_feedback.trigger_shield_break_feedback(contact_pos)
			else:
				if player and player.has_method("apply_camera_recoil"):
					player.apply_camera_recoil(1)
				if combat_feedback:
					combat_feedback.trigger_block_feedback(contact_pos)
		else:
			_trigger_hit_impact(contact_pos, hit_dir)
			_trigger_hit_stop()
			spawn_damage_number(contact_pos, final_damage, false, 0.0)
			if player and player.has_method("apply_camera_recoil"):
				player.apply_camera_recoil(0)
			if combat_feedback:
				combat_feedback.trigger_hit_feedback(target_node, final_damage)

func get_valid_target_in_range() -> Node:
	var world_3d: World3D = get_world_3d()
	if not world_3d or not is_inside_tree():
		return null

	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if not space_state:
		return null

	var forward_dir: Vector3 = Vector3.FORWARD
	var origin_pos: Vector3 = Vector3.ZERO
	if player:
		if player.is_third_person:
			var attack_basis: Basis = player.visuals.global_basis if player.visuals else player.global_basis
			forward_dir = -attack_basis.z.normalized()
			origin_pos = player.global_position + Vector3(0.0, 0.9, 0.0)
		else:
			var attack_basis: Basis = player.camera.global_basis if player.camera else player.global_basis
			forward_dir = -attack_basis.z.normalized()
			origin_pos = (player.camera.global_position if player.camera else player.global_position) + Vector3(0.0, -0.2, 0.0)
	else:
		forward_dir = -global_basis.z.normalized()
		origin_pos = global_position + Vector3(0.0, 0.9, 0.0)

	var attack_center: Vector3 = origin_pos + forward_dir * (attack_range * 0.5)

	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _cached_shape
	query.transform = Transform3D(Basis.IDENTITY, attack_center)
	query.collision_mask = target_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	if player:
		query.exclude = [player.get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	if hits.is_empty():
		return null

	for hit in hits:
		var collider: Object = hit.get("collider")
		if not collider is Node:
			continue

		var target_node: Node = collider as Node
		if target_node == player or target_node == self or target_node.is_ancestor_of(self) or self.is_ancestor_of(target_node):
			continue

		if not target_node.has_method("take_damage"):
			continue

		# Line-of-sight wall check
		var target_pos: Vector3 = (target_node as Node3D).global_position + Vector3(0.0, 0.9, 0.0) if target_node is Node3D else origin_pos
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin_pos, target_pos, wall_collision_mask
		)
		ray_query.collide_with_areas = false
		ray_query.collide_with_bodies = true

		var exclude_list: Array[RID] = []
		if player:
			exclude_list.append(player.get_rid())
		if target_node is CollisionObject3D:
			exclude_list.append((target_node as CollisionObject3D).get_rid())
		ray_query.exclude = exclude_list

		var ray_result: Dictionary = space_state.intersect_ray(ray_query)
		if ray_result.is_empty():
			return target_node

	return null


func is_attack_inside_block_cone(defender: Node3D, attacker_pos: Vector3, block_cone_deg: float = 120.0) -> bool:
	var defender_fwd: Vector3 = Vector3.FORWARD

	if defender is PlayerController:
		var p: PlayerController = defender as PlayerController
		if p.is_third_person and p.visuals:
			defender_fwd = -p.visuals.global_basis.z
		elif p.camera:
			defender_fwd = -p.camera.global_basis.z
		else:
			defender_fwd = -p.global_basis.z
	elif defender.has_node("Visuals"):
		defender_fwd = -defender.get_node("Visuals").global_basis.z
	else:
		defender_fwd = -defender.global_basis.z

	defender_fwd.y = 0.0
	defender_fwd = defender_fwd.normalized()

	var to_attacker: Vector3 = attacker_pos - defender.global_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() < 0.0001:
		return true
	to_attacker = to_attacker.normalized()

	var dot: float = defender_fwd.dot(to_attacker)
	var min_dot: float = cos(deg_to_rad(block_cone_deg * 0.5)) # cos(60°) = 0.50

	return dot >= min_dot


func _trigger_visual_cue(attack_direction: Vector3 = Vector3.FORWARD) -> void:
	var direction: Vector3 = attack_direction
	direction.y = 0.0

	if direction.length_squared() < 0.0001:
		if player:
			var basis: Basis = player.visuals.global_basis if (player.is_third_person and player.visuals) else player.global_basis
			direction = -basis.z
			direction.y = 0.0
		else:
			direction = Vector3.FORWARD

	direction = direction.normalized()

	var player_pos: Vector3 = player.global_position if player else global_position

	# 1. Trigger stylized SlashArcVFX
	if slash_arc_vfx and slash_arc_vfx.has_method("trigger"):
		slash_arc_vfx.trigger(direction, player_pos)
	elif slash_arc_vfx:
		slash_arc_vfx.global_position = player_pos + direction * 1.1
		slash_arc_vfx.global_position.y = player_pos.y + 0.9
		slash_arc_vfx.global_basis = Basis.looking_at(direction, Vector3.UP)
		slash_arc_vfx.visible = true

	# 2. Legacy yellow BoxMesh: disabled by default once SlashArcVFX is active
	if use_legacy_slash_cue and visual_slash_cue:
		visual_slash_cue.global_position = player_pos + direction * 1.1
		visual_slash_cue.global_position.y = player_pos.y + 0.9
		visual_slash_cue.global_basis = Basis.looking_at(direction, Vector3.UP)
		visual_slash_cue.visible = true
		visual_slash_cue.scale = Vector3(0.5, 0.5, 0.5)

		if _slash_tween and _slash_tween.is_valid():
			_slash_tween.kill()

		_slash_tween = create_tween()
		_slash_tween.tween_property(visual_slash_cue, "scale", Vector3(1.2, 1.2, 1.2), 0.12)
		_slash_tween.tween_callback(func() -> void: if visual_slash_cue: visual_slash_cue.visible = false)
	elif visual_slash_cue:
		visual_slash_cue.visible = false


func _trigger_hit_impact(impact_pos: Vector3, impact_dir: Vector3) -> void:
	if hit_impact_vfx and hit_impact_vfx.has_method("trigger"):
		hit_impact_vfx.trigger(impact_pos, impact_dir)
	elif hit_impact_vfx:
		hit_impact_vfx.global_position = impact_pos
		hit_impact_vfx.visible = true


func trigger_hit_impact(impact_pos: Vector3, impact_dir: Vector3) -> void:
	_trigger_hit_impact(impact_pos, impact_dir)


func trigger_block_impact(block_pos: Vector3, incoming_dir: Vector3) -> void:
	_trigger_block_impact(block_pos, incoming_dir)


func _trigger_block_impact(block_pos: Vector3, incoming_dir: Vector3) -> void:
	if block_impact_vfx and block_impact_vfx.has_method("trigger"):
		block_impact_vfx.trigger(block_pos, incoming_dir)
	elif block_impact_vfx:
		block_impact_vfx.global_position = block_pos
		block_impact_vfx.visible = true


func trigger_shield_break(break_pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	_trigger_shield_break(break_pos, normal)


func _trigger_shield_break(break_pos: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if shield_break_vfx and shield_break_vfx.has_method("trigger"):
		shield_break_vfx.trigger(break_pos, normal)
	elif shield_break_vfx:
		shield_break_vfx.global_position = break_pos
		shield_break_vfx.visible = true


func stop_slash_effect() -> void:
	if slash_arc_vfx and slash_arc_vfx.has_method("stop"):
		slash_arc_vfx.stop()
	elif slash_arc_vfx:
		slash_arc_vfx.visible = false
	if visual_slash_cue:
		visual_slash_cue.visible = false
	if hit_impact_vfx and hit_impact_vfx.has_method("stop"):
		hit_impact_vfx.stop()
	elif hit_impact_vfx:
		hit_impact_vfx.visible = false
	if block_impact_vfx and block_impact_vfx.has_method("stop"):
		block_impact_vfx.stop()
	elif block_impact_vfx:
		block_impact_vfx.visible = false
	if shield_break_vfx and shield_break_vfx.has_method("stop"):
		shield_break_vfx.stop()
	elif shield_break_vfx:
		shield_break_vfx.visible = false
	if damage_number_pool and damage_number_pool.has_method("stop_all"):
		damage_number_pool.stop_all()
	if attack_telegraph_vfx and attack_telegraph_vfx.has_method("stop"):
		attack_telegraph_vfx.stop()
	elif attack_telegraph_vfx:
		attack_telegraph_vfx.visible = false


func spawn_damage_number(impact_pos: Vector3, hp_amount: float, is_blocked: bool, shield_amount: float = 0.0) -> DamageNumberVFX:
	if damage_number_pool and damage_number_pool.has_method("spawn"):
		return damage_number_pool.spawn(impact_pos, hp_amount, is_blocked, shield_amount)
	return null


func _trigger_hit_stop() -> void:
	# Per Section 6: Global pause breaks timers/shield recovery/VFX, while slowing
	# AnimationPlayer speed_scale breaks strict attack timing (0.35s impact constraint).
	# Safely skipped per design specification.
	if player and player.anim_player:
		player.anim_player.speed_scale = 1.0
