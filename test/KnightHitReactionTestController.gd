extends Node3D

## Test Controller for Knight Hit Reaction & Ragdoll Prototype (Phase 2 & Phase 3)
## Provides interactive controls and API for testing hit reaction, ragdoll start/stop, impulses, and recovery.

const KnightRagdollScript = preload("res://scripts/KnightRagdoll.gd")

@onready var player: PlayerController = $Player as PlayerController
@onready var dummy: TrainingDummy = get_node_or_null("TrainingDummy") as TrainingDummy
@onready var attack_dummy: AttackTrainingDummy = get_node_or_null("AttackTrainingDummy") as AttackTrainingDummy

var ragdoll: Node = null
var initial_player_pos: Vector3 = Vector3.ZERO
var _hud_label: Label = null


func _ready() -> void:
	if player:
		initial_player_pos = player.global_position
		ragdoll = player.get("ragdoll")
		if not ragdoll:
			ragdoll = KnightRagdollScript.new()
			ragdoll.name = "KnightRagdoll"
			player.add_child(ragdoll)
			var skeleton: Skeleton3D = player.get_node_or_null("Visuals/CharacterModel/Gladiator_Armature/Skeleton3D") as Skeleton3D
			if skeleton:
				ragdoll.call("setup", player, skeleton)

	_create_debug_hud()


func _create_debug_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugHUD"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(360, 260)
	canvas.add_child(panel)

	_hud_label = Label.new()
	_hud_label.text = "Initializing HUD..."
	panel.add_child(_hud_label)


func _process(_delta: float) -> void:
	if not _hud_label:
		return

	var r_state_str: String = "N/A"
	var r_active: bool = false
	var grace_active: bool = false
	var pelvis_y: float = 0.0

	if ragdoll:
		r_active = ragdoll.call("is_active")
		grace_active = ragdoll.call("is_cc_grace_active")
		pelvis_y = ragdoll.call("get_pelvis_global_position").y
		match ragdoll.call("get_state"):
			0: r_state_str = "INACTIVE"
			1: r_state_str = "LAUNCHED"
			2: r_state_str = "SETTLING"
			3: r_state_str = "RECOVERING"

	var c_state_str: String = "UNKNOWN"
	var hp: float = 0.0
	var shield: float = 0.0
	var impaired: bool = false
	if player:
		hp = player.health_component.current_health if player.health_component else 0.0
		shield = player.shield_durability
		impaired = player.is_control_impaired()
		match player.combat_state:
			0: c_state_str = "IDLE"
			1: c_state_str = "RUN"
			2: c_state_str = "ATTACK"
			3: c_state_str = "BLOCK"
			4: c_state_str = "DEAD"
			5: c_state_str = "DODGE"
			6: c_state_str = "COUNTER"

	var text: String = ""
	text += "=== KNIGHT RAGDOLL TEST BED ===\n"
	text += "[1] Light Hit      [2] Heavy Z Launch\n"
	text += "[3] Block Recoil   [4] Shield Break\n"
	text += "[5] Toggle Ragdoll [6] Stand Up\n"
	text += "[B] Wake-up Block  [R] Reset Arena\n"
	text += "-------------------------------\n"
	text += "Combat State:    %s\n" % c_state_str
	text += "Ragdoll State:   %s (Active: %s)\n" % [r_state_str, r_active]
	text += "Pelvis Y:        %.3f m\n" % pelvis_y
	text += "Controls Impaired: %s\n" % impaired
	text += "CC Grace:        %s\n" % ("ACTIVE" if grace_active else "OFF")
	text += "Health:          %.1f HP\n" % hp
	text += "Shield:          %.1f pts (Broken: %s)\n" % [shield, player.is_shield_broken if player else false]
	text += "FPS:             %d\n" % Engine.get_frames_per_second()
	_hud_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	match event.keycode:
		KEY_1:
			trigger_light_hit()
		KEY_2:
			trigger_heavy_hit()
		KEY_3:
			trigger_block()
		KEY_4:
			trigger_shield_break()
		KEY_5:
			toggle_ragdoll()
		KEY_6:
			trigger_recovery()
		KEY_B:
			trigger_wake_up_block()
		KEY_R:
			reset_arena()


func trigger_light_hit() -> void:
	if not player:
		return
	print("[TEST] Triggering light hit on player...")
	player.apply_hit_reaction(Vector3.BACK, false)


func trigger_heavy_hit() -> void:
	if not player:
		return
	print("[TEST] Triggering heavy Z launch on player...")
	player.trigger_ragdoll(Vector3(0, 6.0, 8.5))


func trigger_wake_up_block() -> void:
	if not player:
		return
	print("[TEST] Triggering Wake-up Block on player...")
	player._start_block()


func trigger_block() -> void:
	if not player:
		return
	print("[TEST] Triggering block hit on player...")
	player.apply_hit_reaction(Vector3.BACK, true)


func trigger_shield_break() -> void:
	if not player:
		return
	print("[TEST] Triggering shield break on player...")
	player.break_shield()


func toggle_ragdoll() -> void:
	if not ragdoll:
		return
	if ragdoll.call("is_active"):
		print("[TEST] Stopping ragdoll...")
		ragdoll.call("stop_ragdoll")
	else:
		print("[TEST] Starting ragdoll with backward impulse...")
		ragdoll.call("start_ragdoll", Vector3(0, 3.0, 5.0))


func trigger_recovery() -> void:
	if not ragdoll:
		return
	print("[TEST] Triggering recovery / stand-up...")
	ragdoll.call("start_recovery")


func reset_arena() -> void:
	if not player:
		return
	print("[TEST] Resetting arena and player...")
	if ragdoll and ragdoll.call("is_active"):
		ragdoll.call("stop_ragdoll")
	player.global_position = initial_player_pos
	player.velocity = Vector3.ZERO
	player.health_component.reset_health()
	player.reset_shield_durability()
	player.transition_to(PlayerController.CombatState.IDLE)
