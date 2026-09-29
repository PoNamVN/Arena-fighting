class_name PlayerController
extends CharacterBody3D

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

## Node References
@onready var visuals: Node3D = $Visuals
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var combat: PlayerCombat = get_node_or_null("PlayerCombat") as PlayerCombat

## Internal State
var _camera_yaw: float = 0.0
var _camera_pitch: float = 0.0
var _is_mouse_captured: bool = true


func _ready() -> void:
	_setup_fallback_input_actions()
	_set_mouse_captured(true)
	if camera_pivot:
		_camera_yaw = camera_pivot.rotation.y
		_camera_pitch = camera_pivot.rotation.x


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and _is_mouse_captured:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_camera_yaw -= motion.relative.x * mouse_sensitivity
		_camera_pitch -= motion.relative.y * mouse_sensitivity
		_camera_pitch = clampf(_camera_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		
		if camera_pivot:
			camera_pivot.rotation.y = _camera_yaw
			camera_pivot.rotation.x = _camera_pitch

	# Mouse release / capture & Attack
	if event.is_action_pressed("ui_cancel"):
		_set_mouse_captured(false)
	elif event is InputEventMouseButton and event.is_pressed():
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if not _is_mouse_captured:
				_set_mouse_captured(true)
			elif combat:
				combat.try_attack()
	elif event.is_action_pressed("attack") and _is_mouse_captured:
		if combat:
			combat.try_attack()


func _physics_process(delta: float) -> void:
	# Apply Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Jump
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
		elif velocity.y < 0.0:
			velocity.y = -0.1

	# Calculate Camera-Relative Input
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_z: float = Input.get_axis("move_forward", "move_backward")
	
	var move_dir: Vector3 = Vector3.ZERO
	if camera_pivot:
		# Rotate raw input by camera yaw only to stay flat on XZ plane
		var cam_yaw_basis: Basis = Basis(Vector3.UP, camera_pivot.rotation.y)
		move_dir = cam_yaw_basis * Vector3(input_x, 0.0, input_z)
		move_dir.y = 0.0
		if move_dir.length_squared() > 1.0:
			move_dir = move_dir.normalized()

	# Determine Target Speed
	var is_sprinting: bool = Input.is_action_pressed("sprint")
	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	var target_horizontal: Vector3 = move_dir * target_speed

	# Accelerate or Decelerate Horizontally
	var current_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var lerp_rate: float = acceleration if move_dir.length_squared() > 0.001 else friction
	var new_horizontal: Vector3 = current_horizontal.lerp(target_horizontal, lerp_rate * delta)
	velocity.x = new_horizontal.x
	velocity.z = new_horizontal.z

	# Rotate Character Visuals Towards Movement Direction
	if visuals and move_dir.length_squared() > 0.001:
		var target_angle: float = atan2(-move_dir.x, -move_dir.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_angle, rotation_speed * delta)

	move_and_slide()


func _set_mouse_captured(captured: bool) -> void:
	_is_mouse_captured = captured
	if captured:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_fallback_input_actions() -> void:
	# Ensures actions work even if project.godot input map is not yet reloaded by the editor
	_add_key_if_missing("move_forward", [KEY_W, KEY_UP])
	_add_key_if_missing("move_backward", [KEY_S, KEY_DOWN])
	_add_key_if_missing("move_left", [KEY_A, KEY_LEFT])
	_add_key_if_missing("move_right", [KEY_D, KEY_RIGHT])
	_add_key_if_missing("jump", [KEY_SPACE])
	_add_key_if_missing("sprint", [KEY_SHIFT])
	_add_mouse_button_if_missing("attack", MOUSE_BUTTON_LEFT)


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
