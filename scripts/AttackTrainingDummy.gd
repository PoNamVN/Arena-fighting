class_name AttackTrainingDummy
extends StaticBody3D

## Configuration
@export var attack_interval: float = 2.0
@export var attack_damage: float = 25.0
@export var attack_range: float = 2.2
@export var attack_windup: float = 0.35
@export var attack_recovery: float = 0.75
@export var auto_attack: bool = true
@export var target: Node3D = null

## Node References
@onready var visuals: Node3D = get_node_or_null("Visuals") as Node3D
var anim_player: AnimationPlayer = null

## Internal State
var _fixed_position: Vector3
var _is_attacking: bool = false
var _cycle_tween: Tween
var _total_attacks_executed: int = 0


func _ready() -> void:
	_fixed_position = global_position

	# Find AnimationPlayer inside Visuals/CharacterModel
	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle")

	# Find player target if not set
	if not target:
		target = _find_player()

	# Delay initial attack by ~1.0 second on spawn
	if auto_attack:
		_start_wait_cycle(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F6:
			trigger_attack_now()
		elif event.keycode == KEY_F7:
			toggle_auto_attack()


func _physics_process(_delta: float) -> void:
	# Enforce strictly static position (never moves, chases, or drifts)
	if global_position != _fixed_position:
		global_position = _fixed_position


func _find_player() -> Node3D:
	if get_parent():
		var p: Node3D = get_parent().get_node_or_null("Player") as Node3D
		if p:
			return p
	var tree_player: Node = get_tree().root.find_child("Player", true, false)
	if tree_player is Node3D:
		return tree_player as Node3D
	return null


func _face_target() -> void:
	if not target:
		target = _find_player()
	if not target:
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.0001:
		var yaw: float = atan2(-to_target.x, -to_target.z)
		if visuals:
			visuals.rotation.y = yaw
		else:
			rotation.y = yaw


func trigger_attack_now() -> bool:
	if _is_attacking:
		return false

	if _cycle_tween and _cycle_tween.is_valid():
		_cycle_tween.kill()

	_execute_attack_sequence()
	return true


func toggle_auto_attack() -> bool:
	auto_attack = !auto_attack
	if auto_attack and not _is_attacking:
		_start_wait_cycle(0.5)
	elif not auto_attack and not _is_attacking:
		if _cycle_tween and _cycle_tween.is_valid():
			_cycle_tween.kill()
	return auto_attack


func _start_wait_cycle(delay: float) -> void:
	if _cycle_tween and _cycle_tween.is_valid():
		_cycle_tween.kill()

	_cycle_tween = create_tween()
	_cycle_tween.tween_interval(delay)
	_cycle_tween.tween_callback(func() -> void:
		if auto_attack and not _is_attacking:
			_execute_attack_sequence()
	)


func _execute_attack_sequence() -> void:
	_is_attacking = true
	_face_target()

	if anim_player and anim_player.has_animation("attack"):
		anim_player.speed_scale = 1.0
		anim_player.stop()
		anim_player.play("attack", 0.05)

	if _cycle_tween and _cycle_tween.is_valid():
		_cycle_tween.kill()

	_cycle_tween = create_tween()
	# 1. Wind-up delay to attack impact apex
	_cycle_tween.tween_interval(attack_windup)
	_cycle_tween.tween_callback(_apply_attack_impact)

	# 2. Recovery time after impact
	_cycle_tween.tween_interval(attack_recovery - attack_windup)
	_cycle_tween.tween_callback(_finish_attack_sequence)


func _apply_attack_impact() -> void:
	_total_attacks_executed += 1
	if not target:
		target = _find_player()
	if not target:
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	var dummy_fwd: Vector3 = -visuals.global_basis.z if visuals else -global_basis.z
	dummy_fwd.y = 0.0
	dummy_fwd = dummy_fwd.normalized()

	var to_target_dir: Vector3 = to_target.normalized() if dist > 0.0001 else dummy_fwd
	var dot: float = dummy_fwd.dot(to_target_dir)

	# Check range (2.2m) and directional cone (within 120° frontal sector)
	if dist <= attack_range and dot >= cos(deg_to_rad(60.0)):
		if target.has_method("take_damage"):
			target.call("take_damage", attack_damage, global_position)


func _finish_attack_sequence() -> void:
	_is_attacking = false
	if anim_player and anim_player.has_animation("idle"):
		anim_player.play("idle", 0.15)

	if auto_attack:
		_start_wait_cycle(attack_interval)


func is_attacking() -> bool:
	return _is_attacking
