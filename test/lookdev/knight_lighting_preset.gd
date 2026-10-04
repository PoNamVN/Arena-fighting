extends Resource
## Lighting resources belong only to the isolated look-dev scene.
@export var label := "Day"
@export var environment: Environment
@export var key_color := Color(1.0, 0.92, 0.80)
@export var key_energy := 1.8
@export var key_rotation := Vector3(-48, -35, 0)
@export var rim_color := Color(0.48, 0.68, 1.0)
@export var rim_energy := 1.0

@export var show_sky := true
@export var backdrop_color := Color(0.16, 0.18, 0.21)
@export var floor_color := Color(0.48, 0.43, 0.34)

@export var fill_color := Color(0.66, 0.70, 1.0)
@export var fill_energy := 0.35
