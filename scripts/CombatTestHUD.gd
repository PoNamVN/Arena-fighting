class_name CombatTestHUD
extends CanvasLayer

@export var player: PlayerController = null

@onready var hp_bar: ProgressBar = get_node_or_null("RootControl/StatsPanel/VBoxContainer/HPContainer/HPProgressBar") as ProgressBar
@onready var hp_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/HPContainer/HPLabel") as Label
@onready var shield_bar: ProgressBar = get_node_or_null("RootControl/StatsPanel/VBoxContainer/ShieldContainer/ShieldProgressBar") as ProgressBar
@onready var shield_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/ShieldContainer/ShieldLabel") as Label
@onready var status_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/StatusContainer/StatusLabel") as Label
@onready var break_banner: Label = get_node_or_null("RootControl/BreakBanner") as Label
@onready var respawn_banner: Label = get_node_or_null("RootControl/RespawnBanner") as Label

var _banner_tween: Tween
var _respawn_tween: Tween


func _ready() -> void:
	if break_banner:
		break_banner.visible = false
	if respawn_banner:
		respawn_banner.visible = false
	
	if not player:
		player = _find_player()
		
	if player:
		_setup_player_connections(player)


func _find_player() -> PlayerController:
	if get_parent():
		var p: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
		if p:
			return p
	var tree_player: Node = get_tree().root.find_child("Player", true, false)
	if tree_player is PlayerController:
		return tree_player as PlayerController
	return null


func _setup_player_connections(p: PlayerController) -> void:
	if not p.shield_durability_changed.is_connected(_on_shield_durability_changed):
		p.shield_durability_changed.connect(_on_shield_durability_changed)
	if not p.shield_broken.is_connected(_on_shield_broken):
		p.shield_broken.connect(_on_shield_broken)
	if not p.shield_restored.is_connected(_on_shield_restored):
		p.shield_restored.connect(_on_shield_restored)
	
	if p.health_component:
		if not p.health_component.health_changed.is_connected(_on_health_changed):
			p.health_component.health_changed.connect(_on_health_changed)
		if not p.health_component.died.is_connected(_on_player_died):
			p.health_component.died.connect(_on_player_died)
			
	# Initial UI refresh
	if p.health_component:
		_on_health_changed(p.health_component.current_health, p.health_component.max_health)
	_on_shield_durability_changed(p.shield_durability, p.shield_max_durability)


func _process(_delta: float) -> void:
	if not player:
		return
		
	# Update shield status countdown while broken
	if player.is_shield_broken:
		var time_left: float = player.shield_recovery_time_remaining
		if time_left > 0.0:
			status_label.text = "BROKEN\nRecovering... %.1fs" % time_left
		else:
			status_label.text = "BROKEN"
		status_label.modulate = Color(1.0, 0.35, 0.25, 1.0) # Warning red/orange
	else:
		status_label.text = "READY"
		status_label.modulate = Color(0.3, 0.9, 1.0, 1.0) # Bright cyan


func _on_health_changed(current: float, maximum: float) -> void:
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "HP: %d / %d" % [roundi(current), roundi(maximum)]


func _on_shield_durability_changed(current: float, maximum: float) -> void:
	if shield_bar:
		shield_bar.max_value = maximum
		shield_bar.value = current
	if shield_label:
		shield_label.text = "SHIELD: %d / %d" % [roundi(current), roundi(maximum)]


func _on_shield_broken() -> void:
	if shield_label:
		shield_label.text = "SHIELD: 0 / %d" % [roundi(player.shield_max_durability if player else 100.0)]
	if status_label:
		status_label.text = "BROKEN"
		status_label.modulate = Color(1.0, 0.3, 0.2, 1.0)
		
	# Show prominent SHIELD BROKEN notification banner (~1.2s total)
	if break_banner:
		if _banner_tween and _banner_tween.is_valid():
			_banner_tween.kill()
		break_banner.visible = true
		break_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
		break_banner.scale = Vector2(1.15, 1.15)
		
		_banner_tween = create_tween()
		# Fast settle
		_banner_tween.tween_property(break_banner, "scale", Vector2(1.0, 1.0), 0.12)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Hold visible for 0.85s
		_banner_tween.tween_interval(0.85)
		# Smooth fade out over 0.25s
		_banner_tween.tween_property(break_banner, "modulate:a", 0.0, 0.25)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_banner_tween.tween_callback(func() -> void:
			if break_banner:
				break_banner.visible = false
		)


func _on_shield_restored() -> void:
	if status_label:
		status_label.text = "READY"
		status_label.modulate = Color(0.3, 0.9, 1.0, 1.0)
	if shield_bar:
		shield_bar.value = player.shield_durability if player else 100.0
	if shield_label:
		shield_label.text = "SHIELD: %d / %d" % [roundi(player.shield_durability if player else 100.0), roundi(player.shield_max_durability if player else 100.0)]


func _on_player_died() -> void:
	if respawn_banner:
		if _respawn_tween and _respawn_tween.is_valid():
			_respawn_tween.kill()
		respawn_banner.visible = true
		respawn_banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
		respawn_banner.text = "PLAYER DEFEATED\nRespawning in 1.5s..."


func on_player_respawned() -> void:
	if respawn_banner:
		if _respawn_tween and _respawn_tween.is_valid():
			_respawn_tween.kill()
		respawn_banner.visible = false
	if break_banner:
		break_banner.visible = false
	if player and player.health_component:
		_on_health_changed(player.health_component.current_health, player.health_component.max_health)
		_on_shield_durability_changed(player.shield_durability, player.shield_max_durability)
