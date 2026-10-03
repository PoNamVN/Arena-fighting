class_name CombatTestHUD
extends CanvasLayer

@export var player: PlayerController = null

@onready var hp_bar: ProgressBar = get_node_or_null("RootControl/StatsPanel/VBoxContainer/HPContainer/HPProgressBar") as ProgressBar
@onready var hp_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/HPContainer/HPLabel") as Label
@onready var shield_bar: ProgressBar = get_node_or_null("RootControl/StatsPanel/VBoxContainer/ShieldContainer/ShieldProgressBar") as ProgressBar
@onready var shield_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/ShieldContainer/ShieldLabel") as Label
@onready var stamina_bar: ProgressBar = get_node_or_null("RootControl/StatsPanel/VBoxContainer/StaminaContainer/StaminaProgressBar") as ProgressBar
@onready var stamina_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/StaminaContainer/StaminaLabel") as Label
@onready var abilities_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/AbilitiesContainer/AbilitiesLabel") as Label
@onready var status_label: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/StatusContainer/StatusLabel") as Label
@onready var low_shield_warning: Label = get_node_or_null("RootControl/StatsPanel/VBoxContainer/StatusContainer/LowShieldWarning") as Label
@onready var break_banner: Label = get_node_or_null("RootControl/BreakBanner") as Label
@onready var respawn_banner: Label = get_node_or_null("RootControl/RespawnBanner") as Label

var _banner_tween: Tween
var _respawn_tween: Tween


func _ready() -> void:
	if break_banner:
		break_banner.visible = false
	if respawn_banner:
		respawn_banner.visible = false
	if low_shield_warning:
		low_shield_warning.visible = false
	
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
	if p.has_signal("low_shield_warning_changed"):
		if not p.low_shield_warning_changed.is_connected(_on_low_shield_warning_changed):
			p.low_shield_warning_changed.connect(_on_low_shield_warning_changed)

	if p.health_component:
		if not p.health_component.health_changed.is_connected(_on_health_changed):
			p.health_component.health_changed.connect(_on_health_changed)
		if not p.health_component.died.is_connected(_on_player_died):
			p.health_component.died.connect(_on_player_died)

	if "stamina_component" in p and p.stamina_component:
		if not p.stamina_component.stamina_changed.is_connected(_on_stamina_changed):
			p.stamina_component.stamina_changed.connect(_on_stamina_changed)
		_on_stamina_changed(p.stamina_component.current_stamina, p.stamina_component.max_stamina)

	# Initial UI refresh
	if p.health_component:
		_on_health_changed(p.health_component.current_health, p.health_component.max_health)
	_on_shield_durability_changed(p.shield_durability, p.shield_max_durability)
	_on_low_shield_warning_changed(p.get("is_low_shield") if "is_low_shield" in p else false)


func _process(_delta: float) -> void:
	if not player:
		return
		
	if player.wizard_combat:
		shield_bar.get_parent().visible = true
		shield_label.text = "KHIÊN PHÉP: %d / %d" % [player.shield_durability, player.shield_max_durability]
		break_banner.text = "KHIÊN PHÉP BỊ PHÁ VỠ"
		low_shield_warning.text = "ĐỘ BỀN KHIÊN PHÉP THẤP"
		status_label.text = "PHÙ THỦY NGUYÊN TỐ"
		abilities_label.text = ""
		for slot: String in ["skill_1", "skill_2", "skill_3", "ultimate"]:
			var ability: AbilityData = player.ability_system.get_ability(slot)
			var cd: float = player.ability_system.get_cooldown_remaining(slot)
			abilities_label.text += "%s %s: %s · %d NL\n" % [{"skill_1": "Z", "skill_2": "X", "skill_3": "C", "ultimate": "V"}[slot], ability.display_name, "%.1fs" % cd if cd > 0 else ("Sẵn sàng" if player.stamina_component.has_enough_stamina(ability.stamina_cost) else "Thiếu NL"), ability.stamina_cost]
		if player.wizard_combat.storm.channeling():
			status_label.text = "BÃO SÉT · KHIÊN MIỄN SÁT THƯƠNG"
		var wizard_tip: Label = get_node_or_null("RootControl/ControlsTip") as Label
		if wizard_tip:
			wizard_tip.hide()
		return
	if player.archer_combat:
		shield_bar.get_parent().visible = true
		shield_label.text = "ĐỘ BỀN CUNG: %d / %d" % [player.shield_durability, player.shield_max_durability]
		if break_banner:
			break_banner.text = "CUNG BỊ ĐÁNH BẬT"
		if low_shield_warning:
			low_shield_warning.text = "ĐỘ BỀN CUNG THẤP"
		status_label.text = "CUNG BỊ BẬT · %.1fs" % player.shield_recovery_time_remaining if player.is_shield_broken else "CUNG THỦ RỪNG"
		var cooldown: float = player.ability_system.get_cooldown_remaining("skill_1")
		var z_status: String = "%.1fs" % cooldown if cooldown > 0 else ("Sẵn sàng" if player.stamina_component.has_enough_stamina(25.0) else "Thiếu năng lượng")
		abilities_label.text = "Z Loạt tên: %s · 25 NL" % z_status
		for slot: String in ["skill_2", "skill_3"]:
			var ability: AbilityData = player.ability_system.get_ability(slot)
			var remaining: float = player.ability_system.get_cooldown_remaining(slot)
			var state: String = "%.1fs" % remaining if remaining > 0.0 else ("Sẵn sàng" if player.stamina_component.has_enough_stamina(ability.stamina_cost) else "Thiếu năng lượng")
			abilities_label.text += "\n%s %s: %s · %d NL" % ["X" if slot == "skill_2" else "C", ability.display_name, state, ability.stamina_cost]
		abilities_label.text += "\nV Mồi T-rex: %s · 100 NL" % ("Sẵn sàng" if player.stamina_component.is_full() and not player.archer_combat.bait_ultimate.active() else "Đang thi triển" if player.archer_combat.bait_ultimate.active() else "Cần đầy năng lượng")
		var tip: Label = get_node_or_null("RootControl/ControlsTip") as Label
		if tip:
			tip.hide()
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

	# Update abilities cooldown and ultimate readiness
	if abilities_label and "ability_system" in player and player.ability_system:
		var sys: AbilitySystem = player.ability_system
		var cd1: float = sys.get_cooldown_remaining("skill_1")
		var cd2: float = sys.get_cooldown_remaining("skill_2")
		var cd3: float = sys.get_cooldown_remaining("skill_3")
		var s1_str: String = "Z: %.1fs" % cd1 if cd1 > 0.0 else "Z: READY"
		var s2_str: String = "X: %.1fs" % cd2 if cd2 > 0.0 else "X: READY"
		var s3_str: String = "C: %.1fs" % cd3 if cd3 > 0.0 else "C: READY"

		var ult_ready: bool = player.stamina_component != null and player.stamina_component.is_full()
		var ult_pct: int = roundi((player.stamina_component.get_stamina_ratio() * 100.0) if player.stamina_component else 0.0)
		var ult_str: String = "V: [100% READY]" if ult_ready else "V: [%d%%]" % ult_pct

		abilities_label.text = "%s | %s | %s\n%s" % [s1_str, s2_str, s3_str, ult_str]


func _on_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
	if stamina_label:
		stamina_label.text = "STAMINA: %d / %d" % [roundi(current), roundi(maximum)]


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


func _on_low_shield_warning_changed(is_active: bool) -> void:
	if low_shield_warning:
		low_shield_warning.visible = is_active


func on_player_respawned() -> void:
	if respawn_banner:
		if _respawn_tween and _respawn_tween.is_valid():
			_respawn_tween.kill()
		respawn_banner.visible = false
	if break_banner:
		break_banner.visible = false
	_on_low_shield_warning_changed(false)
	if player and player.health_component:
		_on_health_changed(player.health_component.current_health, player.health_component.max_health)
		_on_shield_durability_changed(player.shield_durability, player.shield_max_durability)
