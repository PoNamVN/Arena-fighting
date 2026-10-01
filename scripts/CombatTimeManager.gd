class_name CombatTimeManager
extends Node

## Singleton / Global Reference
static var instance: CombatTimeManager = null

## Signals
signal slow_motion_started(scale: float, duration: float)
signal slow_motion_ended()

## Configuration
@export var default_time_scale: float = 1.0
@export var perfect_dodge_time_scale: float = 0.2
@export var perfect_dodge_duration: float = 0.3 # Real wall-clock seconds

## Internal State
var _is_dilated: bool = false
var _restore_timer: SceneTreeTimer = null


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	restore_time_scale()
	if instance == self:
		instance = null


func _ready() -> void:
	Engine.time_scale = default_time_scale


func trigger_slow_motion(target_scale: float = 0.2, real_duration: float = 0.3) -> void:
	# Clamp scale to prevent negative or zero division
	var safe_scale: float = clampf(target_scale, 0.05, 1.0)
	var safe_duration: float = maxf(0.01, real_duration)

	Engine.time_scale = safe_scale
	_is_dilated = true
	slow_motion_started.emit(safe_scale, safe_duration)

	# In Godot 4: create_timer(time_sec, process_always, process_in_physics, ignore_time_scale)
	# Setting ignore_time_scale = true guarantees timer runs in real wall-clock time
	var tree: SceneTree = get_tree()
	if tree:
		_restore_timer = tree.create_timer(safe_duration, true, false, true)
		_restore_timer.timeout.connect(_on_timer_timeout)


func restore_time_scale() -> void:
	if Engine.time_scale != default_time_scale or _is_dilated:
		Engine.time_scale = default_time_scale
		_is_dilated = false
		slow_motion_ended.emit()


func is_time_dilated() -> bool:
	return _is_dilated


func _on_timer_timeout() -> void:
	restore_time_scale()


## Static Helper Methods
static func apply_slow_motion(target_scale: float = 0.2, real_duration: float = 0.3) -> void:
	if instance and is_instance_valid(instance):
		instance.trigger_slow_motion(target_scale, real_duration)
	else:
		# Fallback if no node instance is active in the tree
		Engine.time_scale = clampf(target_scale, 0.05, 1.0)


static func reset_time() -> void:
	if instance and is_instance_valid(instance):
		instance.restore_time_scale()
	else:
		Engine.time_scale = 1.0
