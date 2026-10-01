class_name AttackPayload
extends RefCounted

## Configuration & Metadata
var damage: float = 25.0
var attacker_pos: Vector3 = Vector3(99999.0, 99999.0, 99999.0)
var incoming_shield_damage: float = 15.0
var is_dodgeable: bool = true
var is_perfect_dodge_eligible: bool = true
var stamina_reward: float = 25.0
var can_be_blocked: bool = true
var knockback_distance: float = 0.40
var knockback_duration: float = 0.15
var vfx_type: String = "hit"
var sfx_type: String = "hit"


func _init(
	p_damage: float = 25.0,
	p_attacker_pos: Vector3 = Vector3(99999.0, 99999.0, 99999.0),
	p_shield_damage: float = 15.0,
	p_dodgeable: bool = true,
	p_perfect_dodge_eligible: bool = true,
	p_stamina_reward: float = 25.0
) -> void:
	damage = p_damage
	attacker_pos = p_attacker_pos
	incoming_shield_damage = p_shield_damage
	is_dodgeable = p_dodgeable
	is_perfect_dodge_eligible = p_perfect_dodge_eligible
	stamina_reward = p_stamina_reward
