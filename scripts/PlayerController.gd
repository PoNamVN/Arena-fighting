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
		return maxf(0.0, _shield_recovery_timer)

var _shield_stun_timer: float = 0.0
var _shield_recovery_timer: float = 0.0
var _shield_break_count: int = 0

signal shield_durability_changed(current: float, maximum: float)
signal shield_broken()
signal shield_restored()

## Node References
@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var combat: PlayerCombat = get_node_or_null("PlayerCombat") as PlayerCombat
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent") as HealthComponent
var anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _head_bone_idx: int = -1
var _neck_bone_idx: int = -1

## FSM & Combat State
const ATTACK_IMPACT_TIMESTAMP: float = 0.35
var combat_state: CombatState = CombatState.IDLE
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0
var _is_mouse_captured: bool = true
var _attack_impact_applied: bool = false
var _block_transition: String = ""

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
				camera_pivot.rotation.x = _camera_pitch
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
			camera_pivot.rotation.x = _camera_pitch

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
	if combat_state == CombatState.ATTACK:
		target_speed *= 0.5 # Phase 2: 50% attack movement speed
	elif combat_state == CombatState.BLOCK:
		target_speed *= 0.45 # Phase 3: 45% block movement speed
	var target_horizontal: Vector3 = move_dir * target_speed
	if _shield_stun_timer > 0.0:
		target_horizontal = Vector3.ZERO # Stop movement during shield break stun

	# Accelerate or Decelerate Horizontally
	var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var lerp_rate: float = acceleration if move_dir.length_squared() > 0.001 else friction
	var new_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, lerp_rate * delta)
	velocity.x = new_horizontal.x
	velocity.z = new_horizontal.z

	# Rotate Character Visuals
	if visuals:
		if is_third_person:
			if combat_state == CombatState.BLOCK:
				# Face camera yaw while blocking to keep shield facing threat
				visuals.rotation.y = lerp_angle(visuals.rotation.y, _camera_yaw, rotation_speed * delta)
			elif combat_state != CombatState.ATTACK and move_dir.length_squared() > 0.001:
				var target_angle: float = atan2(-move_dir.x, -move_dir.z)
				visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)
		else:
			# In 1st person: orient character with camera yaw for accurate forward aim
			visuals.rotation.y = _camera_yaw

	move_and_slide()

	# FSM Locomotion transitions (only when in IDLE or RUN)
	if combat_state == CombatState.IDLE or combat_state == CombatState.RUN:
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
			_attack_impact_applied = false
			_orient_attack_direction()
			if anim_player and anim_player.has_animation("attack"):
				anim_player.speed_scale = 1.0
				anim_player.stop()
				anim_player.play("attack", 0.05)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.BLOCK:
			if is_shield_broken or combat_state == CombatState.ATTACK or combat_state == CombatState.DEAD:
				# Block rejected while shield broken, attacking, or dead
				return false
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
	_attack_impact_applied = true # Stop any pending impact
	_block_transition = ""
	
	# Stop movement and combat actions
	velocity = Vector3.ZERO
	if combat and combat.slash_effect:
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
	return not is_shield_broken and combat_state != CombatState.DEAD and combat_state != CombatState.ATTACK


func _try_combat_attack() -> bool:
	return transition_to(CombatState.ATTACK)


func _start_block() -> bool:
	if is_shield_broken or combat_state == CombatState.DEAD:
		return false
	return transition_to(CombatState.BLOCK)


func _release_block() -> void:
	if combat_state != CombatState.BLOCK:
		return
	
	var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_z: float = Input.get_axis("move_forward", "move_backward")
	var is_moving: bool = abs(input_x) > 0.1 or abs(input_z) > 0.1 or horiz_sq > 0.05
	
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
	if is_third_person and visuals:
		var input_x: float = Input.get_axis("move_left", "move_right")
		var input_z: float = Input.get_axis("move_forward", "move_backward")
		if abs(input_x) > 0.1 or abs(input_z) > 0.1:
			var cam_yaw_basis: Basis = Basis(Vector3.UP, camera_pivot.rotation.y)
			var move_dir: Vector3 = (cam_yaw_basis * Vector3(input_x, 0.0, input_z)).normalized()
			visuals.rotation.y = atan2(-move_dir.x, -move_dir.z)
		else:
			visuals.rotation.y = _camera_yaw


const NO_ATTACKER_POS: Vector3 = Vector3(99999.0, 99999.0, 99999.0)


func take_damage(amount: float, attacker_pos: Vector3 = NO_ATTACKER_POS, incoming_shield_damage: float = 15.0) -> void:
	if combat_state == CombatState.DEAD:
		# TEST 16: No damage can be processed after DEAD
		return
	
	var final_damage: float = amount
	if combat_state == CombatState.BLOCK and not is_shield_broken and attacker_pos != NO_ATTACKER_POS:
		if combat and combat.is_attack_inside_block_cone(self, attacker_pos, block_cone_deg):
			final_damage = amount * (1.0 - block_damage_reduction)
			if combat and combat.has_method("trigger_block_impact"):
				var to_attacker: Vector3 = attacker_pos - global_position
				to_attacker.y = 0.0
				var to_attacker_dir: Vector3 = to_attacker.normalized() if to_attacker.length_squared() > 0.0001 else Vector3.FORWARD
				var incoming_dir: Vector3 = -to_attacker_dir
				var block_pos: Vector3 = global_position + Vector3(0.0, 0.9, 0.0) + to_attacker_dir * 0.4
				combat.trigger_block_impact(block_pos, incoming_dir)
			apply_shield_damage(incoming_shield_damage)
	else:
		# Unblocked hit visual feedback on player's body
		if combat and combat.has_method("trigger_hit_impact") and attacker_pos != NO_ATTACKER_POS:
			var to_attacker: Vector3 = attacker_pos - global_position
			to_attacker.y = 0.0
			var to_attacker_dir: Vector3 = to_attacker.normalized() if to_attacker.length_squared() > 0.0001 else Vector3.FORWARD
			var hit_pos: Vector3 = global_position + Vector3(0.0, 0.9, 0.0) + to_attacker_dir * 0.35
			combat.trigger_hit_impact(hit_pos, -to_attacker_dir)
	
	if health_component:
		health_component.take_damage(final_damage)
	elif final_damage > 0.0:
		transition_to(CombatState.DEAD)


func apply_shield_damage(amount: float) -> void:
	if shield_state == ShieldState.BROKEN:
		return
	var prev_durability: float = shield_durability
	shield_durability = maxf(0.0, shield_durability - amount)
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	if prev_durability > 0.0 and shield_durability <= 0.0:
		break_shield()


func break_shield() -> void:
	if shield_state == ShieldState.BROKEN or combat_state == CombatState.DEAD:
		return
	shield_state = ShieldState.BROKEN
	_shield_break_count += 1
	_shield_stun_timer = shield_break_stun_duration
	_shield_recovery_timer = shield_recovery_delay
	shield_durability = 0.0
	shield_durability_changed.emit(0.0, shield_max_durability)
	
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
	
	shield_broken.emit()


func _restore_shield() -> void:
	if shield_state != ShieldState.BROKEN:
		return
	shield_state = ShieldState.READY
	_shield_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	shield_restored.emit()


func reset_shield_durability() -> void:
	shield_state = ShieldState.READY
	_shield_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)


func respawn(spawn_pos: Vector3 = Vector3.ZERO, spawn_yaw: float = 0.0) -> void:
	if combat_state != CombatState.DEAD and not is_dead:
		return

	# 1. Reset Health
	if health_component:
		health_component.reset_health()

	# 2. Reset Shield
	reset_shield_durability()

	# 3. Clear timers and internal states
	_shield_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	_attack_impact_applied = false
	_block_transition = ""

	# 4. Stop active VFX
	if combat:
		combat.stop_slash_effect()

	# 5. Position, yaw, and velocity
	velocity = Vector3.ZERO
	global_position = spawn_pos
	_camera_yaw = spawn_yaw
	_camera_pitch = 0.0
	if camera_pivot:
		camera_pivot.rotation.y = _camera_yaw
		camera_pivot.rotation.x = _camera_pitch
	if visuals:
		visuals.rotation.y = _camera_yaw

	# 6. Reset combat state to IDLE & restore locomotion animation
	var old_state: CombatState = combat_state
	combat_state = CombatState.IDLE
	if anim_player and anim_player.has_animation("idle"):
		anim_player.speed_scale = 1.0
		anim_player.stop()
		anim_player.play("idle", 0.1)

	state_changed.emit(old_state, combat_state)


func _on_health_died() -> void:
	transition_to(CombatState.DEAD)


func _on_animation_finished(anim_name: StringName) -> void:
	if combat_state == CombatState.DEAD:
		# TEST 15: Character remains DEAD and at death location after dead animation completes
		return

	if anim_name == "attack":
		_attack_impact_applied = false
		var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
		var input_x: float = Input.get_axis("move_left", "move_right")
		var input_z: float = Input.get_axis("move_forward", "move_backward")
		var has_move_input: bool = abs(input_x) > 0.1 or abs(input_z) > 0.1 or horiz_sq > 0.05
		
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
