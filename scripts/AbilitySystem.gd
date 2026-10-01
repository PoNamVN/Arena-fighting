class_name AbilitySystem
extends Node

## Signals
signal ability_equipped(slot_name: String, ability: AbilityData)
signal ability_cast_started(slot_name: String, ability: AbilityData)
signal ability_cast_failed(slot_name: String, reason: String)
signal cooldown_updated(slot_name: String, remaining: float, total: float)
signal cooldown_completed(slot_name: String)

## Configuration
@export var stamina_component: StaminaComponent
@export var slot_skill_1: AbilityData
@export var slot_skill_2: AbilityData
@export var slot_skill_3: AbilityData
@export var slot_ultimate: AbilityData

## State
var _slots: Dictionary = {}
var _cooldowns: Dictionary = {}
var _max_cooldowns: Dictionary = {}


func _ready() -> void:
	_init_default_abilities_if_empty()
	if slot_skill_1:
		equip_ability("skill_1", slot_skill_1)
	if slot_skill_2:
		equip_ability("skill_2", slot_skill_2)
	if slot_skill_3:
		equip_ability("skill_3", slot_skill_3)
	if slot_ultimate:
		equip_ability("ultimate", slot_ultimate)


func _init_default_abilities_if_empty() -> void:
	if not slot_skill_1:
		var s1: AbilityData = AbilityData.new()
		s1.id = "thrust"
		s1.display_name = "Forward Thrust"
		s1.description = "Rapid lunging thrust dealing 35 damage."
		s1.stamina_cost = 20.0
		s1.cooldown = 3.0
		s1.damage = 35.0
		s1.range = 3.0
		s1.is_aoe = false
		s1.is_dodgeable = true
		slot_skill_1 = s1

	if not slot_skill_2:
		var s2: AbilityData = AbilityData.new()
		s2.id = "shield_bash"
		s2.display_name = "Shield Bash"
		s2.description = "Defensive bash that deals 20 damage and restores shield."
		s2.stamina_cost = 25.0
		s2.cooldown = 4.0
		s2.damage = 20.0
		s2.range = 2.2
		s2.is_aoe = false
		s2.is_dodgeable = true
		slot_skill_2 = s2

	if not slot_skill_3:
		var s3: AbilityData = AbilityData.new()
		s3.id = "whirlwind"
		s3.display_name = "Whirlwind Slash"
		s3.description = "360-degree sweep dealing 40 damage to all nearby foes."
		s3.stamina_cost = 35.0
		s3.cooldown = 6.0
		s3.damage = 40.0
		s3.range = 3.5
		s3.is_aoe = true
		s3.is_dodgeable = true
		slot_skill_3 = s3

	if not slot_ultimate:
		var ult: AbilityData = AbilityData.new()
		ult.id = "judgment_blade"
		ult.display_name = "Judgment Blade"
		ult.description = "Signature heavy strike requiring 100% stamina, dealing 100 damage."
		ult.stamina_cost = 100.0
		ult.cooldown = 0.0
		ult.requires_full_stamina = true
		ult.damage = 100.0
		ult.range = 5.0
		ult.is_aoe = true
		ult.is_dodgeable = true
		slot_ultimate = ult


func _process(delta: float) -> void:
	if _cooldowns.is_empty():
		return

	var finished_slots: Array[String] = []
	for slot_name: String in _cooldowns.keys():
		var remaining: float = _cooldowns[slot_name] - delta
		var total: float = _max_cooldowns.get(slot_name, 0.0)
		if remaining <= 0.0:
			finished_slots.append(slot_name)
		else:
			_cooldowns[slot_name] = remaining
			cooldown_updated.emit(slot_name, remaining, total)

	for slot_name: String in finished_slots:
		_cooldowns.erase(slot_name)
		_max_cooldowns.erase(slot_name)
		cooldown_completed.emit(slot_name)


func equip_ability(slot_name: String, ability: AbilityData) -> void:
	_slots[slot_name] = ability
	ability_equipped.emit(slot_name, ability)


func get_ability(slot_name: String) -> AbilityData:
	return _slots.get(slot_name, null)


func has_ability(slot_name: String) -> bool:
	return _slots.has(slot_name) and _slots[slot_name] != null


func is_on_cooldown(slot_name: String) -> bool:
	return _cooldowns.has(slot_name) and _cooldowns[slot_name] > 0.0


func get_cooldown_remaining(slot_name: String) -> float:
	return _cooldowns.get(slot_name, 0.0)


func get_max_cooldown(slot_name: String) -> float:
	return _max_cooldowns.get(slot_name, 0.0)


func can_cast(slot_name: String) -> bool:
	if not has_ability(slot_name):
		return false

	if is_on_cooldown(slot_name):
		return false

	var ability: AbilityData = _slots[slot_name]
	if stamina_component:
		if ability.requires_full_stamina and not stamina_component.is_full():
			return false
		if not stamina_component.has_enough_stamina(ability.stamina_cost):
			return false

	return true


func cast_ability(slot_name: String) -> bool:
	if not has_ability(slot_name):
		ability_cast_failed.emit(slot_name, "NO_ABILITY")
		return false

	if is_on_cooldown(slot_name):
		ability_cast_failed.emit(slot_name, "ON_COOLDOWN")
		return false

	var ability: AbilityData = _slots[slot_name]
	if stamina_component:
		if ability.requires_full_stamina and not stamina_component.is_full():
			ability_cast_failed.emit(slot_name, "REQUIRES_FULL_STAMINA")
			return false
		if not stamina_component.consume_stamina(ability.stamina_cost):
			ability_cast_failed.emit(slot_name, "NOT_ENOUGH_STAMINA")
			return false

	if ability.cooldown > 0.0:
		_cooldowns[slot_name] = ability.cooldown
		_max_cooldowns[slot_name] = ability.cooldown

	ability_cast_started.emit(slot_name, ability)
	return true


func reset_cooldowns() -> void:
	_cooldowns.clear()
	_max_cooldowns.clear()
