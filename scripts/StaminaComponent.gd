class_name StaminaComponent
extends Node

## Signals
signal stamina_changed(current: float, max_stamina: float)
signal stamina_depleted()
signal stamina_filled()

## Configuration
@export var max_stamina: float = 100.0
@export var starting_stamina: float = 100.0
@export var attack_stamina_gain: float = 15.0
@export var perfect_dodge_stamina_bonus: float = 25.0
@export var dodge_stamina_cost: float = 20.0

## State
var current_stamina: float = 0.0


func _ready() -> void:
	current_stamina = clampf(starting_stamina, 0.0, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)


func has_enough_stamina(cost: float) -> bool:
	return current_stamina >= cost


func is_full() -> bool:
	return current_stamina >= max_stamina


func consume_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if not has_enough_stamina(amount):
		return false
	current_stamina = maxf(0.0, current_stamina - amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if current_stamina <= 0.0:
		stamina_depleted.emit()
	return true


func add_stamina(amount: float) -> void:
	if amount <= 0.0:
		return
	var was_full: bool = is_full()
	current_stamina = minf(max_stamina, current_stamina + amount)
	stamina_changed.emit(current_stamina, max_stamina)
	if not was_full and is_full():
		stamina_filled.emit()


func reset_stamina() -> void:
	current_stamina = 0.0
	stamina_changed.emit(current_stamina, max_stamina)
	stamina_depleted.emit()


func get_stamina_ratio() -> float:
	return current_stamina / max_stamina if max_stamina > 0.0 else 0.0
