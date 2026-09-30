class_name DamageNumberVFX
extends Node3D

## Configuration
@export var float_distance: float = 0.50
@export var lifetime: float = 0.65

## Node References
@onready var hp_label: Label3D = $HPLabel
@onready var shield_label: Label3D = $ShieldLabel

## Internal State
var is_active: bool = false
var last_hp_value: float = 0.0
var last_shield_value: float = 0.0
var last_is_blocked: bool = false
var last_spawn_pos: Vector3 = Vector3.ZERO
var _tween: Tween = null

signal completed(instance: Node)


func _ready() -> void:
	visible = false
	if not hp_label:
		hp_label = get_node_or_null("HPLabel") as Label3D
	if not shield_label:
		shield_label = get_node_or_null("ShieldLabel") as Label3D


func trigger(spawn_pos: Vector3, hp_amount: float, is_blocked: bool, shield_amount: float = 0.0) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	last_hp_value = hp_amount
	last_shield_value = shield_amount
	last_is_blocked = is_blocked
	last_spawn_pos = spawn_pos
	is_active = true

	# Set 3D position
	global_position = spawn_pos + Vector3(0.0, 0.25, 0.0)
	scale = Vector3(1.25, 1.25, 1.25)
	visible = true

	# Configure HP Label
	if hp_label:
		if is_equal_approx(hp_amount, roundf(hp_amount)):
			hp_label.text = "%d" % roundi(hp_amount)
		else:
			hp_label.text = "%.2f" % hp_amount

		if is_blocked:
			# Light blue-cyan for blocked damage (3.75)
			hp_label.modulate = Color(0.45, 0.85, 1.0, 1.0)
		else:
			# Bright gold-yellow for confirmed normal hit (25)
			hp_label.modulate = Color(1.0, 0.90, 0.20, 1.0)

	# Configure Shield Label
	if shield_label:
		if shield_amount > 0.0:
			shield_label.text = "Shield -%d" % roundi(shield_amount)
			shield_label.modulate = Color(0.35, 0.70, 1.0, 1.0)
			shield_label.visible = true
		else:
			shield_label.visible = false

	# Float upward and fade animation (~0.65s total)
	_tween = create_tween()
	var target_y: float = global_position.y + float_distance
	_tween.tween_property(self, "global_position:y", target_y, lifetime)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "scale", Vector3.ONE, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fade out over the final 0.25s of lifetime
	_tween.parallel().tween_property(hp_label, "modulate:a", 0.0, 0.25)\
		.set_delay(lifetime - 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if shield_label and shield_amount > 0.0:
		_tween.parallel().tween_property(shield_label, "modulate:a", 0.0, 0.25)\
			.set_delay(lifetime - 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.tween_callback(_on_fade_complete)


func _on_fade_complete() -> void:
	visible = false
	is_active = false
	completed.emit(self)


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	is_active = false
