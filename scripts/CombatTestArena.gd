class_name CombatTestArena
extends Node3D

@export var respawn_delay: float = 1.5

@onready var player: PlayerController = get_node_or_null("Player") as PlayerController
@onready var attack_dummy: AttackTrainingDummy = get_node_or_null("AttackTrainingDummy") as AttackTrainingDummy
@onready var training_dummy: TrainingDummy = get_node_or_null("TrainingDummy") as TrainingDummy
@onready var hud: CanvasLayer = get_node_or_null("CombatTestHUD") as CanvasLayer

var _player_spawn_pos: Vector3 = Vector3(0, 0.1, 0)
var _player_spawn_yaw: float = 0.0
var _respawn_tween: Tween
var _respawn_count: int = 0

var no_cooldowns: bool = false
var debug_label: Label
var difficulty_select: OptionButton
var hero_select: OptionButton
var practice_button: Button

signal player_respawned()


func _enter_tree() -> void:
	var actor: PlayerController = get_node_or_null("Player") as PlayerController
	if actor:
		actor.hero_profile = PracticeArena.selected_hero


func _ready() -> void:
	if not player:
		player = find_child("Player", true, false) as PlayerController
		
	if player:
		_player_spawn_pos = player.global_position
		_player_spawn_yaw = player._camera_yaw
		player.shield_recovery_mode = PlayerController.ShieldRecoveryMode.TEST_ARENA
		if player.stamina_component:
			player.stamina_component.current_stamina = 100.0
		if player.health_component:
			player.health_component.died.connect(_on_player_died)
			
	if not hud:
		hud = find_child("CombatTestHUD", true, false) as CanvasLayer

	_setup_training_tools()


func _on_player_died() -> void:
	if _respawn_tween and _respawn_tween.is_valid():
		_respawn_tween.kill()
		
	_respawn_tween = create_tween()
	_respawn_tween.tween_interval(respawn_delay)
	_respawn_tween.tween_callback(respawn_player)


func respawn_player() -> void:
	if not player:
		return
		
	_respawn_count += 1
	player.respawn(_player_spawn_pos, _player_spawn_yaw)
	if player.stamina_component:
		player.stamina_component.current_stamina = 100.0
	
	if hud:
		hud.on_player_respawned()
		
	player_respawned.emit()


func _setup_training_tools() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "TrainingTools"
	layer.layer = 20
	add_child(layer)
	var background: PanelContainer = PanelContainer.new()
	layer.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	background.offset_left = -394
	background.offset_top = 20
	background.offset_right = -20
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.16, 0.21, 0.94)
	style.set_content_margin_all(12.0)
	style.set_corner_radius_all(6)
	background.add_theme_stylebox_override("panel", style)
	var panel: VBoxContainer = VBoxContainer.new()
	background.add_child(panel)
	practice_button = Button.new()
	practice_button.text = "ĐẤU TẬP · Bạn vs AI"
	practice_button.custom_minimum_size = Vector2(350, 48)
	panel.add_child(practice_button)
	practice_button.pressed.connect(enter_practice)
	difficulty_select = OptionButton.new()
	difficulty_select.name = "DifficultySelect"
	difficulty_select.add_item("Dễ · đánh đơn, phản ứng chậm")
	difficulty_select.add_item("Thường · combo, né, chiêu C")
	difficulty_select.add_item("Khó · combo 3 đòn, áp lực cao")
	difficulty_select.select(clampi(PracticeArena.selected_difficulty, 0, 2))
	difficulty_select.custom_minimum_size = Vector2(350, 36)
	panel.add_child(difficulty_select)
	hero_select = OptionButton.new()
	hero_select.name = "HeroSelect"
	hero_select.add_item("Knight · Kiếm và khiên")
	hero_select.add_item("Cung thủ rừng · Bản bắn cơ bản")
	hero_select.add_item("Phù thủy nguyên tố · Cầu lửa và khiên phép")
	hero_select.select(["knight", "archer", "wizard"].find(PracticeArena.selected_hero))
	hero_select.custom_minimum_size = Vector2(350, 36)
	panel.add_child(hero_select)
	hero_select.item_selected.connect(_select_hero)
	debug_label = Label.new()
	debug_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(debug_label)
	_update_training_label()
	if player and player.ability_system:
		player.ability_system.ability_cast_started.connect(_on_training_cast)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not player:
		return
	match event.keycode:
		KEY_F1:
			player.stamina_component.training_infinite = not player.stamina_component.training_infinite
			if player.stamina_component.training_infinite:
				player.stamina_component.add_stamina(player.stamina_component.max_stamina)
		KEY_F2:
			no_cooldowns = not no_cooldowns
			if no_cooldowns:
				player.ability_system.reset_cooldowns()
		KEY_F3:
			player.health_component.training_invulnerable = not player.health_component.training_invulnerable
		KEY_F4:
			get_tree().reload_current_scene.call_deferred()
		_:
			return
	_update_training_label()
	get_viewport().set_input_as_handled()


func _on_training_cast(_slot: String, _ability: AbilityData) -> void:
	if no_cooldowns:
		player.ability_system.reset_cooldowns()


func _update_training_label() -> void:
	if not player or not debug_label:
		return
	debug_label.text = "ARENA TEST · Esc để dùng chuột\nF1 Năng lượng: %s\nF2 Bỏ hồi chiêu: %s\nF3 Bất tử: %s\nF4 Làm mới phòng" % [
		"BẬT" if player.stamina_component.training_infinite else "TẮT",
		"BẬT" if no_cooldowns else "TẮT",
		"BẬT" if player.health_component.training_invulnerable else "TẮT"]


func enter_practice() -> void:
	PracticeArena.selected_difficulty = difficulty_select.selected
	if player.active_ability_action and player.active_ability_action.is_active():
		player.active_ability_action.cancel()
	CombatTimeManager.reset_time()
	get_tree().change_scene_to_file("res://scenes/PracticeArena.tscn")


func _select_hero(index: int) -> void:
	PracticeArena.selected_hero = ["knight", "archer", "wizard"][index]
	PracticeArena.selected_difficulty = difficulty_select.selected
	if player.wizard_combat:
		player.wizard_combat.reset()
	if player.archer_combat:
		player.archer_combat.reset()
	if player.active_ability_action and player.active_ability_action.is_active():
		player.active_ability_action.cancel()
	CombatTimeManager.reset_time()
	get_tree().reload_current_scene.call_deferred()
