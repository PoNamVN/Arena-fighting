extends Resource

## One named visual-only scene. Gameplay/telegraph timing stays in combat logic.
@export var effect_name: StringName
@export var scene: PackedScene
@export_range(1, 64, 1) var pool_size: int = 8
@export_range(0.02, 30.0, 0.01) var duration: float = 0.4
@export var ultimate: bool = false
## Essential warnings survive the decorative VFX switch and quality reduction.
@export var essential: bool = false
@export var event: StringName
@export var hero: StringName
@export var skill: StringName
@export var warmup_context: Dictionary = {}
@export_range(0.05, 2.0, 0.01) var warmup_seconds: float = 0.12
