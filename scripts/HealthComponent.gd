class_name HealthComponent
extends Node

## Signals
signal health_changed(new_health: float, max_health: float)
signal damaged(amount: float)
signal died()

## Configuration
@export var max_health: float = 100.0

## State
var current_health: float = 100.0
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	_is_dead = current_health <= 0.0


func take_damage(amount: float) -> void:
	# Ignore non-positive damage (prevents healing or corruption)
	if amount <= 0.0:
		return
	
	# Ignore damage if already defeated
	if _is_dead:
		return
	
	current_health = clampf(current_health - amount, 0.0, max_health)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0 and not _is_dead:
		_is_dead = true
		died.emit()


func is_dead() -> bool:
	return _is_dead


func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
