class_name CombatFeedback
extends CanvasLayer

## Audio & Combat Feedback Signals
signal audio_attack_started()
signal audio_attack_hit(target: Node, damage: float, was_blocked: bool)
signal audio_attack_blocked(target: Node)
signal audio_shield_break(position: Vector3)
signal audio_death()
signal target_state_changed(has_target: bool, target: Node)

enum CameraFeedbackType {
	NORMAL_HIT = 0,
	BLOCK = 1,
	SHIELD_BREAK = 2
}

@export var player: PlayerController = null
@onready var screen_emphasis: ColorRect = get_node_or_null("ScreenEmphasis") as ColorRect
@onready var sfx_attack: AudioStreamPlayer = get_node_or_null("Audio/AttackSFX") as AudioStreamPlayer
@onready var sfx_hit: AudioStreamPlayer = get_node_or_null("Audio/HitSFX") as AudioStreamPlayer
@onready var sfx_block: AudioStreamPlayer = get_node_or_null("Audio/BlockSFX") as AudioStreamPlayer
@onready var sfx_break: AudioStreamPlayer = get_node_or_null("Audio/ShieldBreakSFX") as AudioStreamPlayer
@onready var sfx_death: AudioStreamPlayer = get_node_or_null("Audio/DeathSFX") as AudioStreamPlayer

var _has_target: bool = false
var _current_target: Node = null
var _screen_tween: Tween = null


func _ready() -> void:
	layer = 5
	if screen_emphasis:
		screen_emphasis.visible = false
	if not player:
		if get_parent() is PlayerController:
			player = get_parent() as PlayerController
		else:
			var tree_player: Node = get_tree().root.find_child("Player", true, false)
			if tree_player is PlayerController:
				player = tree_player as PlayerController


func _process(_delta: float) -> void:
	update_target_detection()


func update_target_detection() -> void:
	if not player or not player.combat:
		if _has_target:
			_set_target_state(false, null)
		return

	if player.combat_state == PlayerController.CombatState.DEAD:
		if _has_target:
			_set_target_state(false, null)
		return

	var target: Node = player.combat.get_valid_target_in_range()
	var has_valid: bool = (target != null)
	if has_valid != _has_target or target != _current_target:
		_set_target_state(has_valid, target)


func _set_target_state(new_has_target: bool, target: Node) -> void:
	_has_target = new_has_target
	_current_target = target
	target_state_changed.emit(_has_target, _current_target)


var has_target: bool:
	get:
		return _has_target


var current_target: Node:
	get:
		return _current_target



func trigger_hit_feedback(target: Node, damage: float) -> void:
	play_audio_event("attack_hit")
	audio_attack_hit.emit(target, damage, false)


func trigger_block_feedback(target_or_pos: Variant = null) -> void:
	play_audio_event("attack_blocked")
	var target_node: Node = target_or_pos as Node if target_or_pos is Node else null
	audio_attack_blocked.emit(target_node)


func trigger_shield_break_feedback(pos: Vector3 = Vector3.ZERO) -> void:
	play_audio_event("shield_break")
	audio_shield_break.emit(pos)
	trigger_screen_emphasis()


func trigger_screen_emphasis() -> void:
	if not screen_emphasis:
		return
	if _screen_tween and _screen_tween.is_valid():
		_screen_tween.kill()

	screen_emphasis.visible = true
	screen_emphasis.modulate.a = 0.20
	_screen_tween = create_tween()
	_screen_tween.tween_property(screen_emphasis, "modulate:a", 0.0, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_callback(func() -> void:
		screen_emphasis.visible = false
	)


func play_audio_event(event_name: String) -> void:
	match event_name:
		"attack_started":
			audio_attack_started.emit()
			if sfx_attack and sfx_attack.stream:
				sfx_attack.play()
		"attack_hit":
			if sfx_hit and sfx_hit.stream:
				sfx_hit.play()
		"attack_blocked":
			if sfx_block and sfx_block.stream:
				sfx_block.play()
		"shield_break":
			if sfx_break and sfx_break.stream:
				sfx_break.play()
		"death":
			audio_death.emit()
			if sfx_death and sfx_death.stream:
				sfx_death.play()
		"dodge":
			audio_dodge.emit()
		"perfect_dodge":
			audio_perfect_dodge.emit()
		"skill_used":
			audio_skill_used.emit("")
		"ultimate_used":
			audio_ultimate_used.emit()


signal audio_dodge()
signal audio_perfect_dodge()
signal audio_skill_used(skill_id: String)
signal audio_ultimate_used()


func trigger_dodge_feedback() -> void:
	play_audio_event("dodge")


func trigger_perfect_dodge_feedback() -> void:
	play_audio_event("perfect_dodge")
	if not screen_emphasis:
		return
	if _screen_tween and _screen_tween.is_valid():
		_screen_tween.kill()

	screen_emphasis.visible = true
	# Golden cyan flash for perfect dodge
	screen_emphasis.color = Color(0.2, 0.9, 1.0, 1.0)
	screen_emphasis.modulate.a = 0.35
	_screen_tween = create_tween()
	_screen_tween.tween_property(screen_emphasis, "modulate:a", 0.0, 0.28)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_screen_tween.tween_callback(func() -> void:
		if screen_emphasis:
			screen_emphasis.visible = false
			screen_emphasis.color = Color(1.0, 1.0, 1.0, 1.0)
	)


func trigger_skill_feedback(skill_id: String) -> void:
	play_audio_event("skill_used")
	audio_skill_used.emit(skill_id)


func trigger_ultimate_feedback() -> void:
	play_audio_event("ultimate_used")
	audio_ultimate_used.emit()
	if screen_emphasis:
		if _screen_tween and _screen_tween.is_valid():
			_screen_tween.kill()
		screen_emphasis.visible = true
		screen_emphasis.color = Color(1.0, 0.85, 0.2, 1.0)
		screen_emphasis.modulate.a = 0.45
		_screen_tween = create_tween()
		_screen_tween.tween_property(screen_emphasis, "modulate:a", 0.0, 0.40)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_screen_tween.tween_callback(func() -> void:
			if screen_emphasis:
				screen_emphasis.visible = false
				screen_emphasis.color = Color(1.0, 1.0, 1.0, 1.0)
		)
