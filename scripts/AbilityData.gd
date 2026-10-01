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
