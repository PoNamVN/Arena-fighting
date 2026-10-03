class_name PracticeOpponent
extends Node

enum Difficulty { EASY, NORMAL, HARD }
const SKILL_WARNING_DURATION: float = 0.55
var difficulty: Difficulty = Difficulty.NORMAL
var actor: PlayerController
var target: PlayerController
var enabled: bool = false
var attack_timer: float = 0.8
var reaction_timer: float = 0.0
var block_timer: float = 0.0
var attacks_started: int = 0
var dodges_started: int = 0
var skills_started: int = 0
var combo_limit: int = 2
var reaction_delay: float = 0.22
var attack_interval: float = 1.25
var skill_interval: float = 12.0
var skill_timer: float = 4.0
var skill_warning_remaining: float = 0.0
var warning_ring: MeshInstance3D
var _threat_active: bool = false
var _defense_committed: bool = false
var _threat_count: int = 0


func _ready() -> void:
	configure(difficulty)
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "AISkillWarning"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.85
	torus.outer_radius = 3.0
	torus.rings = 48
	torus.ring_segments = 4
	warning_ring.mesh = torus
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.3, 0.05)
	warning_ring.material_override = material
	warning_ring.position.y = 0.08
	warning_ring.scale.y = 0.25
	actor.add_child(warning_ring)
	warning_ring.visible = false


func configure(level: int) -> void:
	difficulty = clampi(level, Difficulty.EASY, Difficulty.HARD) as Difficulty
	combo_limit = [1, 2, 3][difficulty]
	reaction_delay = [0.32, 0.22, 0.16][difficulty]
	attack_interval = [1.7, 1.25, 1.05][difficulty]
	skill_interval = [0.0, 12.0, 8.0][difficulty]
	if actor:
		actor.walk_speed = [3.6, 4.4, 5.0][difficulty]


func difficulty_name() -> String:
	return ["Dễ", "Thường", "Khó"][difficulty]


func _physics_process(delta: float) -> void:
	if not actor or not target:
		return
	actor.external_move_direction = Vector3.ZERO
	if not enabled or actor.is_dead or target.is_dead or not actor.controls_enabled:
		_cancel_warning()
		return
	if actor.frost and actor.frost.active():
		_cancel_warning()
		return
	if actor.polymorph and actor.polymorph.active():
		_cancel_warning()
		actor.external_move_direction = (actor.global_position - target.global_position).normalized()
		return
	if not target.is_targetable():
		_cancel_warning()
		actor._release_block()
		_threat_active = false
		_defense_committed = false
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	block_timer = maxf(0.0, block_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	var offset: Vector3 = target.global_position - actor.global_position
	offset.y = 0.0
	var distance: float = offset.length()
	var direction: Vector3 = offset.normalized()
	if skill_warning_remaining > 0.0:
		if actor.is_shield_broken or actor.is_shield_stunned:
			_cancel_warning()
			skill_timer = 2.0
			return
		skill_warning_remaining = maxf(0.0, skill_warning_remaining - delta)
		if skill_warning_remaining <= 0.0:
			_cancel_warning()
			if actor._try_cast_ability("skill_3"):
				skills_started += 1
				skill_timer = skill_interval
				attack_timer = 1.4
		return
	if actor.active_ability_action and actor.active_ability_action.is_active():
		return
	if actor.combat_state == PlayerController.CombatState.DODGE or actor.is_countering:
		return
	# Commit facing during each swing; advancing a combo uses the real input window.
	if actor.is_attacking:
		if distance <= 2.2 and actor.combo_step < combo_limit and actor.is_in_combo_window() and actor.anim_player.current_animation_position >= 0.50:
			if actor._try_combat_attack():
				attack_timer = attack_interval
		return
	actor._camera_yaw = atan2(-direction.x, -direction.z)
	actor.camera_pivot.rotation.y = actor._camera_yaw
	actor.visuals.rotation.y = actor._camera_yaw
	_update_defense(delta, distance, direction)
	if actor.combat_state == PlayerController.CombatState.DODGE:
		return
	if actor.is_blocking:
		if block_timer > 0.0:
			return
		actor._release_block()
	if difficulty != Difficulty.EASY and skill_timer <= 0.0 and distance <= 2.7 and actor.ability_system.can_cast("skill_3") and not actor.is_shield_broken and not actor.is_shield_stunned and actor.combo_finisher_recovery_remaining <= 0.0:
		skill_warning_remaining = SKILL_WARNING_DURATION
		warning_ring.visible = true
		return
	if distance > 1.65:
		actor.external_move_direction = direction
	elif attack_timer <= 0.0:
		if actor._try_combat_attack():
			attacks_started += 1
			attack_timer = attack_interval


func _update_defense(delta: float, distance: float, direction: Vector3) -> void:
	var threat: bool = target.is_attacking and distance < 3.0
	if not threat:
		_threat_active = false
		_defense_committed = false
		reaction_timer = 0.0
		return
	if not _threat_active:
		_threat_active = true
		_threat_count += 1
		reaction_timer = 0.0
		_defense_committed = false
	reaction_timer += delta
	if _defense_committed or reaction_timer < reaction_delay:
		return
	_defense_committed = true
	# Deliberately leave openings, and use only visible melee windup plus distance.
	if (difficulty == Difficulty.EASY and _threat_count % 3 != 1) or (difficulty == Difficulty.NORMAL and _threat_count % 3 == 0):
		return
	var use_dodge: bool = difficulty != Difficulty.EASY and _threat_count % 2 == 0
	if use_dodge:
		actor.external_move_direction = -direction
		if actor._try_dodge():
			dodges_started += 1
			attack_timer = maxf(attack_timer, 0.65)
			return
		actor.external_move_direction = Vector3.ZERO
	if actor.can_block() and actor._start_block():
		block_timer = 0.55


func _cancel_warning() -> void:
	skill_warning_remaining = 0.0
	if is_instance_valid(warning_ring):
		warning_ring.visible = false
