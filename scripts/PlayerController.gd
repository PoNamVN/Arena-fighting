class_name PlayerController
extends CharacterBody3D

@export var external_controlled: bool = false
var controls_enabled: bool = true
var external_move_direction: Vector3 = Vector3.ZERO

# Store previous global position for shield charge impact correction
var _last_global_position: Vector3 = Vector3.ZERO
const CHARGE_DISTANCE_LIMIT := 11.0
var _charge_distance := 0.0
var _charge_clock := 0.0
var _charge_vfx: Node
var _impact_stun_timer:=0.0
const SHIELD_RAM_STUN:=0.75
var _charge_hit_query:=PhysicsShapeQueryParameters3D.new()
var _charge_hit_shape:=SphereShape3D.new()

## Combat FSM
enum CombatState {
	IDLE,
	RUN,
	ATTACK,
	BLOCK,
	DEAD,
	DODGE,
	COUNTER
}

signal state_changed(old_state: CombatState, new_state: CombatState)
# Reserved visual-only hooks. Emissions are deliberately not wired in task 0.2.
signal presentation_cast_started(skill_id: StringName)
signal presentation_skill_finished(skill_id: StringName, cancelled: bool)

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

@export_group("Counter Attack")
@export var counter_attack_damage: float = 50.0
@export var counter_lunge_duration: float = 0.20
@export var counter_arrival_distance: float = 1.2

var _counter_target: Node3D = null
var _counter_timer: float = 0.0
var _counter_lunge_total_time: float = 0.20
var _counter_strike_executed: bool = false
var _counter_recovery_timer: float = 0.0

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
@onready var stamina_component: StaminaComponent = get_node_or_null("StaminaComponent") as StaminaComponent
@onready var dodge_controller: DodgeController = get_node_or_null("DodgeController") as DodgeController
var ability_system: AbilitySystem:
	get:
		if not _ability_system:
			_ability_system = get_node_or_null("AbilitySystem") as AbilitySystem
		return _ability_system
	set(value):
		_ability_system = value
var _ability_system: AbilitySystem = null
var active_ability_action: AbilityAction = null

signal ability_action_started(slot_name: String, ability: AbilityData)
signal ability_action_finished(slot_name: String)

@export var hero_profile: String = "knight"
const ARCHER_TOON_SHADER: Shader = preload("res://shaders/archer_toon.gdshader")
const ARCHER_CAPE_SHADER: Shader = preload("res://shaders/archer_cape.gdshader")
var _cape_material: ShaderMaterial = null
var _archer_toon_materials: Array[ShaderMaterial] = []
var _cape_current_drag: Vector3 = Vector3.ZERO
var _cape_current_tuck: float = 0.0
var _hit_flash_tween: Tween = null
var hawk_carry: HawkCarryEffect
var archer_combat: ArcherCombat = null
var spectacle: Node
var _dive_vfx: Node
var wizard_combat: WizardCombat = null
var frost: FreezeEffect
var polymorph: PolymorphEffect
var is_shield_enlarged: bool = false
var _giant_shield_visual: Node3D = null
var _shield_visual_tween: Tween = null
var _shield_bone_idx: int = -1
var _z_shield_visual_root: Node3D
var _z_shield_original: MeshInstance3D
var _z_shield_socket: Marker3D
var _z_shield_mesh: MeshInstance3D
var _z_shield_scale: float = 1.0
var _z_shield_legacy_size: Vector3
var _z_shield_wood_normal: Vector3
var _z_shield_returning: bool = false
var _z_shield_fit: RefCounted
@export var steering_turn_rate: float = 7.0 # rad/s (~400 deg/s)

## Sky Dive (X) State
var _sky_dive_sub_phase: int = 0  # 0=none, 1=takeoff, 2=aim, 3=dive, 4=landing
var _sky_dive_direction: Vector3 = Vector3.FORWARD
var _sky_dive_start_y: float = 0.0
var _sky_dive_aim_entry_frame: int = -1
var _sky_dive_attack_armed: bool = false
# Presentation-only tilt; collision, camera and dive direction stay code-owned.
var _sky_dive_model_rest: Transform3D = Transform3D.IDENTITY
var _sky_dive_model_cached: bool = false
const SKY_DIVE_LAUNCH_VELOCITY: float = 12.0  # Upward launch speed
const SKY_DIVE_JUMP_HEIGHT: float = 3.5  # Target height
const SKY_DIVE_DIVE_SPEED: float = 20.0  # Dive movement speed
const SKY_DIVE_HOVER_GRAVITY: float = 4.0  # Reduced gravity during aim

@onready var giant_sword_ultimate: GiantSwordUltimate = get_node_or_null("GiantSwordUltimate") as GiantSwordUltimate

var anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var ragdoll: Node = null
var last_hit_was_blocked: bool = false
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

var is_countering: bool:
	get:
		return combat_state == CombatState.COUNTER

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
	_charge_hit_shape.radius=1.3
	_charge_hit_query.shape=_charge_hit_shape
	_charge_hit_query.collision_mask=4
	_charge_hit_query.exclude=[get_rid()]
	_setup_fallback_input_actions()
	if not external_controlled:
		_set_mouse_captured(true)
	else:
		camera.current = false
	if camera_pivot:
		_camera_yaw = camera_pivot.rotation.y
		_camera_pitch = camera_pivot.rotation.x
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
		if spring_arm.shape == null:
			var cam_shape := SphereShape3D.new()
			cam_shape.radius = 0.22
			spring_arm.shape = cam_shape
			spring_arm.margin = 0.12
	if hero_profile in ["archer", "wizard"]:
		var old_model: Node = visuals.get_node("CharacterModel")
		visuals.remove_child(old_model)
		old_model.queue_free()
		var model_scene: PackedScene = preload("res://assets/models/elemental_wizard.glb") if hero_profile == "wizard" else preload("res://assets/models/forest_archer.glb")
		var hunter: Node3D = model_scene.instantiate() as Node3D
		hunter.name = "CharacterModel"
		if hero_profile == "archer":
			hunter.rotation.y = PI
		visuals.add_child(hunter)
		if hero_profile == "archer":
			apply_archer_look()
	hawk_carry = HawkCarryEffect.new()
	hawk_carry.actor = self
	add_child(hawk_carry)
	_setup_animation_player()
	set_third_person(is_third_person)

	if health_component:
		if not health_component.died.is_connected(_on_health_died):
			health_component.died.connect(_on_health_died)

	if not stamina_component:
		stamina_component = get_node_or_null("StaminaComponent") as StaminaComponent
	if not stamina_component:
		stamina_component = StaminaComponent.new()
		stamina_component.name = "StaminaComponent"
		add_child(stamina_component)

	if not dodge_controller:
		dodge_controller = get_node_or_null("DodgeController") as DodgeController
	if not dodge_controller:
		dodge_controller = DodgeController.new()
		dodge_controller.name = "DodgeController"
		add_child(dodge_controller)
	dodge_controller.stamina_component = stamina_component
	if hero_profile in ["knight", "archer"]:
		dodge_controller.dodge_duration = 0.40
		dodge_controller.dodge_distance = 5.0
	if not dodge_controller.dodge_completed.is_connected(_on_dodge_completed):
		dodge_controller.dodge_completed.connect(_on_dodge_completed)

	if not ability_system:
		ability_system = get_node_or_null("AbilitySystem") as AbilitySystem
	if not ability_system:
		ability_system = AbilitySystem.new()
		ability_system.name = "AbilitySystem"
		add_child(ability_system)
	polymorph = PolymorphEffect.new()
	polymorph.actor = self
	add_child(polymorph)
	frost = FreezeEffect.new()
	frost.actor = self
	add_child(frost)
	ability_system.stamina_component = stamina_component
	if hero_profile == "knight":
		equip_knight_loadout()
	elif hero_profile == "archer":
		ability_system.clear_loadout()
		archer_combat = ArcherCombat.new()
		archer_combat.name = "ArcherCombat"
		archer_combat.actor = self
		add_child(archer_combat)
		var archer_dash = preload("res://scripts/ArcherDashPresentation.gd").new()
		archer_dash.name = "ArcherDashPresentation"
		add_child(archer_dash)
	elif hero_profile == "wizard":
		ability_system.clear_loadout()
		wizard_combat = WizardCombat.new()
		wizard_combat.actor = self
		add_child(wizard_combat)

	spectacle = preload("res://scripts/CombatSpectacle.gd").new()
	spectacle.name = "CombatSpectacle"
	add_child(spectacle)
	_setup_giant_shield_visual()
	if hero_profile == "knight":
		_charge_vfx = preload("res://scripts/KnightChargeVFX.gd").new()
		_charge_vfx.name = "KnightChargeVFX"
		add_child(_charge_vfx)
		_dive_vfx = preload("res://scripts/KnightDiveVFX.gd").new()
		_dive_vfx.name = "KnightDiveVFX"
		add_child(_dive_vfx)

func equip_knight_loadout() -> void:
	if ability_system:
		KnightAbilities.equip_knight_loadout(ability_system)



func _unhandled_input(event: InputEvent) -> void:
	if external_controlled or not controls_enabled:
		return
	# Once DEAD: lock all movement, attack, and block input
	if combat_state == CombatState.DEAD:
		# Still allow camera look and perspective toggle for viewing death
		if event is InputEventMouseMotion and _is_mouse_captured:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			_camera_yaw -= motion.relative.x * mouse_sensitivity
			_camera_pitch -= motion.relative.y * mouse_sensitivity
			_camera_pitch = clampf(_camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
			_update_camera()
		elif event.is_action_pressed("toggle_perspective") and not event.is_echo():
			toggle_camera_perspective()
		return

	if wizard_combat and wizard_combat.storm.active():
		wizard_combat.storm.handle_input(event)
		get_viewport().set_input_as_handled()
		return
	if archer_combat and archer_combat.bait_ultimate.phase == ArcherBaitUltimate.Phase.AIM:
		archer_combat.bait_ultimate.handle_input(event)
		get_viewport().set_input_as_handled()
		return

	if active_ability_action and active_ability_action.is_active() and active_ability_action.data.id == "giant_sword_ultimate":
		giant_sword_ultimate.handle_input(event)
		return

	# Toggle third-person / first-person perspective
	if event.is_action_pressed("toggle_perspective") and not event.is_echo():
		toggle_camera_perspective()

	# Mouse look
	if event is InputEventMouseMotion and _is_mouse_captured:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_yaw -= motion.relative.x * mouse_sensitivity
		_camera_pitch -= motion.relative.y * mouse_sensitivity
		var aim_max_pitch := 85.0 if archer_combat and archer_combat.sky_aiming else max_pitch
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(min_pitch), deg_to_rad(aim_max_pitch))

		_update_camera()

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

	if is_control_impaired():
		# Allow Wake-up Block input while settling/recovering on ground
		if event.is_action_pressed("block") and is_ragdoll_active() and ragdoll and ragdoll.call("can_wake_up_block"):
			if not is_shield_broken:
				_start_block()
		return
	if wizard_combat:
		wizard_combat.handle_input(event)
		return
	if archer_combat:
		archer_combat.handle_input(event)
		return

	# Combat Input Actions (Single source of truth via InputMap)
	if event.is_action_pressed("attack") and not event.is_echo():
		# X owns LMB throughout its lifecycle; physics validates the fresh AIM edge.
		if active_ability_action and active_ability_action.is_active() and active_ability_action.data and active_ability_action.data.id == "sky_dive":
			if _sky_dive_sub_phase == 2 and Engine.get_physics_frames() <= _sky_dive_aim_entry_frame:
				_sky_dive_attack_armed = false
			return
		if is_counter_window_active():
			if try_counter_attack(true):
				return
			else:
				# If no valid target exists, LMB does nothing and must not start Counter.
				return
		_try_combat_attack()
	elif event.is_action_pressed("block"):
		if not is_shield_broken:
			_start_block()
	elif event.is_action_released("block"):
		_release_block()
	elif event.is_action_pressed("dodge") and not event.is_echo():
		_try_dodge()
	elif event.is_action_pressed("skill_1"):
		_try_cast_ability("skill_1")
	elif event.is_action_pressed("skill_2"):
		_try_cast_ability("skill_2")
	elif event.is_action_pressed("skill_3"):
		_try_cast_ability("skill_3")
	elif event.is_action_pressed("ultimate"):
		_try_cast_ability("ultimate")


func _physics_process(delta: float) -> void:
	if hawk_carry and hawk_carry.active():
		hawk_carry.step(delta)
		return
	if spectacle and hero_profile == "knight" and active_ability_action and active_ability_action.is_active():
		spectacle.wake()
	if not controls_enabled and not is_dead:
		velocity = Vector3.ZERO
		if not is_on_floor():
			velocity.y = -gravity * delta
		move_and_slide()
		return
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

	if _impact_stun_timer > 0.0:
		_impact_stun_timer=maxf(0.0,_impact_stun_timer-delta)
		var pushed:=minf(_knockback_timer,delta)/maxf(delta,.000001)
		_knockback_timer=maxf(0.0,_knockback_timer-delta)
		velocity.x=0.0 if frost and frost.active() else _knockback_vel.x*pushed
		velocity.z=0.0 if frost and frost.active() else _knockback_vel.z*pushed
		velocity.y = -0.1 if (is_on_floor() and velocity.y <= 0.0) else velocity.y - gravity * delta
		move_and_slide()
		return

	if is_ragdoll_active():
		velocity = Vector3.ZERO
		return

	if wizard_combat and wizard_combat.storm.active():
		velocity.x = 0
		velocity.z = 0
		velocity.y = -0.1 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		return
	if wizard_combat and wizard_combat.ice.active:
		wizard_combat.ice.process_movement(delta)
		return
	if frost and frost.active():
		_knockback_timer = maxf(0, _knockback_timer - delta)
		velocity.x = 0
		velocity.z = 0
		velocity.y = -0.1 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		return

	# DODGE state: moves character with dodge velocity
	if combat_state == CombatState.DODGE:
		var dodge_vel: Vector3 = dodge_controller.get_dodge_velocity(delta) if dodge_controller else Vector3.ZERO
		velocity.x = dodge_vel.x
		velocity.z = dodge_vel.z
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1
		move_and_slide()
		if visuals and dodge_controller and dodge_controller.world_direction.length_squared() > 0.01:
			if hero_profile == "archer":
				visuals.rotation.y = _camera_yaw
			else:
				visuals.rotation.y = atan2(-dodge_controller.world_direction.x, -dodge_controller.world_direction.z)
		return

	if archer_combat and archer_combat.bait_ultimate.input_busy() and _knockback_timer <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.1 if is_on_floor() else velocity.y - gravity * delta
		move_and_slide()
		return

	if archer_combat and archer_combat.dash_active:
		archer_combat.process_escape_movement(delta)
		return

	if wizard_combat and wizard_combat.counter_active:
		wizard_combat.process_counter_movement(delta)
		return
	if archer_combat and archer_combat.counter_active:
		archer_combat.process_counter_movement(delta)
		return

	# COUNTER state: fast lunge towards target using move_and_slide(), then strike on arrival
	if combat_state == CombatState.COUNTER:
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = -0.1

		if not _counter_strike_executed:
			_counter_timer += delta
			if is_instance_valid(_counter_target):
				var to_target: Vector3 = _counter_target.global_position - global_position
				to_target.y = 0.0
				var dist: float = to_target.length()
				var desired_stop_dist: float = counter_arrival_distance
				var remaining_dist: float = maxf(0.0, dist - desired_stop_dist)

				if dist > 0.001:
					var face_dir: Vector3 = to_target.normalized()
					var look_yaw: float = atan2(-face_dir.x, -face_dir.z)
					if visuals:
						visuals.rotation.y = look_yaw
					_camera_yaw = look_yaw

					var time_left: float = maxf(0.001, _counter_lunge_total_time - _counter_timer)
					var lunge_speed: float = remaining_dist / time_left
					var horiz_vel: Vector3 = face_dir * lunge_speed
					velocity.x = horiz_vel.x
					velocity.z = horiz_vel.z
				else:
					velocity.x = 0.0
					velocity.z = 0.0
			else:
				velocity.x = 0.0
				velocity.z = 0.0

			move_and_slide()

			var is_arrived: bool = _counter_timer >= _counter_lunge_total_time
			if is_instance_valid(_counter_target):
				var curr_dist: float = (Vector3(_counter_target.global_position.x, 0, _counter_target.global_position.z) - Vector3(global_position.x, 0, global_position.z)).length()
				if curr_dist <= counter_arrival_distance + 0.15:
					is_arrived = true

			if is_arrived:
				velocity.x = 0.0
				velocity.z = 0.0
				_execute_counter_strike()
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			move_and_slide()
			_counter_recovery_timer -= delta
			if _counter_recovery_timer <= 0.0:
				_finish_counter_attack()
		return

	# SHIELD CHARGE (Ability Z) movement & steering
	if active_ability_action and active_ability_action.is_active() and active_ability_action.data and active_ability_action.data.id == "shield_charge":
		_process_shield_charge(delta)
		return

	# SKY DIVE (Ability X) foundation movement
	if active_ability_action and active_ability_action.is_active() and active_ability_action.data and active_ability_action.data.id == "sky_dive":
		_process_sky_dive(delta)
		return

	if active_ability_action and active_ability_action.is_active() and active_ability_action.data and active_ability_action.data.id in ["whirling_blade", "giant_sword_ultimate"]:
		_process_stationary_ability(delta)
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
		if not external_controlled and Input.is_action_just_pressed("jump") and combat_state != CombatState.BLOCK and combat_state != CombatState.ATTACK and _shield_stun_timer <= 0.0 and not (is_control_impaired()):
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

	if external_controlled:
		move_dir = external_move_direction.limit_length(1.0)

	# Determine Target Speed
	var is_sprinting: bool = not external_controlled and Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	if combat_state == CombatState.ATTACK or _combo_finisher_recovery_timer > 0.0:
		target_speed *= 0.5 # Phase 2: 50% attack movement speed
	elif combat_state == CombatState.BLOCK:
		target_speed *= 0.45 # Phase 3: 45% block movement speed
	if wizard_combat and (wizard_combat.charging or wizard_combat.spell != "" or wizard_combat.staff_strike.active):
		target_speed *= 0.55
	if archer_combat and (archer_combat.charging or archer_combat.hawk_skill.casting or archer_combat.seeking_active):
		target_speed *= 0.55
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
		if active_ability_action and active_ability_action.is_active():
			active_ability_action.update(delta)
			if not active_ability_action.allows_movement():
				target_horizontal = Vector3.ZERO
		var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		var lerp_rate: float = acceleration if move_dir.length_squared() > 0.001 else friction
		var new_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, lerp_rate * delta)
		velocity.x = new_horizontal.x
		velocity.z = new_horizontal.z

	# Rotate Character Visuals (player horizontal yaw follows camera yaw in combat camera)
	if visuals:
		if not is_third_person:
			visuals.rotation.y = _camera_yaw
			_prev_camera_yaw = _camera_yaw
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
		if anim_player and _is_basic_attack_animation(anim_player.current_animation):
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
	if is_control_impaired() and new_state in [CombatState.ATTACK, CombatState.BLOCK, CombatState.COUNTER, CombatState.DODGE]:
		return false
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
			if combat_state == CombatState.ATTACK or (combat_state == CombatState.COUNTER and not _counter_strike_executed and not archer_combat and not wizard_combat):
				# Cannot exit attack or active counter prematurely
				return false
			combat_state = CombatState.IDLE
			_block_transition = ""
			if anim_player and anim_player.has_animation("idle"):
				anim_player.speed_scale = 1.0
				anim_player.play("idle", 0.18)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.RUN:
			if combat_state == CombatState.ATTACK or combat_state == CombatState.COUNTER:
				return false
			combat_state = CombatState.RUN
			_block_transition = ""
			if anim_player and anim_player.has_animation("run"):
				anim_player.play("run", 0.15)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.ATTACK:
			if combat_state == CombatState.ATTACK or combat_state == CombatState.DODGE or combat_state == CombatState.COUNTER:
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
				_play_basic_attack_animation()
			combo_step_changed.emit(_combo_step)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.BLOCK:
			if is_shield_broken or combat_state == CombatState.ATTACK or combat_state == CombatState.DEAD or combat_state == CombatState.DODGE or combat_state == CombatState.COUNTER or _combo_finisher_recovery_timer > 0.0:
				# Block rejected while shield broken, attacking, dead, dodging, or countering
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

		CombatState.DODGE:
			if combat_state == CombatState.DEAD or combat_state == CombatState.COUNTER or _combo_finisher_recovery_timer > 0.0:
				return false
			if is_shield_broken or _shield_stun_timer > 0.0:
				return false
			if combat_state == CombatState.ATTACK:
				reset_combo()
				_attack_impact_applied = true
				if combat and combat.has_method("stop_slash_effect"):
					combat.stop_slash_effect()
			elif combat_state == CombatState.BLOCK:
				_block_transition = ""

			_knockback_timer = 0.0
			_knockback_vel = Vector3.ZERO
			combat_state = CombatState.DODGE
			if anim_player:
				if anim_player.has_animation("dash_forward"):
					pass
				elif anim_player.has_animation("dodge"):
					anim_player.speed_scale = 1.0
					anim_player.play("dodge", 0.05)
				elif anim_player.has_animation("run"):
					anim_player.speed_scale = 2.2
					anim_player.play("run", 0.05)
			state_changed.emit(old_state, combat_state)
			return true

		CombatState.COUNTER:
			if combat_state == CombatState.DEAD:
				return false
			reset_combo()
			_knockback_timer = 0.0
			_knockback_vel = Vector3.ZERO
			combat_state = CombatState.COUNTER
			_block_transition = ""
			if anim_player:
				if anim_player.has_animation("attack"):
					anim_player.speed_scale = 1.6
					anim_player.play("attack", 0.05)
				elif anim_player.has_animation("run"):
					anim_player.speed_scale = 1.0
					anim_player.play("run", 0.05)
			state_changed.emit(old_state, combat_state)
			return true

	return false


func _enter_dead_state() -> void:
	_restore_z_shield_visual(true)
	var old_state: CombatState = combat_state
	combat_state = CombatState.DEAD
	reset_combo()
	_attack_impact_applied = true # Stop any pending impact
	_block_transition = ""
	_counter_target = null
	_counter_strike_executed = false
	_counter_timer = 0.0
	_counter_recovery_timer = 0.0

	if dodge_controller:
		dodge_controller.reset()
	if active_ability_action:
		active_ability_action.cancel()
		active_ability_action = null
	_clear_sky_dive_state()
	if stamina_component:
		stamina_component.reset_stamina()
	CombatTimeManager.reset_time()

	if ragdoll and ragdoll.call("is_active"):
		ragdoll.call("stop_ragdoll")

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


var is_dodging: bool:
	get:
		return combat_state == CombatState.DODGE or (dodge_controller != null and dodge_controller.is_dodging)

var is_dodging_iframe: bool:
	get:
		return is_in_dodge_iframe()

var is_invulnerable: bool:
	get:
		return is_in_dodge_iframe()


func is_in_dodge_iframe() -> bool:
	return dodge_controller != null and dodge_controller.is_in_dodge_iframe()


func can_perfect_dodge_attack(payload_or_dodgeable: Variant = true) -> bool:
	if dodge_controller and dodge_controller.has_method("can_perfect_dodge_attack"):
		return dodge_controller.can_perfect_dodge_attack(payload_or_dodgeable)
	return is_in_dodge_iframe()


func register_perfect_dodge(payload: Variant = null) -> bool:
	if dodge_controller and dodge_controller.has_method("register_perfect_dodge"):
		return dodge_controller.register_perfect_dodge(payload)
	return false


func is_counter_window_active() -> bool:
	return dodge_controller != null and dodge_controller.counter_window_active


func find_counter_target(range_limit: float = 8.0) -> Node3D:
	var candidates: Array[Node3D] = []

	# 1. Physics shape intersection in radius range_limit
	var world_3d: World3D = get_world_3d()
	if world_3d and is_inside_tree():
		var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
		if space_state:
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = range_limit
			query.shape = sphere
			query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.9, 0.0))
			query.collision_mask = 4 # Target collision layer
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.exclude = [get_rid()]
			var hits: Array[Dictionary] = space_state.intersect_shape(query, 32)
			for hit in hits:
				var col: Object = hit.get("collider")
				if col is Node3D and not (col in candidates):
					candidates.append(col as Node3D)

	# 2. Scene tree search across relevant enemy groups / nodes (robust for both live scene and tests)
	if is_inside_tree():
		for grp in ["enemies", "training_dummy", "targets"]:
			for node in get_tree().get_nodes_in_group(grp):
				if node is Node3D and not (node in candidates):
					candidates.append(node as Node3D)

	var best_target: Node3D = null
	var best_score: float = -999999.0
	var player_fwd: Vector3 = get_facing_direction()

	for cand in candidates:
		if cand == self or is_ancestor_of(cand) or cand.is_ancestor_of(self):
			continue
		if not cand.has_method("take_damage"):
			continue
		# Ignore dead / defeated targets
		if cand.has_method("is_dead") and cand.call("is_dead"):
			continue
		if cand.has_method("is_alive") and not cand.call("is_alive"):
			continue
		if cand.has_method("is_targetable") and not cand.call("is_targetable"):
			continue
		if "health_component" in cand and cand.health_component != null:
			if cand.health_component.has_method("is_dead") and cand.health_component.is_dead():
				continue

		var to_cand: Vector3 = cand.global_position - global_position
		to_cand.y = 0.0
		var dist: float = to_cand.length()
		if dist > range_limit:
			continue

		var dir: Vector3 = to_cand.normalized() if dist > 0.001 else player_fwd
		var facing_dot: float = player_fwd.dot(dir)
		# Score combines facing alignment (highest priority) and proximity
		var score: float = facing_dot * 3.0 + (1.0 - (dist / range_limit))
		if score > best_score:
			best_score = score
			best_target = cand

	return best_target


func try_counter_attack(is_new_press: bool = true) -> bool:
	if is_control_impaired():
		return false
	if wizard_combat:
		return is_new_press and wizard_combat.start_counter()
	if archer_combat:
		return is_new_press and archer_combat.start_counter()
	if not is_new_press:
		return false
	if not is_counter_window_active():
		return false
	if combat_state == CombatState.DEAD:
		return false
	var target_enemy: Node3D = find_counter_target(8.0)
	if target_enemy == null:
		return false
	if dodge_controller:
		dodge_controller.consume_counter_window()
	return _start_counter_attack(target_enemy)


func _start_counter_attack(target_enemy: Node3D) -> bool:
	if combat_state == CombatState.DEAD:
		return false
	if target_enemy == null:
		return false

	if dodge_controller and dodge_controller.is_dodging:
		dodge_controller.cancel_dodge()

	_counter_target = target_enemy
	_counter_timer = 0.0
	_counter_lunge_total_time = counter_lunge_duration
	_counter_strike_executed = false
	_counter_recovery_timer = 0.0

	var success: bool = transition_to(CombatState.COUNTER)
	if success:
		var to_target: Vector3 = target_enemy.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			var look_yaw: float = atan2(-to_target.x, -to_target.z)
			if visuals:
				visuals.rotation.y = look_yaw
			_camera_yaw = look_yaw
	return success


func _execute_counter_strike() -> void:
	if _counter_strike_executed:
		return
	_counter_strike_executed = true
	_counter_recovery_timer = 0.20

	if is_instance_valid(_counter_target):
		var to_target: Vector3 = _counter_target.global_position - global_position
		to_target.y = 0.0
		var fwd: Vector3 = to_target.normalized() if to_target.length_squared() > 0.0001 else get_facing_direction()
		if visuals:
			visuals.rotation.y = atan2(-fwd.x, -fwd.z)
		_camera_yaw = atan2(-fwd.x, -fwd.z)

		# Deal damage via existing combat pipeline
		if _counter_target.has_method("take_damage"):
			_counter_target.call("take_damage", counter_attack_damage, global_position)

		# Feedback and VFX
		if combat:
			var hit_pos: Vector3 = _counter_target.global_position + Vector3(0.0, 0.9, 0.0) - fwd * 0.3
			if combat.has_method("trigger_hit_impact"):
				combat.trigger_hit_impact(hit_pos, -fwd)
			if combat.slash_arc_vfx and combat.slash_arc_vfx.has_method("trigger"):
				combat.slash_arc_vfx.trigger(fwd, global_position)
			if combat.has_method("spawn_damage_number"):
				var dmg_pos: Vector3 = _counter_target.global_position + Vector3(0.0, 1.2, 0.0)
				combat.spawn_damage_number(dmg_pos, counter_attack_damage, false, 0.0)

		if combat_feedback and combat_feedback.has_method("trigger_hit_feedback"):
			combat_feedback.trigger_hit_feedback(_counter_target, counter_attack_damage)


func _finish_counter_attack() -> void:
	reset_combo()
	_counter_target = null
	_counter_strike_executed = false
	var old_state: CombatState = combat_state
	combat_state = CombatState.IDLE
	state_changed.emit(old_state, combat_state)
	_update_locomotion_animations()


func _can_cancel_attack_into_dodge() -> bool:
	if _combo_finisher_recovery_timer > 0.0:
		return false
	return true


func _try_dodge() -> bool:
	if is_control_impaired():
		return false
	if not controls_enabled:
		return false
	if combat_state == CombatState.DEAD:
		return false
	if _combo_finisher_recovery_timer > 0.0:
		return false
	if is_shield_broken or _shield_stun_timer > 0.0:
		return false
	if combat_state == CombatState.DODGE or combat_state == CombatState.COUNTER:
		return false
	if active_ability_action and active_ability_action.is_active():
		if not active_ability_action.allows_dodge():
			return false
		active_ability_action.cancel()
		active_ability_action = null
	if not dodge_controller:
		return false
	if not dodge_controller.can_dodge():
		return false

	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_z: float = Input.get_axis("move_forward", "move_backward")
	if external_controlled:
		var local_direction: Vector3 = Basis(Vector3.UP, _camera_yaw).inverse() * external_move_direction
		input_x = local_direction.x
		input_z = local_direction.z
	var input_vec: Vector2 = Vector2(input_x, -input_z)
	var resolved_dir: DodgeController.Direction = dodge_controller.determine_dodge_direction(input_vec)

	var cam_yaw_basis: Basis = Basis(Vector3.UP, _camera_yaw) if camera_pivot else global_basis
	var world_dir: Vector3 = Vector3.ZERO
	if Vector2(input_x, input_z).length_squared() > 0.01:
		world_dir = (cam_yaw_basis * Vector3(input_x, 0.0, input_z)).normalized()
	else:
		world_dir = (-cam_yaw_basis.z).normalized()
	world_dir.y = 0.0
	world_dir = world_dir.normalized()

	if wizard_combat:
		wizard_combat.interrupt()
	if archer_combat:
		archer_combat.interrupt()
	# Match the backflip timing to the captured facing, independent of camera yaw.
	if hero_profile == "knight":
		var facing_local := visuals.global_basis.orthonormalized().inverse() * world_dir
		var backflip := absf(facing_local.z) >= absf(facing_local.x) and facing_local.z > 0.0
		dodge_controller.dodge_duration = 0.45 if backflip else 0.40
		dodge_controller.dodge_distance = 5.0
	elif hero_profile == "archer":
		var facing_local := visuals.global_basis.orthonormalized().inverse() * world_dir
		var backflip := absf(facing_local.z) >= absf(facing_local.x) and facing_local.z > 0.0
		dodge_controller.dodge_duration = 0.60 if backflip else 0.40
		dodge_controller.dodge_distance = 6.5 if backflip else 5.0
	if transition_to(CombatState.DODGE):
		var started: bool = dodge_controller.start_dodge(resolved_dir, world_dir)
		if started and combat_feedback and combat_feedback.has_method("trigger_dodge_feedback"):
			combat_feedback.trigger_dodge_feedback()
		return started

	return false


func _on_dodge_completed() -> void:
	if combat_state == CombatState.DODGE:
		if hero_profile in ["knight", "archer"]:
			dodge_controller.dodge_duration = 0.40
			dodge_controller.dodge_distance = 5.0
		var input_x: float = external_move_direction.x if external_controlled else Input.get_axis("move_left", "move_right")
		var input_z: float = external_move_direction.z if external_controlled else Input.get_axis("move_forward", "move_backward")
		var has_input: bool = (abs(input_x) > 0.1 or abs(input_z) > 0.1)
		if not has_input:
			velocity.x = 0.0
			velocity.z = 0.0
		var next_state: CombatState = CombatState.RUN if has_input else CombatState.IDLE
		combat_state = next_state
		state_changed.emit(CombatState.DODGE, next_state)
		_update_locomotion_animations()


func is_targetable() -> bool:
	return not is_dead and not (archer_combat and archer_combat.is_hidden())


func get_facing_direction() -> Vector3:
	var fwd: Vector3 = (-visuals.global_basis.z) if (visuals and is_third_person) else (-camera.global_basis.z if camera else -global_basis.z)
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD


func _try_cast_ability(slot_name: String) -> bool:
	if is_control_impaired():
		return false
	if hero_profile == "wizard" and wizard_combat:
		match slot_name:
			"skill_1": return wizard_combat.start_staff()
			"skill_2": return wizard_combat.start_polymorph()
			"skill_3": return wizard_combat.ice.begin()
			"ultimate": return wizard_combat.storm.begin()
		return false
	if hero_profile == "archer" and archer_combat:
		match slot_name:
			"skill_1": return archer_combat.start_hawk()
			"skill_2": return archer_combat.start_seeking()
			"skill_3": return archer_combat.start_escape()
			"ultimate": return archer_combat.bait_ultimate.begin()
		return false
	if not controls_enabled:
		return false
	if combat_state == CombatState.DEAD:
		return false
	if _combo_finisher_recovery_timer > 0.0:
		return false
	if combat_state == CombatState.DODGE or combat_state == CombatState.COUNTER:
		return false
	if is_shield_broken or _shield_stun_timer > 0.0:
		return false
	if active_ability_action and active_ability_action.is_active():
		return false
	if not ability_system:
		return false

	if combat_state == CombatState.ATTACK:
		if not _attack_impact_applied or (anim_player and anim_player.current_animation_position <= ATTACK_IMPACT_TIMESTAMP):
			return false
		reset_combo()
		if combat and combat.has_method("stop_slash_effect"):
			combat.stop_slash_effect()

	if combat_state == CombatState.BLOCK:
		_release_block()

	if not ability_system.can_cast(slot_name):
		return false

	var ability: AbilityData = ability_system.get_ability(slot_name)
	if not ability:
		return false

	if not ability_system.cast_ability(slot_name):
		return false

	active_ability_action = AbilityAction.new()
	active_ability_action.init_action(self, slot_name, ability)
	active_ability_action.action_finished.connect(_on_ability_action_finished.bind(slot_name))
	active_ability_action.action_cancelled.connect(_on_ability_action_cancelled.bind(slot_name))
	ability_action_started.emit(slot_name, ability)

	if ability.id == "shield_charge":
		_start_shield_charge(ability)
	elif ability.id == "sky_dive":
		_start_sky_dive(ability)
	elif ability.id == "whirling_blade":
		_start_whirling_blade()
	elif ability.id == "giant_sword_ultimate":
		_start_giant_sword()
	else:
		_execute_ability_effect(slot_name, ability)
	return true


func _on_ability_action_finished(slot_name: String) -> void:
	if _charge_vfx:
		_charge_vfx.stop(false)
	_clear_whirling_blade()
	_clear_giant_sword()
	if active_ability_action and active_ability_action.data and active_ability_action.data.id == "sky_dive":
		_clear_sky_dive_state()
	_restore_z_shield_visual(true)
	_combo_step = 0
	_combo_recovery_timer = 0.0
	_update_locomotion_animations()
	ability_action_finished.emit(slot_name)
	active_ability_action = null


func _on_ability_action_cancelled(slot_name: String) -> void:
	if _charge_vfx:
		_charge_vfx.stop(true)
	_clear_whirling_blade()
	_clear_giant_sword()
	if active_ability_action and active_ability_action.data and active_ability_action.data.id == "sky_dive":
		_clear_sky_dive_state()
	_restore_z_shield_visual(true)
	_combo_step = 0
	_combo_recovery_timer = 0.0
	_update_locomotion_animations()
	ability_action_finished.emit(slot_name)
	active_ability_action = null


func _start_whirling_blade() -> void:
	_orient_attack_direction()
	if combat_state == CombatState.ATTACK or combat_state == CombatState.BLOCK:
		var old_state: CombatState = combat_state
		combat_state = CombatState.IDLE
		state_changed.emit(old_state, combat_state)
	reset_combo()
	_block_transition = ""
	_attack_impact_applied = true
	velocity.x = 0.0
	velocity.z = 0.0
	active_ability_action.phase_changed.connect(_on_whirling_blade_phase_changed)
	if anim_player:
		anim_player.speed_scale = 1.0
		anim_player.play("Knight_C_WhirlingBlade", 0.05)


func _on_whirling_blade_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == AbilityAction.Phase.ACTIVE and combat:
		var action: AbilityAction = active_ability_action
		combat.execute_radial_ability_impact(action.data, action)


func _process_stationary_ability(delta: float) -> void:
	var action: AbilityAction = active_ability_action
	var is_ultimate: bool = action.data.id == "giant_sword_ultimate"
	if not is_ultimate or not giant_sword_ultimate.aiming:
		action.update(delta)
	if active_ability_action != action or not action.is_active():
		return
	if is_ultimate:
		giant_sword_ultimate.tick(delta, action)
	# WASD is locked; receiving a hit still applies the existing recoil impulse.
	velocity.x = 0.0
	velocity.z = 0.0
	if _knockback_timer > 0.0:
		_knockback_timer = maxf(0.0, _knockback_timer - delta)
		if _knockback_timer > 0.0:
			velocity.x = _knockback_vel.x
			velocity.z = _knockback_vel.z
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.1
	if visuals:
		visuals.rotation.y = _camera_yaw
	move_and_slide()


func _clear_whirling_blade() -> void:
	if not active_ability_action or not active_ability_action.data or active_ability_action.data.id != "whirling_blade":
		return
	if combat and combat.whirling_blade_vfx:
		combat.whirling_blade_vfx.stop()
	if anim_player and anim_player.current_animation == "Knight_C_WhirlingBlade":
		anim_player.stop()
		anim_player.speed_scale = 1.0


func _start_giant_sword() -> void:
	_orient_attack_direction()
	if combat_state == CombatState.ATTACK or combat_state == CombatState.BLOCK:
		var old_state: CombatState = combat_state
		combat_state = CombatState.IDLE
		state_changed.emit(old_state, combat_state)
	reset_combo()
	_block_transition = ""
	_attack_impact_applied = true
	velocity.x = 0.0
	velocity.z = 0.0
	active_ability_action.phase_changed.connect(_on_giant_sword_phase_changed)
	giant_sword_ultimate.begin()


func _on_giant_sword_phase_changed(_old_phase: int, new_phase: int) -> void:
	if new_phase == AbilityAction.Phase.ACTIVE and combat:
		giant_sword_ultimate.impact()
		var action: AbilityAction = active_ability_action
		combat.execute_radial_ability_impact(action.data, action)


func _clear_giant_sword() -> void:
	if not active_ability_action or not active_ability_action.data or active_ability_action.data.id != "giant_sword_ultimate":
		return
	if giant_sword_ultimate:
		giant_sword_ultimate.stop()
	if anim_player and anim_player.current_animation == "Knight_V_GiantSword":
		anim_player.stop()
		anim_player.speed_scale = 1.0


func _setup_giant_shield_visual() -> void:
	if hero_profile != "knight" or _z_shield_visual_root or not visuals:
		return
	_z_shield_original = visuals.find_child("Gladiator_Shield", true, false) as MeshInstance3D
	_z_shield_socket = visuals.find_child("Socket_ShieldCenter", true, false) as Marker3D
	if not _z_shield_original or not _z_shield_original.mesh or not _z_shield_socket:
		push_error("K3 Z requires Gladiator_Shield and Socket_ShieldCenter")
		return
	# Keep the old target node as an invisible transform reference only.
	_giant_shield_visual = visuals.get_node_or_null("GiantShieldVisual") as Node3D
	if not _giant_shield_visual:
		_giant_shield_visual = Node3D.new()
		_giant_shield_visual.name = "GiantShieldVisual"
		visuals.add_child(_giant_shield_visual)
		_giant_shield_visual.position = Vector3(-0.35, 0.95, -0.55)
		_giant_shield_visual.scale = Vector3(1.3, 1.3, 1.3)
	_giant_shield_visual.hide()
	# Fallback is the old combined plate/rim bounds, at the old active scale.
	_z_shield_legacy_size = Vector3(1.18, 1.68, 0.12) * 1.3
	var old_bounds := AABB()
	var has_old_mesh := false
	for child in _giant_shield_visual.get_children():
		if child is MeshInstance3D and child.mesh:
			var bounds: AABB = child.transform * child.mesh.get_aabb()
			old_bounds = old_bounds.merge(bounds) if has_old_mesh else bounds
			has_old_mesh = true
			child.hide()
	if has_old_mesh:
		_z_shield_legacy_size = old_bounds.size * 1.3
	var source_bounds := _z_shield_original.mesh.get_aabb()
	_z_shield_scale = _z_shield_legacy_size.y / source_bounds.size.y
	_z_shield_visual_root = Node3D.new()
	_z_shield_visual_root.name = "ZShieldVisualRoot"
	visuals.add_child(_z_shield_visual_root)
	_z_shield_visual_root.hide()
	_z_shield_mesh = MeshInstance3D.new()
	_z_shield_mesh.name = "ShieldMesh"
	_z_shield_mesh.mesh = _z_shield_original.mesh
	_z_shield_mesh.skeleton = NodePath("")
	_z_shield_mesh.skin = null
	_z_shield_visual_root.add_child(_z_shield_mesh)
	# The socket's rest +Z normal is the outward wooden face. Convert the
	# imported mesh's rest coordinates into that local frame, without skinning.
	var attachment := _z_shield_socket.get_parent() as BoneAttachment3D
	var skeleton := attachment.get_parent() as Skeleton3D
	var bone := skeleton.find_bone(attachment.bone_name)
	var socket_rest: Transform3D = skeleton.global_transform * skeleton.get_bone_global_rest(bone) * _z_shield_socket.transform
	_z_shield_wood_normal = (_z_shield_original.global_basis.inverse() * socket_rest.basis.z).normalized()
	_z_shield_mesh.basis = Basis(Quaternion(_z_shield_wood_normal, Vector3.BACK))
	_z_shield_mesh.position = -(_z_shield_mesh.basis * source_bounds.get_center())
	# Keep the enlarged shield physical: airflow and impact glints replace the aura.
	_z_shield_mesh.material_overlay = null
	_z_shield_fit = preload("res://scripts/KnightShieldClearance.gd").new()
	_z_shield_fit.prepare(skeleton, skeleton.get_node("Gladiator_Mesh"), _z_shield_mesh)
	skeleton.skeleton_updated.connect(_fit_z_shield_pose)


func _enlarge_giant_shield() -> void:
	is_shield_enlarged = true
	if not _z_shield_visual_root or not _z_shield_original or not _z_shield_socket:
		return
	if _shield_visual_tween and _shield_visual_tween.is_valid():
		_shield_visual_tween.kill()
	_z_shield_returning = false
	_z_shield_original.hide()
	_z_shield_visual_root.global_transform = _z_shield_socket.global_transform.orthonormalized()
	_z_shield_visual_root.show()
	var start := _z_shield_visual_root.transform
	_shield_visual_tween = create_tween()
	_shield_visual_tween.tween_method(_blend_z_shield_out.bind(start), 0.0, 1.0, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _blend_z_shield_out(weight: float, start: Transform3D) -> void:
	var target := visuals.global_transform.affine_inverse() * _giant_shield_visual.global_transform
	# Local +Z is the wooden face; the old display faces along visual -Z.
	target.basis = target.basis.orthonormalized() * Basis(Vector3.UP, PI)
	target.basis = target.basis.scaled(Vector3.ONE * _z_shield_scale)
	_z_shield_visual_root.transform = start.interpolate_with(target, weight)
	_fit_z_shield_pose()


func _retract_giant_shield() -> void:
	_restore_z_shield_visual(false)


func _restore_z_shield_visual(immediate: bool = false) -> void:
	is_shield_enlarged = false
	if not is_instance_valid(_z_shield_visual_root) or not is_instance_valid(_z_shield_original):
		return
	if immediate or not _z_shield_visual_root.visible:
		if _shield_visual_tween and _shield_visual_tween.is_valid():
			_shield_visual_tween.kill()
		if is_instance_valid(_z_shield_socket) and _z_shield_socket.is_inside_tree() and _z_shield_visual_root.is_inside_tree():
			_z_shield_visual_root.global_transform = _z_shield_socket.global_transform.orthonormalized()
		_z_shield_visual_root.hide()
		_z_shield_visual_root.scale = Vector3.ONE
		_z_shield_original.show()
		_z_shield_returning = false
		return
	if _z_shield_returning:
		return
	if _shield_visual_tween and _shield_visual_tween.is_valid():
		_shield_visual_tween.kill()
	_z_shield_returning = true
	var start := _z_shield_visual_root.transform
	_shield_visual_tween = create_tween()
	_shield_visual_tween.tween_method(_blend_z_shield_back.bind(start), 0.0, 1.0, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shield_visual_tween.tween_callback(_restore_z_shield_visual.bind(true))


func _blend_z_shield_back(weight: float, start: Transform3D) -> void:
	var target := visuals.global_transform.affine_inverse() * _z_shield_socket.global_transform.orthonormalized()
	_z_shield_visual_root.transform = start.interpolate_with(target, weight)
	_fit_z_shield_pose()


func _fit_z_shield_pose() -> void:
	if _z_shield_fit and is_instance_valid(_z_shield_visual_root):
		_z_shield_fit.fit(_z_shield_visual_root)


func _process(delta: float) -> void:
	_update_camera(delta)
	if not is_instance_valid(_z_shield_visual_root) or not _z_shield_visual_root.visible:
		return
	if combat_state == CombatState.DEAD or _shield_stun_timer > 0.0 or is_control_impaired() or not controls_enabled or not active_ability_action or not active_ability_action.is_active():
		if _charge_vfx:
			_charge_vfx.stop(true)
		_restore_z_shield_visual(true)


func _exit_tree() -> void:
	if _charge_vfx:
		_charge_vfx.stop(true,false)
	_restore_z_shield_visual(true)

func _start_shield_charge(ability: AbilityData) -> void:
	_charge_distance = 0.0
	_charge_clock = 0.0
	_enlarge_giant_shield()
	_orient_attack_direction()
	if anim_player:
		anim_player.speed_scale = anim_player.get_animation("Knight_Z_Start").length / ability.startup_duration
		anim_player.play("Knight_Z_Start", 0.08)

	if active_ability_action:
		active_ability_action.phase_changed.connect(_on_shield_charge_phase_changed)
	if _charge_vfx:
		_charge_vfx.start()


func _on_shield_charge_phase_changed(old_phase: int, new_phase: int) -> void:
	if new_phase == AbilityAction.Phase.ACTIVE:
		print("[ShieldCharge] Phase: ACTIVE")
		if anim_player:
			anim_player.speed_scale = 1.0
			anim_player.play("Knight_Z_Charge", 0.07)
	elif new_phase == AbilityAction.Phase.RECOVERY:
		print("[ShieldCharge] Phase: RECOVERY")
		if _charge_vfx:
			_charge_vfx.stop(false)
		_retract_giant_shield()
		if anim_player:
			anim_player.speed_scale = 1.0
			anim_player.play("Knight_Z_Stop", 0.07)
	elif new_phase == AbilityAction.Phase.FINISHED:
		print("[ShieldCharge] Phase: FINISHED")
		_retract_giant_shield()


func _start_sky_dive(ability: AbilityData) -> void:
	if _dive_vfx:
		_dive_vfx.prepare()
	var model: Node3D = visuals.get_node_or_null("CharacterModel") as Node3D
	if model:
		_sky_dive_model_rest = model.transform
		_sky_dive_model_cached = true
	_orient_attack_direction()
	# X may replace an allowed attack follow-through or block release.
	if combat_state == CombatState.ATTACK or combat_state == CombatState.BLOCK:
		var old_state: CombatState = combat_state
		combat_state = CombatState.IDLE
		state_changed.emit(old_state, combat_state)
	reset_combo()
	_block_transition = ""
	_attack_impact_applied = true
	_sky_dive_sub_phase = 0
	_sky_dive_direction = Vector3.FORWARD
	_sky_dive_start_y = global_position.y
	_sky_dive_aim_entry_frame = -1
	_sky_dive_attack_armed = false
	if active_ability_action:
		active_ability_action.phase_changed.connect(_on_sky_dive_phase_changed)
	# Play sky dive animation if available
	if anim_player and anim_player.has_animation("Knight_X_SkyDive"):
		anim_player.speed_scale = 1.0
		anim_player.play("Knight_X_SkyDive", 0.1)


func _on_sky_dive_phase_changed(old_phase: int, new_phase: int) -> void:
	if new_phase == AbilityAction.Phase.ACTIVE:
		# ACTIVE = begin TAKEOFF sub-phase (launch upward)
		_sky_dive_sub_phase = 1  # TAKEOFF
		velocity.y = SKY_DIVE_LAUNCH_VELOCITY
		if _dive_vfx:
			_dive_vfx.launch()
	elif new_phase == AbilityAction.Phase.RECOVERY:
		_sky_dive_sub_phase = 4  # LANDING/RECOVERY
		if anim_player and anim_player.has_animation("Knight_X_SkyDive"):
			var animation: Animation = anim_player.get_animation("Knight_X_SkyDive")
			anim_player.play("Knight_X_SkyDive")
			anim_player.seek(animation.length * 0.8, true)
			if active_ability_action and active_ability_action.data.recovery_duration > 0.0:
				anim_player.speed_scale = animation.length * 0.2 / active_ability_action.data.recovery_duration


func _clear_sky_dive_state() -> void:
	if _dive_vfx:
		_dive_vfx.stop(not active_ability_action or active_ability_action.is_cancelled or is_dead)
	if _sky_dive_model_cached:
		var model: Node3D = visuals.get_node_or_null("CharacterModel") as Node3D
		if model:
			model.transform = _sky_dive_model_rest
		_sky_dive_model_cached = false
	if _sky_dive_sub_phase != 0:
		velocity = Vector3.ZERO
	_sky_dive_sub_phase = 0
	_sky_dive_direction = Vector3.FORWARD
	_sky_dive_start_y = 0.0
	_sky_dive_aim_entry_frame = -1
	_sky_dive_attack_armed = false
	if anim_player and anim_player.current_animation == "Knight_X_SkyDive":
		anim_player.stop()
		anim_player.speed_scale = 1.0


func _process_shield_charge(delta: float) -> void:
	var action = active_ability_action
	if not action or not action.is_active():
		return

	# Update the ability first
	action.update(delta)

	if not is_instance_valid(action):
		return
	if active_ability_action != action:
		return
	if not action.is_active():
		return

	match action.current_phase:
		AbilityAction.Phase.STARTUP:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)
			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				velocity.y = -0.1
			move_and_slide()
			if visuals:
				visuals.rotation.y = _camera_yaw

		AbilityAction.Phase.ACTIVE:
			if action.custom_data.has("ram_remaining"):
				velocity.x=0.0
				velocity.z=0.0
				velocity.y=-0.1 if is_on_floor() else velocity.y-gravity*delta
				move_and_slide()
				if _charge_vfx:_charge_vfx.tick(delta,get_facing_direction())
				action.custom_data.ram_remaining=maxf(0.0,float(action.custom_data.ram_remaining)-delta)
				if action.custom_data.ram_remaining<=0.0:
					action.phase_timer=0.001
					action.update(0.001)
				return
			# Player can steer charge using camera/mouse direction with a turn limit
			_last_global_position = global_position

			var target_yaw: float = _camera_yaw
			var current_yaw: float = visuals.rotation.y if visuals else _camera_yaw
			var diff: float = wrapf(target_yaw - current_yaw, -PI, PI)
			var max_turn_step: float = steering_turn_rate * delta
			var step: float = clamp(diff, -max_turn_step, max_turn_step)
			var new_yaw: float = current_yaw + step

			if visuals:
				visuals.rotation.y = new_yaw

			var fwd: Vector3 = Vector3(-sin(new_yaw), 0.0, -cos(new_yaw))
			_check_shield_charge_hit(fwd)
			if action.custom_data.has("ram_remaining"):
				return
			var next_clock: float = minf(_charge_clock + delta, action.data.active_duration)
			var charge_speed: float = (_charge_distance_at(next_clock, action.data.movement_speed) - _charge_distance_at(_charge_clock, action.data.movement_speed)) / delta
			_charge_clock = next_clock
			charge_speed = minf(charge_speed, maxf(0.0, CHARGE_DISTANCE_LIMIT - _charge_distance) / delta)
			velocity.x = fwd.x * charge_speed
			velocity.z = fwd.z * charge_speed

			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				velocity.y = -0.1

			move_and_slide()
			var travelled := global_position - _last_global_position
			travelled.y = 0.0
			_charge_distance += travelled.length()
			_check_shield_charge_hit(fwd)
			if _charge_vfx:
				_charge_vfx.tick(delta,fwd)
			var blocked := false
			for index in get_slide_collision_count():
				var collision := get_slide_collision(index)
				var collider := collision.get_collider() as CollisionObject3D
				if collider and (collider.collision_layer & 1) != 0 and collision.get_normal().dot(-fwd) > 0.6:
					blocked = true
			if blocked or _charge_distance >= CHARGE_DISTANCE_LIMIT - 0.0001:
				velocity.x = 0.0
				velocity.z = 0.0
				action.phase_timer = 0.001
				action.update(0.001)

		AbilityAction.Phase.RECOVERY:
			# Z has already braked; never add an uncontrolled recovery slide.
			velocity.x = 0.0
			velocity.z = 0.0
			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				velocity.y = -0.1
			move_and_slide()


func _process_sky_dive(delta: float) -> void:
	var action: AbilityAction = active_ability_action
	if not action or not action.is_active():
		return

	if action.current_phase == AbilityAction.Phase.STARTUP:
		action.update(delta)
		if active_ability_action != action or not action.is_active():
			return
		# On the transition frame, immediately use TAKEOFF physics. Never
		# overwrite the launch with the grounded startup velocity.
		if action.current_phase == AbilityAction.Phase.STARTUP:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			velocity.z = move_toward(velocity.z, 0.0, friction * delta)
			velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.1
			move_and_slide()
			return

	if action.current_phase == AbilityAction.Phase.ACTIVE:
		# ACTIVE is manually owned by X; no timer can confirm or land it.
		match _sky_dive_sub_phase:
			1: # TAKEOFF
				velocity.y -= SKY_DIVE_HOVER_GRAVITY * delta
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
				velocity.z = move_toward(velocity.z, 0.0, friction * delta)
				move_and_slide()
				var height_gained: float = global_position.y - _sky_dive_start_y
				if not is_on_floor() and (height_gained >= SKY_DIVE_JUMP_HEIGHT or velocity.y <= 0.5):
					_sky_dive_sub_phase = 2
					velocity = Vector3.ZERO
					_sky_dive_aim_entry_frame = Engine.get_physics_frames()
					_sky_dive_attack_armed = not Input.is_action_pressed("attack")
					if anim_player and anim_player.has_animation("Knight_X_SkyDive"):
						anim_player.seek(anim_player.get_animation("Knight_X_SkyDive").length * 0.3, true)
						anim_player.pause()
					if _dive_vfx:
						_dive_vfx.aim()
			2: # AERIAL AIM: hover until a new, post-entry LMB edge
				velocity = Vector3.ZERO
				move_and_slide()
				if visuals:
					visuals.rotation.y = _camera_yaw
				if not Input.is_action_pressed("attack"):
					_sky_dive_attack_armed = true
				if Engine.get_physics_frames() > _sky_dive_aim_entry_frame and _sky_dive_attack_armed and Input.is_action_just_pressed("attack"):
					_sky_dive_begin_dive()
			3: # DIVE: collision movement, never a position assignment
				var dive_speed: float = action.data.movement_speed if action.data else SKY_DIVE_DIVE_SPEED
				velocity = _sky_dive_direction * dive_speed
				move_and_slide()
				if is_on_floor():
					_sky_dive_end_dive(action)
				else:
					_hold_sky_dive_air_pose()
		return

	if action.current_phase == AbilityAction.Phase.RECOVERY:
		velocity.x = move_toward(velocity.x, 0.0, friction * 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * 2.0 * delta)
		velocity.y = velocity.y - gravity * delta if not is_on_floor() else -0.1
		move_and_slide()
		_update_sky_dive_thrust_alignment()
		# Recovery is measured on the floor, not while falling off an edge.
		if is_on_floor():
			action.update(delta)


func _sky_dive_begin_dive() -> void:
	var aim_basis: Basis = Basis.from_euler(Vector3(_camera_pitch, _camera_yaw, 0.0))
	_sky_dive_direction = -aim_basis.z
	# Preserve yaw/pitch aiming while ensuring even upward aim descends.
	_sky_dive_direction.y = minf(_sky_dive_direction.y, -0.35)
	_sky_dive_direction = _sky_dive_direction.normalized()
	_sky_dive_sub_phase = 3
	_sky_dive_attack_armed = false
	if visuals:
		visuals.rotation.y = _camera_yaw
	if anim_player and anim_player.has_animation("Knight_X_SkyDive"):
		anim_player.speed_scale = 1.0
		anim_player.play("Knight_X_SkyDive")
		anim_player.seek(anim_player.get_animation("Knight_X_SkyDive").length * 0.5, true)
	if _dive_vfx:
		_dive_vfx.dive(_sky_dive_direction)


func _sky_dive_end_dive(action: AbilityAction) -> void:
	if not is_on_floor() or active_ability_action != action or not action.is_active():
		return
	velocity = Vector3(0.0, -0.1, 0.0)
	_sky_dive_sub_phase = 4
	if action.current_phase == AbilityAction.Phase.ACTIVE:
		if _dive_vfx:
			_dive_vfx.impact()
		_execute_ability_effect(action.slot_name, action.data)
		# Advance the existing lifecycle only after physical floor contact.
		action.phase_timer = 0.001
		action.update(0.001)


func _check_shield_charge_hit(fwd: Vector3) -> void:
	var action:AbilityAction=active_ability_action
	if not action or action.current_phase!=AbilityAction.Phase.ACTIVE or action.custom_data.has("ram_remaining"):
		return
	var candidates:Array[Node]=[]
	var space=get_world_3d().direct_space_state
	var query:=_charge_hit_query
	query.transform=Transform3D(Basis.IDENTITY,global_position+Vector3(0,.9,0)+fwd*.8)

	for hit:Dictionary in space.intersect_shape(query,8):
		var target:Node=hit.collider as Node
		if target and not candidates.has(target):candidates.append(target)
	for target:Node in get_tree().get_nodes_in_group("enemies"):
		if not candidates.has(target):candidates.append(target)
	for i in get_slide_collision_count():
		var target:=get_slide_collision(i).get_collider() as Node
		if target and not candidates.has(target):candidates.append(target)
	var nearest:Node3D
	var distance:=INF
	for target:Node in candidates:
		if not target is Node3D or target==self or not target.has_method("take_damage") or not action.can_hit_target(target):continue
		if target is PlayerController and target.is_dead:continue
		var offset:Vector3=target.global_position-global_position;offset.y=0
		var d:=offset.length()
		if d>2.2 or (d>.0001 and fwd.dot(offset/d)<=.15):continue
		if d<distance:
			distance=d;nearest=target
	if nearest:
		action.register_hit(nearest)
		_apply_shield_charge_impact(nearest,fwd)


func _apply_shield_charge_impact(target_node: Node, fwd: Vector3) -> void:
	var action:AbilityAction=active_ability_action
	if not action or action.custom_data.has("ram_remaining"):return
	var evaded:bool=target_node is PlayerController and target_node.is_in_dodge_iframe()
	var dmg:float=action.data.damage
	var hp_before:float=target_node.health_component.current_health if target_node is PlayerController else -1.0
	target_node.call("take_damage",dmg,global_position)
	# Preserve Perfect Dodge's own negation/reward. A missed contact cannot stun.
	if evaded or (target_node is PlayerController and target_node.health_component.current_health>=hp_before):return
	var target_is_player: bool = target_node is PlayerController
	var blocked_and_held: bool = false
	if target_is_player:
		var target_pc: PlayerController = target_node as PlayerController
		blocked_and_held = target_pc.last_hit_was_blocked and not target_pc.is_shield_broken

	if not blocked_and_held:
		if target_node.has_method("trigger_ragdoll") and not target_node.get("is_dead") and target_node.get("combat_state") != CombatState.DEAD:
			var launch_dir: Vector3 = fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
			# Powerful launch impulse: high speed horizontal trajectory with buoyant hang-time and extended floor slide
			var launch_impulse: Vector3 = launch_dir * 11.5 + Vector3.UP * 4.8
			target_node.call("trigger_ragdoll", launch_impulse)

		if target_node.has_method("apply_impact_stun"):
			target_node.call("apply_impact_stun",SHIELD_RAM_STUN)
		if target_node.has_method("apply_knockback"):
			target_node.call("apply_knockback",fwd,action.data.knockback_distance,action.data.knockback_duration)
	if combat:combat.trigger_hit_impact(target_node.global_position,-fwd)
	if combat_feedback:combat_feedback.trigger_hit_feedback(target_node,dmg)
	apply_camera_recoil(1)
	if _charge_vfx:_charge_vfx.impact(fwd,true)
	velocity.x=0.0;velocity.z=0.0
	action.custom_data["ram_remaining"]=.18
	# Hold the impact pose, then enter the existing recovery. Never pass through.
	action.phase_timer=maxf(action.phase_timer,.20)


func _execute_ability_effect(slot_name: String, ability: AbilityData) -> void:
	_orient_attack_direction()
	var fwd: Vector3 = get_facing_direction()

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state if get_world_3d() else null
	if not space_state:
		return

	if ability.is_aoe:
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		var sphere: SphereShape3D = SphereShape3D.new()
		sphere.radius = ability.range
		query.shape = sphere
		query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 0.9, 0.0))
		query.collision_mask = 4
		query.exclude = [get_rid()]
		var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
		for hit in hits:
			var col: Object = hit.get("collider")
			if col and col is Node and col.has_method("take_damage"):
				var target_node: Node = col as Node
				if target_node != self:
					if active_ability_action == null or active_ability_action.can_hit_target(target_node):
						if active_ability_action:
							active_ability_action.register_hit(target_node)
						target_node.call("take_damage", ability.damage, global_position)
	else:
		if combat and combat.has_method("get_valid_target_in_range"):
			var target: Node = combat.get_valid_target_in_range()
			if target and target.has_method("take_damage"):
				if active_ability_action == null or active_ability_action.can_hit_target(target):
					if active_ability_action:
						active_ability_action.register_hit(target)
					target.call("take_damage", ability.damage, global_position)
					if combat.has_method("trigger_hit_impact"):
						combat.trigger_hit_impact(target.global_position, -fwd)

	if ability.id == "shield_bash":
		shield_durability = minf(shield_max_durability, shield_durability + 25.0)
		shield_durability_changed.emit(shield_durability, shield_max_durability)

	if combat and combat.slash_arc_vfx and ability.id != "sky_dive":
		combat.slash_arc_vfx.trigger(fwd, global_position)

	if slot_name == "ultimate":
		if combat_feedback:
			combat_feedback.trigger_ultimate_feedback()
	else:
		if combat_feedback:
			combat_feedback.trigger_skill_feedback(ability.id)


func can_block() -> bool:
	return not is_shield_broken and combat_state != CombatState.DEAD and combat_state != CombatState.ATTACK and combat_state != CombatState.COUNTER and _combo_finisher_recovery_timer <= 0.0 and (active_ability_action == null or not active_ability_action.is_active())


func is_in_combo_window() -> bool:
	if _combo_step >= MAX_COMBO_STEP or _combo_finisher_recovery_timer > 0.0 or combat_state == CombatState.DEAD:
		return false
	if combat_state != CombatState.ATTACK:
		return false
	if not _attack_impact_applied:
		return false
	if not anim_player or not anim_player.is_playing() or not _is_basic_attack_animation(anim_player.current_animation):
		return false
	var pos: float = anim_player.current_animation_position
	return pos >= COMBO_WINDOW_START and pos <= COMBO_WINDOW_END


func is_combo_queued() -> bool:
	return false


func get_combo_buffer() -> int:
	return 0


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
		_play_basic_attack_animation()

	combo_step_changed.emit(_combo_step)


func _try_combat_attack() -> bool:
	if is_control_impaired():
		return false
	if wizard_combat:
		return wizard_combat.start_charge()
	if archer_combat:
		return archer_combat.start_charge()
	if not controls_enabled:
		return false
	if combat_state == CombatState.DEAD:
		return false
	if _combo_finisher_recovery_timer > 0.0:
		return false
	if is_shield_broken or _shield_stun_timer > 0.0:
		return false
	if combat_state == CombatState.DODGE or combat_state == CombatState.COUNTER:
		return false
	if active_ability_action and active_ability_action.is_active():
		return false

	# Task 5.14D: Manual click-to-advance combo
	# If currently attacking:
	if combat_state == CombatState.ATTACK:
		if is_in_combo_window() and _combo_step < MAX_COMBO_STEP:
			_combo_step += 1
			_combo_recovery_timer = 0.0
			_execute_next_combo_attack()
			return true
		# Early clicks during windup or already at max combo step are IGNORED (never buffered)
		return false

	# If in locomotion (IDLE or RUN):
	if combat_state == CombatState.IDLE or combat_state == CombatState.RUN or combat_state == CombatState.BLOCK:
		var success: bool = transition_to(CombatState.ATTACK)
		if success:
			_combo_step = 1
			_combo_recovery_timer = 0.0
		return success

	return false


func _start_block() -> bool:
	if is_ragdoll_active():
		if ragdoll and ragdoll.has_method("can_wake_up_block") and ragdoll.call("can_wake_up_block"):
			if is_shield_broken or combat_state == CombatState.DEAD:
				return false
			# Wake-up block: cancel knockdown and instantly raise shield to prevent follow-up stuns
			ragdoll.call("stop_ragdoll")
			_impact_stun_timer = 0.0
			_knockback_timer = 0.0
			velocity = Vector3.ZERO
			if anim_player and anim_player.has_animation("block_start"):
				anim_player.speed_scale = 1.6
				anim_player.play("block_start", 0.05)
			return transition_to(CombatState.BLOCK)
		return false

	if is_control_impaired():
		return false
	if wizard_combat:
		return wizard_combat.start_block()
	if archer_combat:
		return archer_combat.start_block()
	if not controls_enabled:
		return false
	if is_shield_broken or combat_state == CombatState.DEAD or combat_state == CombatState.COUNTER or _combo_finisher_recovery_timer > 0.0 or (active_ability_action and active_ability_action.is_active()):
		return false
	return transition_to(CombatState.BLOCK)


func _release_block() -> void:
	if combat_state != CombatState.BLOCK:
		return

	var horiz_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	var input_x: float = external_move_direction.x if external_controlled else Input.get_axis("move_left", "move_right")
	var input_z: float = external_move_direction.z if external_controlled else Input.get_axis("move_forward", "move_backward")
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


func take_damage(amount_or_payload: Variant, attacker_pos: Vector3 = NO_ATTACKER_POS, incoming_shield_damage: float = 15.0, spawn_feedback: bool = true) -> void:
	if amount_or_payload is AttackPayload: amount_or_payload.outcome = &"rejected"
	if wizard_combat and wizard_combat.storm.channeling():
		return
	if combat_state == CombatState.DEAD:
		# TEST 16: No damage can be processed after DEAD
		return
	if is_ragdoll_recovering():
		# Completely invulnerable to damage during get-up recovery
		return

	var amount: float = 0.0
	var is_dodgeable: bool = true
	var is_perfect_dodge_eligible: bool = true
	var stamina_reward: float = 25.0
	var attack_payload: Variant = null

	if amount_or_payload is AttackPayload:
		var payload: AttackPayload = amount_or_payload as AttackPayload
		amount = payload.damage
		attacker_pos = payload.attacker_pos
		incoming_shield_damage = payload.incoming_shield_damage
		is_dodgeable = payload.is_dodgeable
		is_perfect_dodge_eligible = payload.is_perfect_dodge_eligible
		stamina_reward = payload.stamina_reward
		attack_payload = payload
	elif amount_or_payload is Dictionary:
		var dict: Dictionary = amount_or_payload as Dictionary
		if dict.has("damage"):
			amount = float(dict["damage"])
		if dict.has("attacker_pos"):
			attacker_pos = dict["attacker_pos"]
		if dict.has("incoming_shield_damage"):
			incoming_shield_damage = float(dict["incoming_shield_damage"])
		if dict.has("is_dodgeable"):
			is_dodgeable = bool(dict["is_dodgeable"])
		elif dict.has("dodgeable"):
			is_dodgeable = bool(dict["dodgeable"])
		if dict.has("is_perfect_dodge_eligible"):
			is_perfect_dodge_eligible = bool(dict["is_perfect_dodge_eligible"])
		if dict.has("stamina_reward"):
			stamina_reward = float(dict["stamina_reward"])
		attack_payload = dict
	elif amount_or_payload is float or amount_or_payload is int:
		amount = float(amount_or_payload)
		attack_payload = AttackPayload.new(amount, attacker_pos, incoming_shield_damage, is_dodgeable, is_perfect_dodge_eligible, stamina_reward)

	# --- DODGE & PERFECT DODGE CHECK ---
	if is_in_dodge_iframe():
		if is_dodgeable:
			if attack_payload is AttackPayload: attack_payload.outcome = &"dodged"
			# Negate damage & knockback entirely!
			_knockback_timer = 0.0
			_knockback_vel = Vector3.ZERO
			if dodge_controller and is_perfect_dodge_eligible:
				dodge_controller.perfect_dodge_stamina_bonus = stamina_reward
				var was_new: bool = dodge_controller.register_perfect_dodge(attack_payload)
				if was_new:
					CombatTimeManager.apply_slow_motion(0.2, 0.3)
					if combat_feedback and combat_feedback.has_method("trigger_perfect_dodge_feedback"):
						combat_feedback.trigger_perfect_dodge_feedback()
			return

	# --- ABILITY FRONT PROTECTION CHECK ---
	if active_ability_action and active_ability_action.has_front_protection() and attacker_pos != NO_ATTACKER_POS:
		if combat and combat.is_attack_inside_block_cone(self, attacker_pos, block_cone_deg):
			_knockback_timer = 0.0
			_knockback_vel = Vector3.ZERO
			if combat:
				var to_attacker: Vector3 = attacker_pos - global_position
				to_attacker.y = 0.0
				var to_attacker_dir: Vector3 = to_attacker.normalized() if to_attacker.length_squared() > 0.0001 else Vector3.FORWARD
				var block_pos: Vector3 = global_position + Vector3(0.0, 0.9, 0.0) + to_attacker_dir * 0.4
				if combat.has_method("trigger_block_impact"):
					combat.trigger_block_impact(block_pos, -to_attacker_dir)
			if combat_feedback and combat_feedback.has_method("trigger_block_feedback"):
				combat_feedback.trigger_block_feedback(attacker_pos)
			return

	var can_block: bool = not attack_payload is AttackPayload or attack_payload.can_be_blocked
	var final_damage: float = amount
	var was_blocked: bool = false
	if can_block and combat_state == CombatState.BLOCK and not is_shield_broken and attacker_pos != NO_ATTACKER_POS:
		if combat and combat.is_attack_inside_block_cone(self, attacker_pos, block_cone_deg):
			was_blocked = true
			final_damage = amount * (1.0 - block_damage_reduction)
			if attack_payload is AttackPayload and attack_payload.blocked_damage_override >= 0:
				final_damage = attack_payload.blocked_damage_override
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
		if hero_profile == "archer":
			trigger_archer_hit_flash()

	last_hit_was_blocked = was_blocked

	if final_damage > 0.0 and archer_combat:
		archer_combat.end_stealth()
	if attack_payload is AttackPayload and health_component and not health_component.ability_invulnerable and not health_component.training_invulnerable:
		attack_payload.outcome = &"blocked" if was_blocked else &"hit"
	var will_die: bool = (health_component and health_component.current_health - final_damage <= 0.0)

	# Apply hit reaction and knockback only if target survives
	var can_react: bool = not attack_payload is AttackPayload or attack_payload.triggers_hit_reaction or was_blocked
	if can_react and not will_die and attacker_pos != NO_ATTACKER_POS and not (hawk_carry and hawk_carry.active()):
		var to_me: Vector3 = global_position - attacker_pos
		to_me.y = 0.0
		var hit_dir: Vector3 = to_me.normalized() if to_me.length_squared() > 0.0001 else (-visuals.global_basis.z if visuals else Vector3.BACK)
		apply_hit_reaction(hit_dir, was_blocked)

	if health_component:
		health_component.take_damage(final_damage)
	elif final_damage > 0.0:
		transition_to(CombatState.DEAD)


func apply_impact_stun(seconds:float) -> bool:
	if is_dead or not controls_enabled or (wizard_combat and wizard_combat.storm.channeling()) or is_ragdoll_recovering():
		return false
	if polymorph and not is_ragdoll_active():
		polymorph.cancel_actions()
	_impact_stun_timer=maxf(_impact_stun_timer,seconds)
	if not is_ragdoll_active() and anim_player and anim_player.has_animation("recoil"):
		anim_player.play("recoil",0.04)
	return true


func apply_knockback(direction: Vector3, distance: float, duration: float) -> void:
	_restore_z_shield_visual(true)
	if wizard_combat and wizard_combat.storm.channeling():
		return
	if combat_state == CombatState.DEAD or is_ragdoll_recovering():
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
	if combat_state == CombatState.DEAD or is_ragdoll_recovering():
		return
	if wizard_combat:
		wizard_combat.interrupt()
	if archer_combat:
		archer_combat.interrupt()
		archer_combat.end_stealth()
	_hit_reaction_count += 1
	# Hit reaction clears queued combo input but cannot bypass finisher recovery.
	reset_combo(false)

	var has_ability_armor: bool = (
		active_ability_action != null
		and active_ability_action.is_active()
		and active_ability_action.data != null
		and active_ability_action.data.id in ["shield_charge", "sky_dive", "whirling_blade", "giant_sword_ultimate"]
	)

	if not is_blocked_hit and hero_profile == "archer":
		trigger_archer_hit_flash()

	if not is_blocked_hit and not has_ability_armor:
		if combat_state == CombatState.ATTACK:
			_attack_impact_applied = false
			if combat and combat.has_method("stop_slash_effect"):
				combat.stop_slash_effect()
			var old_state: CombatState = combat_state
			combat_state = CombatState.IDLE
			if anim_player and anim_player.has_animation("idle"):
				anim_player.speed_scale = 1.0
				anim_player.play("idle", 0.1)
			state_changed.emit(old_state, combat_state)
			_update_locomotion_animations()
		apply_impact_stun(0.16)

	if not has_ability_armor:
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


func _update_camera(_delta: float = 0.0) -> void:
	if not camera_pivot:
		return

	if is_third_person:
		camera_pivot.position = Vector3(0, 1.62, 0)
		var sky_aim: bool = archer_combat != null and archer_combat.sky_aiming
		if sky_aim:
			camera_pivot.position = Basis(Vector3.UP, _camera_yaw) * Vector3(.85, 1.7, 0)
		camera_pivot.rotation.y = _camera_yaw
		camera_pivot.rotation.x = _camera_pitch + _cam_recoil_pitch
		camera_pivot.rotation.z = 0.0
		if spring_arm:
			spring_arm.spring_length = 1.8 if sky_aim else third_person_distance
			spring_arm.rotation.x = 0.0 if sky_aim else deg_to_rad(-12.0)
		if camera:
			camera.rotation = Vector3.ZERO
	else:
		if spring_arm:
			spring_arm.spring_length = 0.0
			spring_arm.rotation = Vector3.ZERO
		if camera:
			camera.position = Vector3.ZERO
			camera.rotation = Vector3.ZERO

		# 1st-person Eye Position and Rotation Tracking
		if hero_profile == "archer" and _skeleton and _head_bone_idx != -1:
			var is_somersault: bool = dodge_controller and dodge_controller.is_dodging
			if is_somersault:
				var head_pose: Transform3D = _skeleton.get_bone_global_pose(_head_bone_idx)
				var head_world: Transform3D = _skeleton.global_transform * head_pose
				var head_rot: Basis = head_world.basis.orthonormalized()
				var eye_pos: Vector3 = head_world.origin + head_rot.z * 0.08 + head_rot.y * 0.06
				var cam_basis: Basis = Basis(-head_rot.x, head_rot.y, -head_rot.z).orthonormalized()
				var final_basis: Basis = (cam_basis * Basis(Vector3.RIGHT, _camera_pitch + _cam_recoil_pitch)).orthonormalized()
				camera_pivot.global_transform = Transform3D(final_basis, eye_pos)
			else:
				var eye_world: Vector3 = global_position + Vector3(0, 1.58, 0) + Basis(Vector3.UP, _camera_yaw) * Vector3(0, 0, -0.04)
				var cam_basis: Basis = (Basis(Vector3.UP, _camera_yaw) * Basis(Vector3.RIGHT, _camera_pitch + _cam_recoil_pitch)).orthonormalized()
				camera_pivot.global_transform = Transform3D(cam_basis, eye_world)
		else:
			camera_pivot.position = Vector3(0, 1.62, 0)
			camera_pivot.rotation.y = _camera_yaw
			camera_pivot.rotation.x = _camera_pitch + _cam_recoil_pitch
			camera_pivot.rotation.z = 0.0


func _update_camera_rotation() -> void:
	_update_camera()


func apply_shield_damage(amount: float) -> void:
	if is_ragdoll_recovering(): return
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
	_impact_stun_timer = 0.0
	_shield_recovery_timer = 0.0
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	_update_low_shield_state()
	shield_restored.emit()


func reset_shield_for_new_round() -> void:
	if hawk_carry: hawk_carry.clear()
	if spectacle:
		spectacle.clear()
	if frost:
		frost.clear()
	if polymorph:
		polymorph.clear()
	var was_broken: bool = (shield_state == ShieldState.BROKEN)
	shield_state = ShieldState.READY
	_shield_stun_timer = 0.0
	_impact_stun_timer = 0.0
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
	_impact_stun_timer = 0.0
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
	if stamina_component:
		stamina_component.reset_stamina()
	if dodge_controller:
		dodge_controller.reset()
	if active_ability_action:
		active_ability_action.cancel()
		active_ability_action = null
	_clear_sky_dive_state()
	if ability_system:
		ability_system.reset_cooldowns()
	CombatTimeManager.reset_time()

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
	_update_camera()
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
	if spectacle:
		spectacle.clear()
	if frost:
		frost.clear()
	if polymorph:
		polymorph.clear()
	if wizard_combat:
		wizard_combat.reset()
	if archer_combat:
		archer_combat.reset()
	if combat_feedback:
		combat_feedback.play_audio_event("death")
	transition_to(CombatState.DEAD)


func _on_animation_finished(anim_name: StringName) -> void:
	if combat_state == CombatState.DEAD:
		# TEST 15: Character remains DEAD and at death location after dead animation completes
		return

	if _is_basic_attack_animation(anim_name):
		_attack_impact_applied = false
		if combat and combat.has_method("stop_slash_effect"):
			combat.stop_slash_effect()

		# Task 5.14D: No automatic combo advancement from buffered input!
		if _combo_step >= MAX_COMBO_STEP:
			_combo_finisher_recovery_timer = COMBO_FINISHER_RECOVERY
			_combo_step = 0
			_combo_recovery_timer = 0.0
			combo_step_changed.emit(0)
		else:
			_combo_recovery_timer = combo_recovery_timeout

		_combo_buffer = 0
		_combo_queued = false

		if combat_state == CombatState.ATTACK:
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
	if hawk_carry and hawk_carry.active(): return
	if is_ragdoll_active():
		return
	var dash_presentation: Node = get_node_or_null("KnightDashPresentation") if hero_profile == "knight" else get_node_or_null("ArcherDashPresentation")
	if dash_presentation and dash_presentation.call("hold_locomotion"):
		return
	if active_ability_action and active_ability_action.is_active() and active_ability_action.data and active_ability_action.data.id in ["shield_charge", "sky_dive", "whirling_blade", "giant_sword_ultimate"]:
		return
	if not anim_player or combat_state == CombatState.DEAD or combat_state == CombatState.ATTACK or combat_state == CombatState.BLOCK or combat_state == CombatState.DODGE:
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
				if hero_profile == "knight": ensure_ragdoll()

	if anim_player:
		if hero_profile == "knight":
			var x_library := anim_player.get_animation_library("").duplicate() as AnimationLibrary
			anim_player.remove_animation_library("")
			anim_player.add_animation_library("", x_library)
			if x_library.has_animation("Knight_X_SkyDive"):
				x_library.remove_animation("Knight_X_SkyDive")
			x_library.add_animation("Knight_X_SkyDive", preload("res://assets/animations/knight_x_sky_dive.tres"))
			for step in range(1, 4):
				var clip := "attack_%d" % step
				var library := anim_player.get_animation_library("")
				if library.has_animation(clip):
					library.remove_animation(clip)
				library.add_animation(clip, load("res://assets/animations/knight_combo_" + clip + ".tres"))
			var c_animation: Animation = preload("res://assets/animations/knight_c_whirling_blade.tres")
			anim_player.get_animation_library("").add_animation("Knight_C_WhirlingBlade", c_animation)
			anim_player.get_animation_library("").add_animation("Knight_V_GiantSword", preload("res://assets/animations/knight_v_giant_sword.tres"))
			for clip in ["start", "charge", "impact", "stop"]:
				var resource: Animation = load("res://assets/animations/knight_z_" + clip + ".tres")
				anim_player.get_animation_library("").add_animation("Knight_Z_" + clip.capitalize(), resource)
			var get_up_anim: Animation = preload("res://assets/animations/knight_get_up.tres")
			anim_player.get_animation_library("").add_animation("get_up", get_up_anim)
		if hero_profile == "knight":
			preload("res://scripts/KnightHandedness.gd").apply(visuals.get_node("CharacterModel"), anim_player)
		elif hero_profile == "archer":
			preload("res://scripts/ArcherLocomotionFix.gd").apply(anim_player)
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

		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.play("idle")


func toggle_camera_perspective() -> void:
	set_third_person(not is_third_person)


func set_third_person(enabled: bool) -> void:
	is_third_person = enabled
	_prev_camera_yaw = _camera_yaw
	if camera_pivot:
		camera_pivot.position = Vector3(0, 1.62, 0)
	if spring_arm:
		spring_arm.spring_length = third_person_distance if is_third_person else 0.0
		spring_arm.rotation.x = deg_to_rad(-12.0) if is_third_person else 0.0
	if camera:
		camera.near = 0.05 if is_third_person else 0.08
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		if not is_third_person:
			camera.position = Vector3.ZERO
	_update_head_visibility()
	_update_camera()


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
	if not captured and wizard_combat:
		wizard_combat.interrupt()
	if not captured and archer_combat:
		archer_combat.interrupt()
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
	_add_key_if_missing("dodge", [KEY_Q])
	_add_key_if_missing("skill_1", [KEY_Z])
	_add_key_if_missing("skill_2", [KEY_X])
	_add_key_if_missing("skill_3", [KEY_C])
	_add_key_if_missing("ultimate", [KEY_V])
	_add_key_if_missing("toggle_perspective", [KEY_B])


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


func is_control_impaired() -> bool:
	return (hawk_carry and hawk_carry.active()) or _impact_stun_timer > 0.0 or (polymorph and polymorph.active()) or (frost and frost.active()) or (ragdoll != null and ragdoll.call("is_active"))


func ensure_ragdoll() -> bool:
	if ragdoll: return true
	if not _skeleton: return false
	ragdoll = preload("res://scripts/KnightRagdoll.gd").new()
	ragdoll.name = "KnightRagdoll"
	add_child(ragdoll)
	ragdoll.setup(self, _skeleton)
	if hero_profile != "knight" and anim_player and not anim_player.has_animation("get_up"):
		var library := anim_player.get_animation_library("").duplicate() as AnimationLibrary
		anim_player.remove_animation_library("")
		anim_player.add_animation_library("", library)
		var clip := preload("res://assets/animations/knight_get_up.tres").duplicate() as Animation
		var skeleton_path := anim_player.get_node(anim_player.root_node).get_path_to(_skeleton)
		for track in range(clip.get_track_count()):
			var bone := String(clip.track_get_path(track).get_subname(0))
			clip.track_set_path(track, NodePath(String(skeleton_path) + ":" + bone))
		library.add_animation("get_up", clip)
	return true


func trigger_ragdoll(impulse: Vector3 = Vector3.ZERO) -> bool:
	if (hawk_carry and hawk_carry.active()) or is_ragdoll_recovering(): return false
	if not is_physics_processing():
		return false
	if ragdoll:
		if ragdoll.has_method("is_cc_grace_active") and ragdoll.call("is_cc_grace_active"):
			return false
		return ragdoll.call("start_ragdoll", impulse)
	return false


func is_ragdoll_active() -> bool:
	return ragdoll != null and ragdoll.call("is_active")


func is_ragdoll_recovering() -> bool:
	return ragdoll != null and ragdoll.call("is_recovering")


# Analytic smoothstep integral: timestep-independent acceleration and braking.
func _charge_distance_at(seconds: float, peak_speed: float) -> float:
	var t := clampf(seconds, 0.0, 0.95)
	if t <= 0.25:
		var u := t / 0.25
		return 2.0*t + (peak_speed-2.0)*0.25*(u*u*u-0.5*u*u*u*u)
	var accelerated := (2.0+peak_speed)*0.125
	if t <= 0.75:
		return accelerated + peak_speed*(t-0.25)
	var u := (t-0.75)/0.20
	return accelerated + peak_speed*0.5 + peak_speed*0.20*(u-u*u*u+0.5*u*u*u*u)


func _is_basic_attack_animation(clip: StringName) -> bool:
	return clip == &"attack" or (hero_profile == "knight" and (clip == &"attack_1" or clip == &"attack_2" or clip == &"attack_3"))


func _play_basic_attack_animation() -> void:
	if hero_profile == "knight":
		# Native blending retains the previous follow-through; no stop/reset to rest.
		anim_player.play("attack_%d" % clampi(_combo_step, 1, MAX_COMBO_STEP), 0.06)
	else:
		anim_player.stop()
		anim_player.play("attack", 0.05)
		anim_player.seek(0.0, true)


func _hold_sky_dive_air_pose() -> void:
	_update_sky_dive_thrust_alignment()
	# Presentation only: never show landing absorption before actual floor contact.
	if anim_player and anim_player.current_animation == "Knight_X_SkyDive":
		var hold_time := anim_player.get_animation("Knight_X_SkyDive").length * 0.78
		if anim_player.current_animation_position >= hold_time and anim_player.is_playing():
			anim_player.seek(hold_time, true)
			anim_player.pause()


func _update_sky_dive_thrust_alignment() -> void:
	if not _sky_dive_model_cached or not anim_player:
		return
	var model: Node3D = visuals.get_node_or_null("CharacterModel") as Node3D
	if not model:
		return
	var frame: float = anim_player.current_animation_position * 60.0
	var weight: float = smoothstep(75.0, 84.0, frame) * (1.0 - smoothstep(120.0, 132.0, frame))
	# The baked arrow points 45 degrees down. Match the actual clamped aim
	# around the torso centre, without touching the actor or its velocity.
	var correction: float = (PI / 4.0 + asin(clampf(_sky_dive_direction.y, -1.0, 1.0))) * weight
	var rotation: Basis = Basis(Vector3.RIGHT, correction)
	var pivot: Vector3 = Vector3(0.0, 1.15, 0.0)
	model.transform = _sky_dive_model_rest * Transform3D(rotation, pivot - rotation * pivot)


func apply_archer_look() -> void:
	_archer_toon_materials.clear()
	_cape_material = null
	_cape_current_drag = Vector3.ZERO
	_cape_current_tuck = 0.0
	if not visuals:
		return
	var hunter: Node = visuals.get_node_or_null("CharacterModel")
	if not hunter:
		return
	if anim_player:
		preload("res://scripts/ArcherLocomotionFix.gd").apply(anim_player)

	# Cape remains original static low-poly mesh without vertex flutter or cloth physics
	var cape_mesh: MeshInstance3D = hunter.find_child("Cape", true, false) as MeshInstance3D

	# Apply toon shader to all other character meshes under CharacterModel
	for mi: MeshInstance3D in hunter.find_children("*", "MeshInstance3D", true, false):
		if mi == cape_mesh or not mi.mesh:
			continue
		if mi.name.begins_with("@") or mi.name == "HunterBowMesh" or mi.name == "HunterBowString":
			continue
		for s in range(mi.mesh.get_surface_count()):
			var orig = mi.get_active_material(s)
			var base_color: Color = Color.WHITE
			if orig is StandardMaterial3D:
				base_color = orig.albedo_color
			var toon_mat := ShaderMaterial.new()
			toon_mat.shader = ARCHER_TOON_SHADER
			toon_mat.resource_name = "Toon_" + mi.name + "_" + str(s)
			toon_mat.set_shader_parameter("albedo_color", base_color)
			toon_mat.set_shader_parameter("shade_floor", 0.32)
			toon_mat.set_shader_parameter("rim_strength", 0.35)
			toon_mat.set_shader_parameter("rim_color", Color(1.0, 1.0, 1.0, 1.0))
			toon_mat.set_shader_parameter("flash_color", Color(0, 0, 0, 0))
			mi.set_surface_override_material(s, toon_mat)
			_archer_toon_materials.append(toon_mat)


func update_cape(delta: float) -> void:
	if not _cape_material:
		return
	if is_dead or combat_state == CombatState.DEAD:
		_cape_material.set_shader_parameter("is_dead", true)
		_cape_material.set_shader_parameter("drag_offset", Vector3.ZERO)
		_cape_material.set_shader_parameter("flutter_amount", 0.0)
		return

	_cape_material.set_shader_parameter("is_dead", false)

	# Check dash / dodge state
	var is_dashing: bool = (
		combat_state == CombatState.DODGE
		or (dodge_controller != null and dodge_controller.is_dodging)
		or (archer_combat != null and archer_combat.dash_active)
	)

	var target_drag := Vector3.ZERO
	var target_tuck: float = 0.0
	var flutter: float = 0.020 # Soothing idle breeze
	var flutter_spd: float = 3.2
	var lerp_speed: float = 6.0

	if is_dashing:
		# Aerodynamic streamline tuck: during high-velocity dodge / somersault / dash,
		# the cape hugs the back and spine closely rather than billowing outward or flaring overhead.
		target_drag = Vector3(0.0, 0.0, -0.015)
		flutter = 0.012
		flutter_spd = 5.0
		lerp_speed = 14.0 # Fast response to prevent sudden pop/flare

		# In backflip somersault, compactly curl cape against spine at flip apex
		if anim_player and anim_player.current_animation == "dash_back":
			var t: float = anim_player.current_animation_position
			target_tuck = clampf(1.0 - absf(t - 0.30) / 0.18, 0.0, 1.0)
	else:
		var hunter: Node3D = visuals.get_node_or_null("CharacterModel") as Node3D if visuals else null
		var local_vel: Vector3 = Vector3.ZERO
		if hunter:
			local_vel = hunter.global_transform.basis.inverse() * velocity

		var speed: float = Vector2(velocity.x, velocity.z).length()
		var speed_ratio: float = clampf(speed / 6.0, 0.0, 1.0)

		# 1. Backwards drag: gentle trailing behind runner
		var forward_ratio: float = clampf(local_vel.z / 6.0, -0.8, 1.0)
		var target_drag_z: float = -forward_ratio * 0.075

		# 2. Aerodynamic lift: soft upward billow
		var target_drag_y: float = speed_ratio * 0.025
		if not is_on_floor() and velocity.y < -2.0:
			# Freefalling lift
			target_drag_y += clampf(-velocity.y / 10.0, 0.0, 1.0) * 0.06
			target_drag_z -= 0.03

		# 3. Lateral strafe / turning sway
		var target_drag_x: float = -clampf(local_vel.x / 6.0, -1.0, 1.0) * 0.045

		target_drag = Vector3(target_drag_x, target_drag_y, target_drag_z)

		if archer_combat and archer_combat.charging:
			flutter = 0.012 # Focused tension while drawing bow
			flutter_spd = 2.4
		elif speed > 0.4:
			flutter = lerpf(0.028, 0.042, clampf(speed / 7.0, 0.0, 1.0))
			flutter_spd = lerpf(4.5, 6.5, clampf(speed / 7.0, 0.0, 1.0))

	_cape_current_drag = _cape_current_drag.lerp(target_drag, minf(1.0, delta * lerp_speed))
	_cape_current_tuck = lerpf(_cape_current_tuck, target_tuck, minf(1.0, delta * 18.0))

	_cape_material.set_shader_parameter("drag_offset", _cape_current_drag)
	_cape_material.set_shader_parameter("flutter_amount", flutter)
	_cape_material.set_shader_parameter("flutter_speed", flutter_spd)
	_cape_material.set_shader_parameter("somersault_tuck", _cape_current_tuck)


func trigger_archer_hit_flash(flash_color: Color = Color(1.0, 0.85, 0.85, 0.8), duration: float = 0.15) -> void:
	if _hit_flash_tween and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_set_archer_flash_color(flash_color)
	_hit_flash_tween.tween_method(_set_archer_flash_color, flash_color, Color(0, 0, 0, 0), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_archer_flash_color(color: Color) -> void:
	if _cape_material:
		_cape_material.set_shader_parameter("flash_color", color)
	for mat in _archer_toon_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("flash_color", color)


func flash_hit() -> void:
	if hero_profile == "archer":
		trigger_archer_hit_flash()
