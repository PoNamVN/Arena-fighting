class_name ArcherReticleHUD
extends Control

var archer_combat: ArcherCombat
var actor: PlayerController

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func setup(combat_node: ArcherCombat, player_actor: PlayerController) -> void:
	archer_combat = combat_node
	actor = player_actor

func _process(_delta: float) -> void:
	visible = is_instance_valid(actor) and is_instance_valid(archer_combat) and not actor.is_dead and actor.controls_enabled and (not actor.is_third_person or archer_combat.sky_aiming)

func _draw() -> void:
	var center := size * .5
	draw_circle(center, 3.0, Color(0, 0, 0, .8))
	draw_circle(center, 1.5, Color.WHITE)
	for axis: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + axis * 4, center + axis * 10, Color(0, 0, 0, .8), 3.0, true)
		draw_line(center + axis * 4, center + axis * 10, Color.WHITE, 1.0, true)
