class_name AbilityData
extends Resource

## Configuration
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stamina_cost: float = 0.0
@export var cooldown: float = 0.0
@export var requires_full_stamina: bool = false
@export var damage: float = 25.0
@export var range: float = 2.5
@export var is_aoe: bool = false
@export var is_dodgeable: bool = true
@export var icon: Texture2D = null

## Phase Timings & Modular Action Parameters
@export var startup_duration: float = 0.0
@export var active_duration: float = 0.0
@export var recovery_duration: float = 0.0
@export var allows_movement: bool = false
@export var movement_speed: float = 0.0
@export var has_front_protection: bool = false
@export var allows_dodge: bool = false
@export var knockback_distance: float = 0.40
@export var knockback_duration: float = 0.15
@export var hit_radius: float = 0.0
