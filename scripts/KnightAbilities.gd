class_name KnightAbilities
extends RefCounted

## Knight Ability Definitions Factory

static func create_shield_charge() -> AbilityData:
	var a: AbilityData = AbilityData.new()
	a.id = "shield_charge"
	a.display_name = "Giant Shield Charge"
	a.description = "Enlarge shield and charge forward with frontal protection, staggering foes."
	a.stamina_cost = 20.0
	a.cooldown = 4.0
	a.damage = 25.0
	a.range = 2.5
	a.is_aoe = false
	a.is_dodgeable = true
	a.startup_duration = 0.32
	a.active_duration = 0.95
	a.recovery_duration = 0.40
	a.allows_movement = true
	a.movement_speed = 14.8
	a.has_front_protection = true
	a.allows_dodge = false
	a.knockback_distance = 2.40
	a.knockback_duration = 0.30
	return a


static func create_sky_dive() -> AbilityData:
	var a: AbilityData = AbilityData.new()
	a.id = "sky_dive"
	a.display_name = "Sky Dive"
	a.description = "Leap into the air, aim landing position, and impale downwards."
	a.stamina_cost = 25.0
	a.cooldown = 6.0
	a.damage = 35.0
	a.range = 3.5
	a.is_aoe = true
	a.is_dodgeable = true
	a.startup_duration = 0.30
	a.active_duration = 99.0  # Manually controlled: aim waits for LMB or timeout
	a.recovery_duration = 0.50
	a.allows_movement = true
	a.movement_speed = 20.0  # Dive speed (m/s)
	a.has_front_protection = false
	a.allows_dodge = false
	a.knockback_distance = 0.50
	a.knockback_duration = 0.15
	return a


static func create_whirling_blade() -> AbilityData:
	var a: AbilityData = AbilityData.new()
	a.id = "whirling_blade"
	a.display_name = "Whirling Blade"
	a.description = "360-degree high-speed sword spin striking all surrounding enemies."
	a.stamina_cost = 30.0
	a.cooldown = 5.0
	a.damage = 30.0
	a.range = 3.0
	a.is_aoe = true
	a.is_dodgeable = true
	a.startup_duration = 0.15
	a.active_duration = 0.45
	a.recovery_duration = 0.30
	a.allows_movement = false
	a.movement_speed = 0.0
	a.has_front_protection = false
	a.allows_dodge = false
	a.knockback_distance = 0.40
	a.knockback_duration = 0.15
	return a


static func create_giant_sword_ultimate() -> AbilityData:
	var a: AbilityData = AbilityData.new()
	a.id = "giant_sword_ultimate"
	a.display_name = "Giant Sword Ultimate"
	a.description = "Select a ground target, then summon a colossal steel sword through the clouds."
	a.stamina_cost = 100.0
	a.cooldown = 0.0
	a.requires_full_stamina = true
	a.damage = 90.0
	a.range = 4.5
	a.is_aoe = true
	a.is_dodgeable = true
	a.startup_duration = 1.40
	a.active_duration = 0.20
	a.recovery_duration = 2.0
	a.allows_movement = false
	a.movement_speed = 0.0
	a.has_front_protection = false
	a.allows_dodge = false
	a.knockback_distance = 0.80
	a.knockback_duration = 0.25
	return a


static func equip_knight_loadout(ability_system: AbilitySystem) -> void:
	if not ability_system:
		return
	ability_system.equip_ability("skill_1", create_shield_charge())
	ability_system.equip_ability("skill_2", create_sky_dive())
	ability_system.equip_ability("skill_3", create_whirling_blade())
	ability_system.equip_ability("ultimate", create_giant_sword_ultimate())
