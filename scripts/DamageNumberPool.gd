class_name DamageNumberPool
extends Node3D

const DamageNumberScene: PackedScene = preload("res://scenes/DamageNumberVFX.tscn")

@export var pool_size: int = 8

var _instances: Array[DamageNumberVFX] = []
var _next_index: int = 0
var _last_spawned: DamageNumberVFX = null


func _ready() -> void:
	_init_pool()


func _init_pool() -> void:
	if _instances.size() >= pool_size:
		return
	for i in range(pool_size):
		var inst: DamageNumberVFX = DamageNumberScene.instantiate() as DamageNumberVFX
		add_child(inst)
		_instances.append(inst)


func spawn(spawn_pos: Vector3, hp_amount: float, is_blocked: bool, shield_amount: float = 0.0) -> DamageNumberVFX:
	if _instances.is_empty():
		_init_pool()

	# Find first inactive instance
	var target_inst: DamageNumberVFX = null
	for inst in _instances:
		if not inst.is_active:
			target_inst = inst
			break

	# If all active, reuse round-robin oldest
	if not target_inst and not _instances.is_empty():
		target_inst = _instances[_next_index % _instances.size()]
		_next_index += 1

	if target_inst:
		target_inst.trigger(spawn_pos, hp_amount, is_blocked, shield_amount)
		_last_spawned = target_inst
	return target_inst


func get_active_count() -> int:
	var count: int = 0
	for inst in _instances:
		if inst.is_active:
			count += 1
	return count


func get_total_pool_size() -> int:
	return _instances.size()


func get_latest_instance() -> DamageNumberVFX:
	return _last_spawned


func stop_all() -> void:
	for inst in _instances:
		inst.stop()
