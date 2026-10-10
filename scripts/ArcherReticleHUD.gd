class_name ArcherReticleHUD
extends Control

## Dynamic Forest Ranger Aim Reticle with Circular Bow-Charge Arc and Lock-On Brackets
## Built for high-impact visual feedback in third-person and first-person archery combat.

const RETICLE_COLOR_IDLE: Color = Color(0.4, 0.95, 0.65, 0.85) # Emerald green
const RETICLE_COLOR_CHARGING: Color = Color(0.3, 1.0, 0.5, 0.95) # Bright spring green
const RETICLE_COLOR_MAX_CHARGE: Color = Color(1.0, 0.84, 0.2, 1.0) # Radiant Gold
const RETICLE_COLOR_LOCKON: Color = Color(0.95, 0.25, 0.35, 0.95) # Crimson/Coral Lock

var archer_combat: ArcherCombat = null
var actor: PlayerController = null

# Visual animation state
var _charge_ratio: float = 0.0
var _is_max_charged: bool = false
var _max_charge_pulse: float = 0.0
var _recoil_bloom: float = 0.0
var _locked_target: Node3D = null
var _target_distance_text: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func setup(combat_node: ArcherCombat, player_actor: PlayerController) -> void:
	archer_combat = combat_node
	actor = player_actor


func _process(delta: float) -> void:
	if not archer_combat or not is_instance_valid(archer_combat) or not actor or not is_instance_valid(actor):
		visible = false
		return

	# Only show reticle when actor is alive and controls are active
	if actor.is_dead or not actor.controls_enabled:
		visible = false
		return

	visible = true

	# Update charging state
	if archer_combat.charging:
		var target_ratio: float = clampf(archer_combat.charge_time / ArcherCombat.MAX_CHARGE, 0.0, 1.0)
		_charge_ratio = lerpf(_charge_ratio, target_ratio, minf(1.0, delta * 25.0))
		_is_max_charged = target_ratio >= 0.98

		if _is_max_charged:
			_max_charge_pulse = fmod(_max_charge_pulse + delta * 8.0, TAU)
		else:
			_max_charge_pulse = 0.0
	else:
		if _charge_ratio > 0.1:
			_recoil_bloom = 1.0 # Trigger shot recoil bloom on release
		_charge_ratio = lerpf(_charge_ratio, 0.0, delta * 18.0)
		_is_max_charged = false

	# Decay recoil bloom
	if _recoil_bloom > 0.0:
		_recoil_bloom = maxf(0.0, _recoil_bloom - delta * 4.5)

	# Update target lock-on state
	_locked_target = archer_combat._find_target()
	if is_instance_valid(_locked_target):
		var dist: float = (actor.global_position - _locked_target.global_position).length()
		_target_distance_text = "%.1fm" % dist
	else:
		_target_distance_text = ""

	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var base_radius: float = 22.0 - (_charge_ratio * 7.0) + (_recoil_bloom * 14.0)

	var theme_color: Color = RETICLE_COLOR_IDLE
	if _is_max_charged:
		var pulse_glow: float = (sin(_max_charge_pulse) + 1.0) * 0.5
		theme_color = RETICLE_COLOR_MAX_CHARGE.lerp(Color.WHITE, pulse_glow * 0.35)
	elif archer_combat.charging:
		theme_color = RETICLE_COLOR_CHARGING.lerp(RETICLE_COLOR_MAX_CHARGE, _charge_ratio)

	if is_instance_valid(_locked_target):
		theme_color = theme_color.lerp(RETICLE_COLOR_LOCKON, 0.45)

	# 1. Central Pip Dot
	draw_circle(center, 2.2 + (_charge_ratio * 0.8), theme_color)

	# 2. Outer Ranger Bracket Reticle (4 elegant compass notches)
	var bracket_dist: float = base_radius + 4.0
	var tick_len: float = 6.0
	var tick_width: float = 1.6

	# North tick
	draw_line(center + Vector2(0, -bracket_dist), center + Vector2(0, -bracket_dist - tick_len), theme_color, tick_width, true)
	# South tick
	draw_line(center + Vector2(0, bracket_dist), center + Vector2(0, bracket_dist + tick_len), theme_color, tick_width, true)
	# West tick
	draw_line(center + Vector2(-bracket_dist, 0), center + Vector2(-bracket_dist - tick_len, 0), theme_color, tick_width, true)
	# East tick
	draw_line(center + Vector2(bracket_dist, 0), center + Vector2(bracket_dist + tick_len, 0), theme_color, tick_width, true)

	# 3. Subtle Faint Guide Ring
	draw_arc(center, base_radius, 0.0, TAU, 36, Color(theme_color.r, theme_color.g, theme_color.b, 0.18), 1.2, true)

	# 4. Circular Arc Bow Charge Meter
	if _charge_ratio > 0.02:
		var arc_angle: float = _charge_ratio * TAU
		var start_angle: float = -PI * 0.5 # Start at top (12 o'clock)
		var end_angle: float = start_angle + arc_angle

		# Shadow/Glow layer behind arc
		var arc_color: Color = theme_color
		var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.45)
		draw_arc(center, base_radius + 1.0, start_angle, end_angle, 32, shadow_color, 4.0, true)
		draw_arc(center, base_radius, start_angle, end_angle, 32, arc_color, 2.5, true)

		# If max charged, draw glowing accent chevrons
		if _is_max_charged:
			draw_arc(center, base_radius + 3.0, 0.0, TAU, 36, Color(1.0, 0.9, 0.4, 0.6), 1.0, true)

	# 5. Hunter Lock-On Brackets & Rangefinder
	if is_instance_valid(_locked_target):
		var lock_radius: float = base_radius + 14.0
		var lock_bracket_len: float = 8.0
		var lock_color: Color = RETICLE_COLOR_LOCKON

		# Corner brackets
		# Top-Left
		draw_line(center + Vector2(-lock_radius, -lock_radius), center + Vector2(-lock_radius + lock_bracket_len, -lock_radius), lock_color, 1.8, true)
		draw_line(center + Vector2(-lock_radius, -lock_radius), center + Vector2(-lock_radius, -lock_radius + lock_bracket_len), lock_color, 1.8, true)
		# Top-Right
		draw_line(center + Vector2(lock_radius, -lock_radius), center + Vector2(lock_radius - lock_bracket_len, -lock_radius), lock_color, 1.8, true)
		draw_line(center + Vector2(lock_radius, -lock_radius), center + Vector2(lock_radius, -lock_radius + lock_bracket_len), lock_color, 1.8, true)
		# Bottom-Left
		draw_line(center + Vector2(-lock_radius, lock_radius), center + Vector2(-lock_radius + lock_bracket_len, lock_radius), lock_color, 1.8, true)
		draw_line(center + Vector2(-lock_radius, lock_radius), center + Vector2(-lock_radius, lock_radius - lock_bracket_len), lock_color, 1.8, true)
		# Bottom-Right
		draw_line(center + Vector2(lock_radius, lock_radius), center + Vector2(lock_radius - lock_bracket_len, lock_radius), lock_color, 1.8, true)
		draw_line(center + Vector2(lock_radius, lock_radius), center + Vector2(lock_radius, lock_radius - lock_bracket_len), lock_color, 1.8, true)

		# Distance text badge below crosshair
		if _target_distance_text != "":
			var font: Font = ThemeDB.fallback_font
			var font_size: int = 11
			var text_size: Vector2 = font.get_string_size(_target_distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos: Vector2 = center + Vector2(-text_size.x * 0.5, lock_radius + 16.0)

			# Background pill
			draw_rect(Rect2(text_pos.x - 6, text_pos.y - 10, text_size.x + 12, text_size.y + 4), Color(0.04, 0.08, 0.05, 0.85), true)
			draw_rect(Rect2(text_pos.x - 6, text_pos.y - 10, text_size.x + 12, text_size.y + 4), Color(0.2, 0.8, 0.4, 0.4), false, 1.0)
			draw_string(font, text_pos, _target_distance_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0.95, 0.95, 0.85, 0.95))
