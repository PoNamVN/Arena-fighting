class_name PlayerController
extends CharacterBody3D

## Combat FSM
enum CombatState {
	IDLE,
	RUN,
	ATTACK,
	BLOCK,
	DEAD
}

signal state_changed(old_state: CombatState, new_state: CombatState)

## Configuration Parameters
@export_group("Movement")
@export var walk_speed: float = 6.0
@export var sprint_speed: float = 10.5
@export var acceleration: float = 12.0
@export var friction: float = 14.0
@export var rotation_speed: float = 14.0

@export_group("Jumping & Gravity")
@export var jump_velocity: float = 8.5
@export var gravity: float = 24.0

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -75.0
@export var max_pitch: float = 60.0
@export var third_person_distance: float = 3.5
@export var is_third_person: bool = true

@export_group("Combat")
@export var block_damage_reduction: float = 0.85
@export var block_cone_deg: float = 120.0
@export var shield_max_durability: float = 100.0
@export var normal_attack_shield_damage: float = 15.0
@export var shield_break_stun_duration: float = 1.0
@export var shield_recovery_delay: float = 2.0
var shield_durability: float = 100.0

## Task 5.7: Hit Reaction, Knockback & Combat Feel Tuning
@export var hit_reaction_duration: float = 0.15
@export var hit_knockback_distance: float = 0.40
@export var hit_knockback_duration: float = 0.10
@export var block_recoil_distance: float = 0.08

var _knockback_timer: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
var _hit_reaction_tween: Tween = null
var _hit_reaction_count: int = 0
var _cam_recoil_pitch: float = 0.0
var _cam_recoil_tween: Tween = null

enum ShieldRecoveryMode {
	TEST_ARENA,
	MATCH
}
@export var shield_recovery_mode: ShieldRecoveryMode = ShieldRecoveryMode.TEST_ARENA

enum ShieldState {
	READY,
	BROKEN
}
var shield_state: ShieldState = ShieldState.READY
var is_shield_broken: bool:
	get:
		return shield_state == ShieldState.BROKEN
var is_shield_stunned: bool:
	get:
		return _shield_stun_timer > 0.0

var shield_recovery_time_remaining: float:
	get:
		if shield_recovery_mode == ShieldRecoveryMode.MATCH:
			return 0.0
		return maxf(0.0, _shield_recovery_timer)

var _shield_stun_timer: float = 0.0
var _shield_recovery_timer: float = 0.0
var _shield_break_count: int = 0

## Task 5.8: Combat Feedback & Low-Shield Feedback
@export var low_shield_threshold: float = 25.0
var is_low_shield: bool = false

signal shield_durability_changed(current: float, maximum: float)
signal shield_broken()
signal shield_restored()
signal low_shield_warning_changed(is_active: bool)
signal hit_reacted(is_blocked: bool, hit_dir: Vector3)

## Node References
@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var combat: PlayerCombat = get_node_or_null("PlayerCombat") as PlayerCombat
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
@onready var combat_feedback: CombatFeedback = get_node_or_null("CombatFeedback") as CombatFeedback
var anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _head_bone_idx: int = -1
var _neck_bone_idx: int = -1

## FSM & Combat State
const ATTACK_IMPACT_TIMESTAMP: float = 0.35
const COMBO_WINDOW_START: float = 0.35
const COMBO_WINDOW_END: float = 0.70
const MAX_COMBO_STEP: int = 3
const COMBO_FINISHER_RECOVERY: float = 0.8
@export var combo_recovery_timeout: float = 0.25

signal combo_step_changed(current_step: int)

var combat_state: CombatState = CombatState.IDLE
var _camera_yaw: float = 0.0
var _prev_camera_yaw: float = 0.0
var _camera_pitch: float = 0.0
var _is_mouse_captured: bool = true
var _attack_impact_applied: bool = false
var _block_transition: String = ""

var combo_step: int:
	get:
		return _combo_step

var combo_buffer: int:
	get:
		return _combo_buffer

var _combo_step: int = 0
var _combo_buffer: int = 0
var _combo_queued: bool = false
var _combo_recovery_timer: float = 0.0
var _combo_finisher_recovery_timer: float = 0.0

var combo_finisher_recovery_remaining: float:
	get:
		return maxf(0.0, _combo_finisher_recovery_timer)

## Compatibility Properties (Mutually exclusive by design)
var is_attacking: bool:
	get:
		return combat_state == CombatState.ATTACK

var _is_attacking: bool:
	get:
		return combat_state == CombatState.ATTACK

var is_blocking: bool:
	get:
		return combat_state == CombatState.BLOCK and not is_shield_broken
	set(value):
		if combat_state == CombatState.DEAD or is_shield_broken:
			return
		if value:
			if combat_state != CombatState.ATTACK:
				transition_to(CombatState.BLOCK)
		else:
			if combat_state == CombatState.BLOCK:
				_release_block()

var is_dead: bool:
	get:
		return combat_state == CombatState.DEAD


func _ready() -> void:
	_setup_fallback_input_actions()
	_set_mouse_captured(true)
	if camera_pivot:
		_camera_yaw = camera_pivot.rotation.y
		_camera_pitch = camera_pivot.rotation.x
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
	_setup_animation_player()
	set_third_person(is_third_person)

	if health_component:
		if not health_component.died.is_connected(_on_health_died):
			health_component.died.connect(_on_health_died)


func _unhandled_input(event: InputEvent) -> void:
	# Once DEAD: lock all movement, attack, and block input
	if combat_state == CombatState.DEAD:
		# Still allow camera look and perspective toggle for viewing death
		if event is InputEventMouseMotion and _is_mouse_captured:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			_camera_yaw -= motion.relative.x * mouse_sensitivity
			_camera_pitch -= motion.relative.y * mouse_sensitivity
			_camera_pitch = clampf(_camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			if camera_pivot:
				camera_pivot.rotation.y = _camera_yaw
				camera_pivot.rotation.x = _camera_pitch + _cam_recoil_pitch
		elif event is InputEventKey and event.is_pressed() and not event.is_echo() and event.physical_keycode == KEY_V:
			toggle_camera_perspective()
		return

	# Toggle third-person / first-person with V key
	if event is InputEventKey and event.is_pressed() and not event.is_echo() and event.physical_keycode == KEY_V:
		toggle_camera_perspective()

	# Mouse look
	if event is InputEventMouseMotion and _is_mouse_captured:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_yaw -= motion.relative.x * mouse_sensitivity
		_camera_pitch -= motion.relative.y * mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

		if camera_pivot:
			camera_pivot.rotation.y = _camera_yaw
			camera_pivot.rotation.x = _camera_pitch + _cam_recoil_pitch

		if visuals:
			visuals.rotation.y = _camera_yaw

	# Mouse release / capture
	if event.is_action_pressed("ui_cancel"):
		_set_mouse_captured(false)
		return

	if not _is_mouse_captured:
		if event is InputEventMouseButton and event.is_pressed():
			_set_mouse_captured(true)
		return

	# Combat Input Actions (Single source of truth via InputMap)
	if event.is_action_pressed("attack"):
		_try_combat_attack()
	elif event.is_action_pressed("block"):
		if not is_shield_broken:
			_start_block()
	elif event.is_action_released("block"):
		_release_block()



func _physics_process(delta: float) -> void:
	# DEAD state locks character in place
	if combat_state == CombatState.DEAD:
		_knockback_timer = 0.0
		_knockback_vel = Vector3.ZERO
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
			move_and_slide()
		else:
			velocity.y = 0.0
		return

	# Shield break timers
	if shield_state == ShieldState.BROKEN:
		if _shield_stun_timer > 0.0:
			_shield_stun_timer -= delta
		if shield_recovery_mode == ShieldRecoveryMode.TEST_ARENA:
			if _shield_recovery_timer > 0.0:
				_shield_recovery_timer -= delta
				if _shield_recovery_timer <= 0.0:
					_restore_shield()

	# Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Jump (disabled while blocking, attacking, or stunned)
		if Input.is_action_just_pressed("jump") and combat_state != CombatState.BLOCK and combat_state != CombatState.ATTACK and _shield_stun_timer <= 0.0:
			velocity.y = jump_velocity
		elif velocity.y < 0.0:
			velocity.y = -0.1

	# Calculate Camera-Relative Input
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_z: float = Input.get_axis("move_forward", "move_backward")

	var move_dir: Vector3 = Vector3.ZERO
	if camera_pivot:
		var cam_yaw_basis: Basis = Basis(Vector3.UP, camera_pivot.rotation.y)
		move_dir = cam_yaw_basis * Vector3(input_x, 0.0, input_z)
		move_dir.y = 0.0
		if move_dir.length_squared() > 1.0:
			move_dir = move_dir.normalized()

	# Determine Target Speed
	var is_sprinting: bool = Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	if combat_state == CombatState.ATTACK or _combo_finisher_recovery_timer > 0.0:
		target_speed *= 0.5 # Phase 2: 50% attack movement speed
	elif combat_state == CombatState.BLOCK:
		target_speed *= 0.45 # Phase 3: 45% block movement speed
	var target_horizontal: Vector3 = move_dir * target_speed
	if _shield_stun_timer > 0.0:
		target_horizontal = Vector3.ZERO # Stop movement during shield break stun

	# Accelerate or Decelerate Horizontally / Apply Knockback
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(0.0, _knockback_timer - delta)
		velocity.x = _knockback_vel.x
		velocity.z = _knockback_vel.z
		if _knockback_timer <= 0.0:
			velocity.x = 0.0
			velocity.z = 0.0
	else:
		var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		var lerp_rate: float = acceleration if move_dir.length_squared() > 0.001 else friction
		var new_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, lerp_rate * delta)
		velocity.x = new_horizontal.x
		velocity.z = new_horizontal.z

	# Rotate Character Visuals (player horizontal yaw follows camera yaw in combat camera)
	if visuals:
		if not is_third_person:
			visuals.rotation.y = _camera_yaw
		else:
			if move_dir.length_squared() > 0.001 or combat_state == CombatState.BLOCK or not is_equal_approx(_camera_yaw, _prev_camera_yaw):
				visuals.rotation.y = _camera_yaw
				_prev_camera_yaw = _camera_yaw

	move_and_slide()

	# FSM Locomotion transitions (only when in IDLE or RUN and not in knockback)
	if (combat_state == CombatState.IDLE or combat_state == CombatState.RUN) and _knockback_timer <= 0.0:
		var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
		if horiz_sq > 0.05 or move_dir.length_squared() > 0.001:
			if combat_state != CombatState.RUN:
				transition_to(CombatState.RUN)
		else:
			if combat_state != CombatState.IDLE:
				transition_to(CombatState.IDLE)

	# Synchronize damage impact at the exact apex frame of the attack animation (t = 0.35s)
	if combat_state == CombatState.ATTACK and not _attack_impact_applied:
		if anim_player and anim_player.current_animation == "attack":
			if anim_player.current_animation_position >= ATTACK_IMPACT_TIMESTAMP:
				_attack_impact_applied = true
				if combat:
					combat.execute_impact()

	# Decay combo recovery timer when not attacking
	if combat_state != CombatState.ATTACK and _combo_recovery_timer > 0.0:
		_combo_recovery_timer = maxf(0.0, _combo_recovery_timer - delta)
		if _combo_recovery_timer <= 0.0:
			if _combo_step != 0:
				_combo_step = 0
				combo_step_changed.emit(0)

	# Task 5.14C: Finisher recovery blocks new attacks and blocks without a new FSM state.
	if _combo_finisher_recovery_timer > 0.0:
		_combo_finisher_recovery_timer = maxf(0.0, _combo_finisher_recovery_timer - delta)

	_update_locomotion_animations()


## FSM Transition Logic
func transition_to(new_state: CombatState) -> bool:
	if combat_state == CombatState.DEAD:
		# DEAD is terminal: ignore any transition attempt
		return false

	if new_state == CombatState.DEAD:
		_enter_dead_state()
		return true

	if combat_state == new_state:
		return true

	var old_state: CombatState = combat_state

	match new_state:
		CombatState.IDLE:
			if combat_state == CombatState.ATTACK:
				# Cannot exit attack prematurely
				return false
			combat_state = CombatState.IDLE
			_block_transition = ""
			if anim_player and anim_player.has_animation("idle"):
				anim_player.speed_scale = 1.0
				anim_player.play("idle", 0.18)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.RUN:
			if combat_state == CombatState.ATTACK:
				return false
			combat_state = CombatState.RUN
			_block_transition = ""
			if anim_player and anim_player.has_animation("run"):
				anim_player.play("run", 0.15)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.ATTACK:
			if combat_state == CombatState.ATTACK:
				return false
			_block_transition = ""
			if combat and not combat.start_attack():
				return false
			combat_state = CombatState.ATTACK
			if _combo_step == 0:
				_combo_step = 1
			_combo_buffer = 0
			_combo_queued = false
			_combo_recovery_timer = 0.0
			_attack_impact_applied = false
			_orient_attack_direction()
			var fwd: Vector3 = (-visuals.global_basis.z) if (visuals and is_third_person) else (-camera.global_basis.z if camera else -global_basis.z)
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
			if combat and combat.has_method("trigger_attack_telegraph"):
				combat.trigger_attack_telegraph(fwd, ATTACK_IMPACT_TIMESTAMP)
			if anim_player and anim_player.has_animation("attack"):
				anim_player.speed_scale = 1.0
				anim_player.stop()
				anim_player.play("attack", 0.05)
				anim_player.seek(0.0, true)
			combo_step_changed.emit(_combo_step)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.BLOCK:
			if is_shield_broken or combat_state == CombatState.ATTACK or combat_state == CombatState.DEAD or _combo_finisher_recovery_timer > 0.0:
				# Block rejected while shield broken, attacking, or dead
				return false
			reset_combo()
			combat_state = CombatState.BLOCK
			_block_transition = "start"
			if anim_player:
				if anim_player.has_animation("block_start"):
					anim_player.speed_scale = 1.4 # Snappy raise to guard (~0.15s)
					anim_player.play("block_start", 0.08)
				elif anim_player.has_animation("block_hold"):
					anim_player.play("block_hold", 0.08)
			state_changed.emit(old_state, combat_state)
			return true

	return false


func _enter_dead_state() -> void:
	var old_state: CombatState = combat_state
	combat_state = CombatState.DEAD
	reset_combo()
	_attack_impact_applied = true # Stop any pending impact
	_block_transition = ""

	# Stop movement and combat actions
	velocity = Vector3.ZERO
	if combat and combat.has_method("stop_slash_effect"):
		combat.stop_slash_effect()
	elif combat and combat.slash_effect:
		combat.slash_effect.visible = false

	# Play dead animation
	if anim_player and anim_player.has_animation("dead"):
		anim_player.speed_scale = 1.0
		anim_player.stop()
		var anim: Animation = anim_player.get_animation("dead")
		if anim:
			anim.loop_mode = Animation.LOOP_NONE
		anim_player.play("dead", 0.1)

	state_changed.emit(old_state, combat_state)


func can_block() -> bool:
	return not is_shield_broken and combat_state != CombatState.DEAD and combat_state != CombatState.ATTACK and _combo_finisher_recovery_timer <= 0.0


func is_in_combo_window() -> bool:
	if combat_state != CombatState.ATTACK:
		return false
	if not anim_player or not anim_player.is_playing() or anim_player.current_animation != "attack":
		return false
	var pos: float = anim_player.current_animation_position
	return pos >= COMBO_WINDOW_START and pos <= COMBO_WINDOW_END


func is_combo_queued() -> bool:
	return _combo_buffer > 0 or _combo_queued


func get_combo_buffer() -> int:
	return _combo_buffer


func get_combo_step() -> int:
	return _combo_step


func reset_combo(clear_finisher_recovery: bool = true) -> void:
	var prev_step: int = _combo_step
	_combo_step = 0
	_combo_buffer = 0
	_combo_queued = false
	_combo_recovery_timer = 0.0
	if clear_finisher_recovery:
		_combo_finisher_recovery_timer = 0.0
	if prev_step != 0:
		combo_step_changed.emit(0)


func _execute_next_combo_attack() -> void:
	if combat_state == CombatState.DEAD:
		reset_combo()
		return

	if combat:
		combat._cooldown_timer = 0.0
		combat.start_attack()

	_attack_impact_applied = false
	_orient_attack_direction()

	var fwd: Vector3 = (-visuals.global_basis.z) if (visuals and is_third_person) else (-camera.global_basis.z if camera else -global_basis.z)
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
	if combat and combat.has_method("trigger_attack_telegraph"):
		combat.trigger_attack_telegraph(fwd, ATTACK_IMPACT_TIMESTAMP)

	if anim_player and anim_player.has_animation("attack"):
		anim_player.speed_scale = 1.0
		anim_player.stop()
		anim_player.play("attack", 0.05)
		anim_player.seek(0.0, true)

	combo_step_changed.emit(_combo_step)


func _try_combat_attack() -> bool:
	if combat_state == CombatState.DEAD:
		return false
	if _combo_finisher_recovery_timer > 0.0:
		return false
	if is_shield_broken or _shield_stun_timer > 0.0:
		return false

	if combat_state == CombatState.ATTACK:
		if _combo_step + _combo_buffer < MAX_COMBO_STEP:
			_combo_buffer += 1
			_combo_queued = true
			return true
		return false

	if combat_state == CombatState.IDLE or combat_state == CombatState.RUN:
		var success: bool = transition_to(CombatState.ATTACK)
		if success:
			_combo_step = 1
			_combo_buffer = 0
			_combo_queued = false
			_combo_recovery_timer = 0.0
		return success

	return false


func _start_block() -> bool:
	if is_shield_broken or combat_state == CombatState.DEAD or _combo_finisher_recovery_timer > 0.0:
		return false
	return transition_to(CombatState.BLOCK)


func _release_block() -> void:
	if combat_state != CombatState.BLOCK:
		return

	var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_z: float = Input.get_axis("move_forward", "move_backward")
	var is_moving: bool = (abs(input_x) > 0.1 or abs(input_z) > 0.1) or (horiz_sq > 0.05 and _knockback_timer <= 0.0)

	var old_state: CombatState = combat_state
	combat_state = CombatState.RUN if is_moving else CombatState.IDLE
	_block_transition = "releasing"

	if anim_player and anim_player.has_animation("block_release"):
		anim_player.speed_scale = 1.4 # Snappy return to stance
		anim_player.play("block_release", 0.08)
	else:
		_block_transition = ""
		_update_locomotion_animations()

	state_changed.emit(old_state, combat_state)


func _orient_attack_direction() -> void:
	if visuals:
		visuals.rotation.y = _camera_yaw


const NO_ATTACKER_POS: Vector3 = Vector3(99999.0, 99999.0, 99999.0)


func take_damage(amount: float, attacker_pos: Vector3 = NO_ATTACKER_POS, incoming_shield_damage: float = 15.0, spawn_feedback: bool = true) -> void:
	if combat_state == CombatState.DEAD:
		# TEST 16: No damage can be processed after DEAD
		return

	var final_damage: float = amount
	var was_blocked: bool = false
	if combat_state == CombatState.BLOCK and not is_shield_broken and attacker_pos != NO_ATTACKER_POS:
		if combat and combat.is_attack_inside_block_cone(self, attacker_pos, block_cone_deg):
			was_blocked = true
			final_damage = amount * (1.0 - block_damage_reduction)
			if combat:
				var to_attacker: Vector3 = attacker_pos - global_position
				to_attacker.y = 0.0
				var to_attacker_dir: Vector3 = to_attacker.normalized() if to_attacker.length_squared() > 0.0001 else Vector3.FORWARD
				var incoming_dir: Vector3 = -to_attacker_dir
				var block_pos: Vector3 = global_position + Vector3(0.0, 0.9, 0.0) + to_attacker_dir * 0.4
				if combat.has_method("trigger_block_impact"):
					combat.trigger_block_impact(block_pos, incoming_dir)
				if spawn_feedback and combat.has_method("spawn_damage_number"):
					combat.spawn_damage_number(block_pos, final_damage, true, incoming_shield_damage)
			apply_shield_damage(incoming_shield_damage)
	else:
		# Unblocked hit visual feedback on player's body
		if combat and attacker_pos != NO_ATTACKER_POS:
			var to_attacker: Vector3 = attacker_pos - global_position
			to_attacker.y = 0.0
			var to_attacker_dir: Vector3 = to_attacker.normalized() if to_attacker.length_squared() > 0.0001 else Vector3.FORWARD
			var hit_pos: Vector3 = global_position + Vector3(0.0, 0.9, 0.0) + to_attacker_dir * 0.35
			if combat.has_method("trigger_hit_impact"):
				combat.trigger_hit_impact(hit_pos, -to_attacker_dir)
			if spawn_feedback and combat.has_method("spawn_damage_number"):
				combat.spawn_damage_number(hit_pos, final_damage, false, 0.0)

	var will_die: bool = (health_component and health_component.current_health - final_damage <= 0.0)

	# Apply hit reaction and knockback only if target survives
	if not will_die and attacker_pos != NO_ATTACKER_POS:
		var to_me: Vector3 = global_position - attacker_pos
		to_me.y = 0.0
		var hit_dir: Vector3 = to_me.normalized() if to_me.length_squared() > 0.0001 else (-visuals.global_basis.z if visuals else Vector3.BACK)
		apply_hit_reaction(hit_dir, was_blocked)

	if health_component:
		health_component.take_damage(final_damage)
	elif final_damage > 0.0:
		transition_to(CombatState.DEAD)


func apply_knockback(direction: Vector3, distance: float, duration: float) -> void:
	if combat_state == CombatState.DEAD:
		return
	var flat_dir: Vector3 = direction
	flat_dir.y = 0.0
	if flat_dir.length_squared() < 0.0001:
		flat_dir = -visuals.global_basis.z if visuals else Vector3.BACK
	flat_dir = flat_dir.normalized()

	var safe_dur: float = maxf(0.01, duration)
	_knockback_timer = safe_dur
	_knockback_vel = flat_dir * (distance / safe_dur)


func apply_hit_reaction(hit_dir: Vector3, is_blocked_hit: bool = false) -> void:
	if combat_state == CombatState.DEAD:
		return
	_hit_reaction_count += 1
	# Hit reaction clears queued combo input but cannot bypass finisher recovery.
	reset_combo(false)

	var kb_dist: float = block_recoil_distance if is_blocked_hit else hit_knockback_distance
	var kb_dur: float = 0.08 if is_blocked_hit else hit_knockback_duration
	apply_knockback(hit_dir, kb_dist, kb_dur)

	# Procedural visual flinch
	if visuals:
		if _hit_reaction_tween and _hit_reaction_tween.is_valid():
			_hit_reaction_tween.kill()
		_hit_reaction_tween = create_tween()
		var tilt_mag: float = deg_to_rad(3.5) if is_blocked_hit else deg_to_rad(10.0)
		var orig_rx: float = 0.0
		_hit_reaction_tween.tween_property(visuals, "rotation:x", orig_rx - tilt_mag, 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hit_reaction_tween.tween_property(visuals, "rotation:x", orig_rx, hit_reaction_duration - 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	apply_camera_recoil(1 if is_blocked_hit else 0)

	hit_reacted.emit(is_blocked_hit, hit_dir)


func _apply_camera_hit_kick(is_blocked_hit: bool) -> void:
	apply_camera_recoil(1 if is_blocked_hit else 0)


func apply_camera_recoil(type: int) -> void:
	if not camera_pivot:
		return
	var kick: float = 0.0
	var duration: float = 0.12
	match type:
		0: # NORMAL_HIT
			kick = deg_to_rad(1.5)
			duration = 0.12
		1: # BLOCK
			kick = deg_to_rad(0.7)
			duration = 0.10
		2: # SHIELD_BREAK
			kick = deg_to_rad(3.5)
			duration = 0.18
		_:
			kick = deg_to_rad(1.5)
			duration = 0.12

	if _cam_recoil_tween and _cam_recoil_tween.is_valid():
		_cam_recoil_tween.kill()

	_cam_recoil_pitch = kick
	_update_camera_rotation()

	_cam_recoil_tween = create_tween()
	_cam_recoil_tween.tween_method(func(val: float) -> void:
		_cam_recoil_pitch = val
		_update_camera_rotation()
	, kick, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cam_recoil_tween.tween_callback(func() -> void:
		_cam_recoil_pitch = 0.0
		_update_camera_rotation()
	)


func get_camera_recoil_pitch() -> float:
	return _cam_recoil_pitch


func _update_camera_rotation() -> void:
	if camera_pivot:
		camera_pivot.rotation.y = _camera_yaw
		camera_pivot.rotation.x = _camera_pitch + _cam_recoil_pitch


func apply_shield_damage(amount: float) -> void:
	if shield_state == ShieldState.BROKEN:
		return
	var prev_durability: float = shield_durability
	shield_durability = maxf(0.0, shield_durability - amount)
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	if prev_durability > 0.0 and shield_durability <= 0.0:
		break_shield()
	else:
		_update_low_shield_state()


func _update_low_shield_state() -> void:
	var should_warn: bool = (shield_state == ShieldState.READY and shield_durability > 0.0 and shield_durability <= low_shield_threshold)
	if should_warn != is_low_shield:
		is_low_shield = should_warn
		low_shield_warning_changed.emit(is_low_shield)


func break_shield() -> void:
	if shield_state == ShieldState.BROKEN or combat_state == CombatState.DEAD:
		return
	# Shield break must not be usable to skip a pending combo-finisher recovery.
	reset_combo(false)
	shield_state = ShieldState.BROKEN
	_shield_break_count += 1
	_shield_stun_timer = shield_break_stun_duration
	if shield_recovery_mode == ShieldRecoveryMode.TEST_ARENA:
		_shield_recovery_timer = shield_recovery_delay
	else:
		_shield_recovery_timer = 0.0
	shield_durability = 0.0
	shield_durability_changed.emit(0.0, shield_max_durability)
	_update_low_shield_state()

	# If currently blocking, immediately exit block state
	if combat_state == CombatState.BLOCK:
		var old_state: CombatState = combat_state
		combat_state = CombatState.IDLE
		_block_transition = ""
		state_changed.emit(old_state, combat_state)
		_update_locomotion_animations()

	# Stop horizontal movement for stagger
	velocity.x = 0.0
	velocity.z = 0.0

	# Task 5.7: Stronger shield break recoil & visual stagger
	var break_kb_dir: Vector3 = (-visuals.global_basis.z) if (visuals and is_third_person) else (-camera.global_basis.z if camera else -global_basis.z)
	break_kb_dir.y = 0.0
	var stagger_dir: Vector3 = -break_kb_dir.normalized() if break_kb_dir.length_squared() > 0.0001 else Vector3.BACK
	apply_knockback(stagger_dir, 0.35, 0.12)

	if visuals:
		if _hit_reaction_tween and _hit_reaction_tween.is_valid():
			_hit_reaction_tween.kill()
		_hit_reaction_tween = create_tween()
		_hit_reaction_tween.tween_property(visuals, "rotation:x", -deg_to_rad(14.0), 0.08)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hit_reaction_tween.tween_property(visuals, "rotation:x", 0.0, 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	apply_camera_recoil(2)

	# Trigger ShieldBreakVFX
	if combat and combat.has_method("trigger_shield_break"):
		var fwd: Vector3 = (-visuals.global_basis.z) if (visuals and is_third_person) else (-camera.global_basis.z if camera else -global_basis.z)
		fwd.y = 0.0
		if fwd.length_squared() > 0.0001:
			fwd = fwd.normalized()
		else:
			fwd = Vector3.FORWARD
		var break_pos: Vector3 = global_position + Vector3(0.0, 0.9, 0.0) + fwd * 0.45
		combat.trigger_shield_break(break_pos, -fwd)
		if combat_feedback:
			combat_feedback.trigger_shield_break_feedback(break_pos)

	shield_broken.emit()


func _restore_shield() -> void:
	if shield_state != ShieldState.BROKEN:
		return
	shield_state = ShieldState.READY
	_shield_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	_update_low_shield_state()
	shield_restored.emit()


func reset_shield_for_new_round() -> void:
	var was_broken: bool = (shield_state == ShieldState.BROKEN)
	shield_state = ShieldState.READY
	_shield_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	_knockback_timer = 0.0
	_knockback_vel = Vector3.ZERO
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	_update_low_shield_state()
	if was_broken:
		shield_restored.emit()


func reset_shield_durability() -> void:
	reset_shield_for_new_round()


func respawn(spawn_pos: Vector3 = Vector3.ZERO, spawn_yaw: float = 0.0) -> void:
	if combat_state != CombatState.DEAD and not is_dead:
		return

	# 1. Reset Health
	if health_component:
		health_component.reset_health()

	# 2. Reset Shield for new life/round
	reset_shield_for_new_round()

	# 3. Clear timers and internal states
	_shield_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	_attack_impact_applied = false
	_block_transition = ""
	_knockback_timer = 0.0
	_knockback_vel = Vector3.ZERO
	_cam_recoil_pitch = 0.0
	if _cam_recoil_tween and _cam_recoil_tween.is_valid():
		_cam_recoil_tween.kill()
	if _hit_reaction_tween and _hit_reaction_tween.is_valid():
		_hit_reaction_tween.kill()

	# 4. Stop active VFX
	if combat:
		combat.stop_slash_effect()
		combat._cooldown_timer = 0.0

	# 5. Position, yaw, and velocity
	velocity = Vector3.ZERO
	if visuals:
		visuals.rotation.x = 0.0
	global_position = spawn_pos
	_camera_yaw = spawn_yaw
	_camera_pitch = 0.0
	if camera_pivot:
		camera_pivot.rotation.y = _camera_yaw
		camera_pivot.rotation.x = _camera_pitch
	if visuals:
		visuals.rotation.y = _camera_yaw

	# 6. Reset combat state to IDLE & restore locomotion animation
	reset_combo()
	var old_state: CombatState = combat_state
	combat_state = CombatState.IDLE
	if anim_player and anim_player.has_animation("idle"):
		anim_player.speed_scale = 1.0
		anim_player.stop()
		anim_player.play("idle", 0.1)

	state_changed.emit(old_state, combat_state)


func _on_health_died() -> void:
	if combat_feedback:
		combat_feedback.play_audio_event("death")
	transition_to(CombatState.DEAD)


func _on_animation_finished(anim_name: StringName) -> void:
	if combat_state == CombatState.DEAD:
		# TEST 15: Character remains DEAD and at death location after dead animation completes
		return

	if anim_name == "attack":
		_attack_impact_applied = false
		if combat and combat.has_method("stop_slash_effect"):
			combat.stop_slash_effect()

		if (_combo_buffer > 0 or _combo_queued) and _combo_step < MAX_COMBO_STEP:
			_combo_step += 1
			if _combo_buffer > 0:
				_combo_buffer -= 1
			_combo_queued = (_combo_buffer > 0)
			_execute_next_combo_attack()
			return

		_combo_buffer = 0
		_combo_queued = false
		_combo_recovery_timer = combo_recovery_timeout
		if _combo_step == MAX_COMBO_STEP:
			_combo_finisher_recovery_timer = COMBO_FINISHER_RECOVERY

		var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
		var input_x: float = Input.get_axis("move_left", "move_right")
		var input_z: float = Input.get_axis("move_forward", "move_backward")
		var has_move_input: bool = (abs(input_x) > 0.1 or abs(input_z) > 0.1) or (horiz_sq > 0.05 and _knockback_timer <= 0.0)

		var next_state: CombatState = CombatState.RUN if has_move_input else CombatState.IDLE
		combat_state = next_state
		state_changed.emit(CombatState.ATTACK, next_state)
		_update_locomotion_animations()

	elif anim_name == "block_start":
		if combat_state == CombatState.BLOCK and anim_player and anim_player.has_animation("block_hold"):
			_block_transition = "holding"
			anim_player.speed_scale = 1.0
			anim_player.play("block_hold", 0.05)

	elif anim_name == "block_release":
		_block_transition = ""
		_update_locomotion_animations()


func _update_locomotion_animations() -> void:
	if not anim_player or combat_state == CombatState.DEAD or combat_state == CombatState.ATTACK or combat_state == CombatState.BLOCK:
		return

	if _block_transition == "releasing":
		if anim_player.is_playing() and anim_player.current_animation == "block_release":
			return
		_block_transition = ""
	elif _block_transition == "start" or _block_transition == "holding":
		_block_transition = ""

	var horizontal_speed_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	if combat_state == CombatState.RUN or horizontal_speed_sq > 0.05:
		if anim_player.current_animation != "run":
			anim_player.play("run", 0.15)
		var current_speed: float = sqrt(horizontal_speed_sq)
		anim_player.speed_scale = clampf(current_speed / 2.6, 0.9, 4.2)
	else:
		if anim_player.current_animation != "idle":
			anim_player.speed_scale = 1.0
			anim_player.play("idle", 0.18)


func _setup_animation_player() -> void:
	if visuals:
		var model: Node = visuals.get_node_or_null("CharacterModel")
		if model:
			anim_player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if not anim_player:
				for child in model.get_children():
					if child is AnimationPlayer:
						anim_player = child
						break
			_skeleton = model.get_node_or_null("Gladiator_Armature/Skeleton3D") as Skeleton3D
			if not _skeleton:
				for child in model.find_children("*", "Skeleton3D", true, false):
					if child is Skeleton3D:
						_skeleton = child
						break
			if _skeleton:
				_head_bone_idx = _skeleton.find_bone("head")
				_neck_bone_idx = _skeleton.find_bone("neck")

	if anim_player:
		# Configure loop modes for locomotion and combat
		if anim_player.has_animation("idle"):
			anim_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		if anim_player.has_animation("run"):
			anim_player.get_animation("run").loop_mode = Animation.LOOP_LINEAR
		if anim_player.has_animation("attack"):
			anim_player.get_animation("attack").loop_mode = Animation.LOOP_NONE
		if anim_player.has_animation("block_start"):
			anim_player.get_animation("block_start").loop_mode = Animation.LOOP_NONE
		if anim_player.has_animation("block_hold"):
			anim_player.get_animation("block_hold").loop_mode = Animation.LOOP_LINEAR
		if anim_player.has_animation("block_release"):
			anim_player.get_animation("block_release").loop_mode = Animation.LOOP_NONE
		if anim_player.has_animation("block"):
			anim_player.get_animation("block").loop_mode = Animation.LOOP_NONE
		if anim_player.has_animation("dead"):
			anim_player.get_animation("dead").loop_mode = Animation.LOOP_NONE

		anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play("idle")


func toggle_camera_perspective() -> void:
	set_third_person(not is_third_person)


func set_third_person(enabled: bool) -> void:
	is_third_person = enabled
	if camera_pivot:
		camera_pivot.position = Vector3(0, 1.62, 0)
	if spring_arm:
		spring_arm.spring_length = third_person_distance if is_third_person else 0.0
		spring_arm.rotation.x = deg_to_rad(-12.0) if is_third_person else 0.0
	if camera:
		camera.position = Vector3(0, 0, third_person_distance) if is_third_person else Vector3.ZERO
		camera.near = 0.05 if is_third_person else 0.08
		camera.h_offset = 0.0
		camera.v_offset = 0.0
	_update_head_visibility()


func _update_head_visibility() -> void:
	if not _skeleton:
		return
	if is_third_person:
		if _head_bone_idx != -1:
			_skeleton.set_bone_pose_scale(_head_bone_idx, Vector3.ONE)
		if _neck_bone_idx != -1:
			_skeleton.set_bone_pose_scale(_neck_bone_idx, Vector3.ONE)
	else:
		if _head_bone_idx != -1:
			_skeleton.set_bone_pose_scale(_head_bone_idx, Vector3(0.0001, 0.0001, 0.0001))
		if _neck_bone_idx != -1:
			_skeleton.set_bone_pose_scale(_neck_bone_idx, Vector3(0.0001, 0.0001, 0.0001))


func _set_mouse_captured(captured: bool) -> void:
	_is_mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if combat_state == CombatState.BLOCK:
			_release_block()


func _setup_fallback_input_actions() -> void:
	_add_key_if_missing("move_forward", [KEY_W, KEY_UP])
	_add_key_if_missing("move_backward", [KEY_S, KEY_DOWN])
	_add_key_if_missing("move_left", [KEY_A, KEY_LEFT])
	_add_key_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_add_key_if_missing("jump", [KEY_SPACE])
	_add_key_if_missing("sprint", [KEY_SHIFT])
	_add_mouse_button_if_missing("attack", MOUSE_BUTTON_LEFT)
	_add_mouse_button_if_missing("block", MOUSE_BUTTON_RIGHT)


func _add_key_if_missing(action: StringName, keycodes: Array[Key]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for keycode in keycodes:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


func _add_mouse_button_if_missing(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = button_index
		InputMap.action_add_event(action, event)
