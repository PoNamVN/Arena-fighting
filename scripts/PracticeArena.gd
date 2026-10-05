class_name PracticeArena
extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://scenes/Player.tscn")
enum RoundState { COUNTDOWN, FIGHT, FINISHED, ENDING }
static var selected_hero: String = "knight"
static var selected_difficulty: int = PracticeOpponent.Difficulty.NORMAL
@export var round_duration: float = 90.0
var round_state: RoundState = RoundState.COUNTDOWN
var countdown_remaining: float = 3.0
var time_remaining: float = 90.0
var player: PlayerController
var opponent: PlayerController
var brain: PracticeOpponent
var warning_label: Label
var timer_label: Label
var center_label: Label
var player_label: Label
var opponent_label: Label
var player_bar: ProgressBar
var opponent_bar: ProgressBar
var abilities_label: Label
var result_buttons: HBoxContainer
var back_button: Button
var _start_banner_time: float = 0.0
const FINISH_WATCHDOG_SECONDS:float=8.0
const FINISH_SETTLE_SECONDS:float=.35
var _finish_started_usec:int=0
var _finish_idle_usec:int=0
var _result_player_hp:float=-1.0
var _result_opponent_hp:float=-1.0


func _ready() -> void:
	CombatTimeManager.reset_time()
	time_remaining = round_duration
	# Spawn exactly two combatants; EmptyArena contains only the environment.
	opponent = _spawn_combatant("Opponent", Vector3(0, 0.1, -8), true)
	player = _spawn_combatant("Player", Vector3(0, 0.1, 4), false)
	brain = PracticeOpponent.new()
	brain.name = "PracticeOpponent"
	brain.actor = opponent
	brain.target = player
	brain.difficulty = clampi(selected_difficulty, 0, 2) as PracticeOpponent.Difficulty
	add_child(brain)
	player.camera.current = true
	player.health_component.died.connect(_schedule_finish)
	opponent.health_component.died.connect(_schedule_finish)
	_build_hud()
	_update_hud()


func _spawn_combatant(actor_name: String, spawn: Vector3, is_ai: bool) -> PlayerController:
	var actor: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	actor.hero_profile = "knight" if is_ai else selected_hero
	actor.name = actor_name
	actor.position = spawn
	actor.external_controlled = is_ai
	actor.controls_enabled = false
	actor.collision_layer = 4 if is_ai else 2
	actor.collision_mask = 3 if is_ai else 5
	actor.get_node("PlayerCombat").target_collision_mask = 2 if is_ai else 4
	actor.get_node("HealthComponent").max_health = 200.0
	actor.get_node("StaminaComponent").starting_stamina = 0.0
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").current = not is_ai
	actor.walk_speed = 4.4 if is_ai else 6.0
	add_child(actor)
	if is_ai:
		actor._camera_yaw = PI
		actor.camera_pivot.rotation.y = PI
		actor.visuals.rotation.y = PI
		# Warm red armor makes the opponent readable while sharing the same rig.
		var tint: StandardMaterial3D = StandardMaterial3D.new()
		tint.albedo_color = Color(0.7, 0.23, 0.18)
		tint.metallic = 0.55
		tint.roughness = 0.6
		_tint_meshes(actor.visuals, tint)
	return actor


func _tint_meshes(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child: Node in node.get_children():
		_tint_meshes(child, material)


func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	if round_state == RoundState.COUNTDOWN:
		countdown_remaining = maxf(0.0, countdown_remaining - real_delta)
		center_label.text = "CHUẨN BỊ\n%d" % ceili(countdown_remaining)
		if countdown_remaining <= 0.0:
			_begin_fight()
	elif round_state == RoundState.FIGHT:
		time_remaining = maxf(0.0, time_remaining - real_delta)
		_start_banner_time = maxf(0.0, _start_banner_time - real_delta)
		center_label.visible = _start_banner_time > 0.0
		if time_remaining <= 0.0:
			_finish_round()
	_update_hud()


func _begin_fight() -> void:
	if round_state != RoundState.COUNTDOWN:
		return
	round_state = RoundState.FIGHT
	player.controls_enabled = true
	opponent.controls_enabled = true
	brain.enabled = true
	center_label.text = "BẮT ĐẦU!"
	_start_banner_time = 0.7
	player._set_mouse_captured(true)


func _schedule_finish() -> void:
	if round_state != RoundState.FIGHT:
		return
	# Freeze the result immediately, while the killing action is still on its impact frame.
	_result_player_hp=player.health_component.current_health
	_result_opponent_hp=opponent.health_component.current_health
	round_state=RoundState.ENDING
	brain.enabled=false
	center_label.hide()
	_finish_started_usec=Time.get_ticks_usec()
	for actor:PlayerController in [player,opponent]:
		actor.external_controlled=true
		actor.external_move_direction=Vector3.ZERO
		actor._combo_buffer=0
		actor.health_component.ability_invulnerable=true
		# Do not disable controls_enabled: that would stop skill physics and Z restoration.
		actor.set_process_unhandled_input(false)
		for node:Node in actor.find_children("*","Node",true,false):
			node.set_process_unhandled_input(false)
	_await_finish_presentation.call_deferred()


func _finishing_presentation_busy() -> bool:
	for actor:PlayerController in [player,opponent]:
		if actor.is_dead:
			continue
		if actor.active_ability_action and actor.active_ability_action.is_active():
			return true
		if actor.combat_state in [PlayerController.CombatState.ATTACK,PlayerController.CombatState.COUNTER]:
			return true
		if actor.giant_sword_ultimate and actor.giant_sword_ultimate._presentation_active:
			return true
		if actor.archer_combat and actor.archer_combat.bait_ultimate.active():
			return true
		if actor.wizard_combat and actor.wizard_combat.storm.active():
			return true
	return false


func _await_finish_presentation() -> void:
	# An idle kill needs no artificial delay; keep the existing immediate result path.
	if not _finishing_presentation_busy():
		_finish_round()
		return
	while is_inside_tree() and round_state==RoundState.ENDING:
		var now:int=Time.get_ticks_usec()
		if now-_finish_started_usec>=int(FINISH_WATCHDOG_SECONDS*1000000):
			push_warning("Round-end presentation timed out; restoring result/camera safely.")
			_finish_round()
			return
		if _finishing_presentation_busy():
			_finish_idle_usec=0
		else:
			if _finish_idle_usec==0:_finish_idle_usec=now
			if now-_finish_idle_usec>=int(FINISH_SETTLE_SECONDS*1000000):
				_finish_round()
				return
		# This clock continues during an ultimate's world pause and ignores slow motion.
		await get_tree().create_timer(.05,true,false,true).timeout


func _finish_round() -> void:
	if round_state not in [RoundState.FIGHT,RoundState.ENDING]:
		return
	round_state = RoundState.FINISHED
	brain.enabled = false
	for actor: PlayerController in [player, opponent]:
		if actor.active_ability_action and actor.active_ability_action.is_active():
			actor.active_ability_action.cancel()
		actor.combat.stop_slash_effect()
		if actor.frost:
			actor.frost.clear()
		if actor.polymorph:
			actor.polymorph.clear()
		if actor.wizard_combat:
			actor.wizard_combat.reset()
		if actor.archer_combat:
			actor.archer_combat.reset()
		actor.controls_enabled = false
		actor.external_move_direction = Vector3.ZERO
		actor.velocity = Vector3.ZERO
	CombatTimeManager.reset_time()
	var hp: float = _result_player_hp if _result_player_hp>=0 else player.health_component.current_health
	var enemy_hp: float = _result_opponent_hp if _result_opponent_hp>=0 else opponent.health_component.current_health
	center_label.text = "HÒA" if is_equal_approx(hp, enemy_hp) else ("BẠN THẮNG!" if hp > enemy_hp else "AI THẮNG")
	center_label.text += "\nHết giờ · so HP còn lại" if time_remaining <= 0.0 else ("\nBạn đã bị hạ gục" if hp <= 0.0 else "\nAI đã bị hạ gục")
	center_label.visible = true
	result_buttons.visible = true
	player._set_mouse_captured(false)


func _update_hud() -> void:
	if not timer_label:
		return
	var seconds: int = ceili(time_remaining)
	timer_label.text = "%s · %02d:%02d" % [brain.difficulty_name(), seconds / 60, seconds % 60]
	player_label.text = "BẠN · HP %d/200  |  Khiên %d  |  Năng lượng %d" % [player.health_component.current_health, player.shield_durability, player.stamina_component.current_stamina]
	if player.archer_combat:
		player_label.text = "CUNG THỦ · HP %d/200 | Cung %d | NL %d" % [player.health_component.current_health, player.shield_durability, player.stamina_component.current_stamina]
	if player.wizard_combat:
		player_label.text = "PHÙ THỦY · HP %d/200 | Khiên phép %d | NL %d" % [player.health_component.current_health, player.shield_durability, player.stamina_component.current_stamina]
	opponent_label.text = "AI · HP %d/200 | Khiên %d | NL %d" % [opponent.health_component.current_health, opponent.shield_durability, opponent.stamina_component.current_stamina]
	warning_label.visible = brain.skill_warning_remaining > 0.0 and round_state == RoundState.FIGHT
	player_bar.value = player.health_component.current_health
	opponent_bar.value = opponent.health_component.current_health
	var slots: Array[String] = ["skill_1", "skill_2", "skill_3", "ultimate"]
	var names: Array[String] = ["Z", "X", "C", "V"]
	var statuses: Array[String] = []
	for i: int in range(4):
		var cooldown: float = player.ability_system.get_cooldown_remaining(slots[i])
		var ability: AbilityData = player.ability_system.get_ability(slots[i])
		if not ability:
			statuses.append("%s: đang phát triển" % names[i])
			continue
		if slots[i] == "ultimate" and player.archer_combat and player.archer_combat.bait_ultimate.active():
			statuses.append("V: Đang săn")
			continue
		var status: String = "%.1fs" % cooldown if cooldown > 0.0 else ("Sẵn sàng" if player.stamina_component.has_enough_stamina(ability.stamina_cost) else "Thiếu năng lượng")
		statuses.append("%s: %s" % [names[i], status])
	abilities_label.text = "   |   ".join(statuses)


func return_to_test() -> void:
	_prepare_scene_exit()
	get_tree().change_scene_to_file("res://scenes/CombatTestArena.tscn")


func replay() -> void:
	_prepare_scene_exit()
	get_tree().reload_current_scene()


func _prepare_scene_exit() -> void:
	round_state=RoundState.FINISHED
	brain.enabled = false
	for actor: PlayerController in [player, opponent]:
		if actor.active_ability_action and actor.active_ability_action.is_active():
			actor.active_ability_action.cancel()
		if actor.frost:
			actor.frost.clear()
		if actor.polymorph:
			actor.polymorph.clear()
		if actor.wizard_combat:
			actor.wizard_combat.reset()
		if actor.archer_combat:
			actor.archer_combat.reset()
	CombatTimeManager.reset_time()


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "PracticeHUD"
	layer.layer = 20
	add_child(layer)
	var root: Control = Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: PanelContainer = PanelContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 16
	top.offset_bottom = 96
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	top.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	player_label = _label(left, "BẠN", 16)
	player_bar = _health_bar(left, Color(0.18, 0.75, 0.56))
	timer_label = _label(row, "ĐẤU TẬP", 25)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	opponent_label = _label(right, "AI", 16)
	opponent_bar = _health_bar(right, Color(0.86, 0.24, 0.20))
	warning_label = _label(root, "AI CHUẨN BỊ XOAY KIẾM · RỜI VÒNG CAM!", 20)
	warning_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	warning_label.offset_top = 108
	warning_label.offset_bottom = 140
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	warning_label.visible = false
	center_label = _label(root, "CHUẨN BỊ\n3", 46)
	center_label.anchor_left = 0.5
	center_label.anchor_right = 0.5
	center_label.anchor_top = 0.5
	center_label.anchor_bottom = 0.5
	center_label.offset_left = -300
	center_label.offset_right = 300
	center_label.offset_top = -140
	center_label.offset_bottom = 10
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_buttons = HBoxContainer.new()
	root.add_child(result_buttons)
	result_buttons.anchor_left = 0.5
	result_buttons.anchor_right = 0.5
	result_buttons.anchor_top = 0.5
	result_buttons.anchor_bottom = 0.5
	result_buttons.offset_left = -218
	result_buttons.offset_right = 218
	result_buttons.offset_top = 50
	result_buttons.offset_bottom = 94
	result_buttons.add_theme_constant_override("separation", 16)
	result_buttons.visible = false
	_button(result_buttons, "Đấu lại", replay)
	_button(result_buttons, "Về Arena Test", return_to_test)
	var bottom: VBoxContainer = VBoxContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 20
	bottom.offset_right = -20
	bottom.offset_top = -130
	bottom.offset_bottom = -12
	abilities_label = _label(bottom, "", 18)
	if not player.archer_combat and not player.wizard_combat:
		var controls: String = "WASD Di chuyển · LMB Đánh · RMB Đỡ · Q Né · Z/X/C/V Skill · B FPS/TPS"
		_label(bottom, controls + "\nEsc để dùng chuột · F1–F4 chỉ dùng trong Arena Test", 16)
	back_button = _button(bottom, "Về Arena Test", return_to_test)
	back_button.custom_minimum_size = Vector2(210, 36)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	parent.add_child(label)
	return label


func _health_bar(parent: Node, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = 200
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(200, 14)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(210, 44)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
