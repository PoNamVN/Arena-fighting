class_name DodgeController
extends Node

## Enums
enum Direction {
	FORWARD,
	BACKWARD,
	LEFT,
	RIGHT
}

## Signals
signal dodge_started(direction: Direction, world_direction: Vector3)
signal dodge_completed()
signal iframe_entered()
signal iframe_exited()
signal perfect_dodge_triggered()

## Configuration
@export var stamina_component: StaminaComponent
@export var stamina_cost: float = 0.0
@export var cooldown: float = 1.0
@export var dodge_duration: float = 0.25
@export var dodge_distance: float = 4.5
@export var iframe_start: float = 0.05
@export var iframe_end: float = 0.20
@export var perfect_dodge_stamina_bonus: float = 25.0
@export var counter_window_duration: float = 1.2

## State
var is_dodging: bool = false
var current_direction: Direction = Direction.FORWARD
var world_direction: Vector3 = Vector3.FORWARD
var counter_window_active: bool = false
var _timer: float = 0.0
var _cooldown_timer: float = 0.0
var _counter_timer: float = 0.0
var _in_iframe: bool = false


func _process(delta: float) -> void:
	if not is_inside_tree():
		_physics_process(delta)


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	if counter_window_active:
		_counter_timer -= delta
		if _counter_timer <= 0.0:
			counter_window_active = false

	if not is_dodging:
		return

	_timer += delta

	# Manage partial i-frame window
	var should_be_in_iframe: bool = _timer >= iframe_start and _timer <= iframe_end
	if should_be_in_iframe and not _in_iframe:
		_in_iframe = true
		iframe_entered.emit()
	elif not should_be_in_iframe and _in_iframe:
		_in_iframe = false
		iframe_exited.emit()

	if _timer >= dodge_duration - 0.001:
		_complete_dodge()


func can_dodge() -> bool:
	if is_dodging:
		return false
	if _cooldown_timer > 0.0:
		return false
	if stamina_cost > 0.0 and stamina_component and not stamina_component.has_enough_stamina(stamina_cost):
		return false
	return true


func is_in_iframe() -> bool:
	return is_dodging and _in_iframe


func is_in_dodge_iframe() -> bool:
	return is_in_iframe()


func get_dodge_velocity() -> Vector3:
	if not is_dodging or dodge_duration <= 0.0:
		return Vector3.ZERO
	return world_direction * (dodge_distance / dodge_duration)


func determine_dodge_direction(input_dir: Vector2) -> Direction:
	# Default when no directional input is held is FORWARD
	if input_dir.length_squared() < 0.01:
		return Direction.FORWARD

	# input_dir: x = lateral (positive right, negative left), y = longitudinal (positive forward, negative backward)
	if absf(input_dir.y) >= absf(input_dir.x):
		return Direction.FORWARD if input_dir.y > 0.0 else Direction.BACKWARD
	else:
		return Direction.RIGHT if input_dir.x > 0.0 else Direction.LEFT


func start_dodge(dir: Direction = Direction.FORWARD, p_world_direction: Vector3 = Vector3.FORWARD) -> bool:
	if not can_dodge():
		return false

	if stamina_cost > 0.0 and stamina_component:
		stamina_component.consume_stamina(stamina_cost)

	is_dodging = true
	current_direction = dir
	world_direction = p_world_direction.normalized() if p_world_direction.length_squared() > 0.0001 else Vector3.FORWARD
	world_direction.y = 0.0
	world_direction = world_direction.normalized()
	_timer = 0.0
	_in_iframe = false
	_cooldown_timer = cooldown

	dodge_started.emit(current_direction, world_direction)
	return true


func trigger_perfect_dodge() -> void:
	if stamina_component:
		stamina_component.add_stamina(perfect_dodge_stamina_bonus)
	counter_window_active = true
	_counter_timer = counter_window_duration
	perfect_dodge_triggered.emit()


func _complete_dodge() -> void:
	is_dodging = false
	if _in_iframe:
		_in_iframe = false
		iframe_exited.emit()
	dodge_completed.emit()


func cancel_dodge() -> void:
	if is_dodging:
		_complete_dodge()


func reset() -> void:
	is_dodging = false
	_in_iframe = false
	_timer = 0.0
	_cooldown_timer = 0.0
	counter_window_active = false
	_counter_timer = 0.0
