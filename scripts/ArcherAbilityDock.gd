class_name ArcherAbilityDock
extends Control

## High-fidelity Forest Ranger Ability Dock for Archer Combat
## Features procedural skill icons, radial cooldown sweeps, stamina cost indicators, and ultimate ready pulses.

const THEME_EMERALD: Color = Color(0.12, 0.78, 0.45, 1.0)
const THEME_GOLD: Color = Color(0.98, 0.82, 0.22, 1.0)
const THEME_BG: Color = Color(0.05, 0.09, 0.06, 0.90)
const THEME_BORDER: Color = Color(0.22, 0.50, 0.32, 0.85)
const THEME_READY_BORDER: Color = Color(0.35, 0.95, 0.60, 0.95)
const THEME_DIM: Color = Color(0.15, 0.20, 0.17, 0.70)

var archer_combat: ArcherCombat = null
var actor: PlayerController = null

# Skill Slot Data
const SKILL_CONFIGS: Array[Dictionary] = [
	{
		"slot": "skill_1",
		"key": "Z",
		"name": "Diều Hâu",
		"cost": 25.0,
		"icon_type": "hawk",
		"color": Color(0.25, 0.92, 0.55),
	},
	{
		"slot": "skill_2",
		"key": "X",
		"name": "Truy Đuổi",
		"cost": 30.0,
		"icon_type": "seeking",
		"color": Color(0.28, 0.85, 0.98),
	},
	{
		"slot": "skill_3",
		"key": "C",
		"name": "Ẩn Bước",
		"cost": 25.0,
		"icon_type": "escape",
		"color": Color(0.65, 0.95, 0.35),
	},
	{
		"slot": "ultimate",
		"key": "V",
		"name": "Mồi T-Rex",
		"cost": 100.0,
		"icon_type": "trex",
		"color": Color(1.0, 0.80, 0.22),
	},
]

var _ult_pulse_time: float = 0.0
var _icon_textures: Dictionary = {}

func _init() -> void:
	_load_textures()

func _load_textures() -> void:
	var paths: Dictionary = {
		"volley": "res://assets/ui/archer/skill_z_volley.png",
		"seeking": "res://assets/ui/archer/skill_x_seeking.png",
		"escape": "res://assets/ui/archer/skill_c_escape.png",
		"trex": "res://assets/ui/archer/skill_v_ultimate.png",
	}
	for k: String in paths:
		if ResourceLoader.exists(paths[k]):
			_icon_textures[k] = load(paths[k])

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(380, 84)
	offset_left = -190
	offset_right = 190
	offset_top = -105
	offset_bottom = -21


func setup(combat_node: ArcherCombat, player_actor: PlayerController) -> void:
	archer_combat = combat_node
	actor = player_actor


func _process(delta: float) -> void:
	if not archer_combat or not is_instance_valid(archer_combat) or not actor or not is_instance_valid(actor):
		visible = false
		return

	if actor.is_dead or not actor.controls_enabled:
		visible = false
		return

	visible = true
	_ult_pulse_time = fmod(_ult_pulse_time + delta * 5.0, TAU)
	queue_redraw()


func _draw() -> void:
	if not actor or not actor.ability_system:
		return

	var slot_width: float = 80.0
	var slot_height: float = 72.0
	var gap: float = 12.0
	var total_width: float = (slot_width * 4.0) + (gap * 3.0)
	var start_x: float = (size.x - total_width) * 0.5
	var start_y: float = (size.y - slot_height) * 0.5

	var cur_stamina: float = actor.stamina_component.current_stamina if actor.stamina_component else 0.0
	var sys: AbilitySystem = actor.ability_system

	for i in range(SKILL_CONFIGS.size()):
		var cfg: Dictionary = SKILL_CONFIGS[i]
		var slot: String = cfg["slot"]
		var slot_x: float = start_x + (i * (slot_width + gap))
		var slot_rect: Rect2 = Rect2(slot_x, start_y, slot_width, slot_height)

		var ability: AbilityData = sys.get_ability(slot)
		var cooldown: float = sys.get_cooldown_remaining(slot)
		var max_cd: float = ability.cooldown if ability else 5.0
		var cd_ratio: float = clampf(cooldown / maxf(0.01, max_cd), 0.0, 1.0)
		var has_stamina: bool = cur_stamina >= cfg["cost"]
		var is_ult: bool = slot == "ultimate"
		var ult_active: bool = is_ult and archer_combat.bait_ultimate and archer_combat.bait_ultimate.active()
		var is_ready: bool = cooldown <= 0.0 and has_stamina and not ult_active

		# 1. Background Panel (Dark wood / Forest obsidian)
		var bg_color: Color = THEME_BG
		if is_ult and is_ready:
			var pulse: float = (sin(_ult_pulse_time) + 1.0) * 0.5
			bg_color = THEME_BG.lerp(Color(0.20, 0.16, 0.04, 0.95), pulse * 0.6)

		draw_rect(slot_rect, bg_color, true)

		# 2. Border Glow
		var border_color: Color = THEME_BORDER
		var border_width: float = 1.4
		if is_ult and is_ready:
			var gold_pulse: float = (sin(_ult_pulse_time) + 1.0) * 0.5
			border_color = THEME_GOLD.lerp(Color.WHITE, gold_pulse * 0.4)
			border_width = 2.4
		elif is_ready:
			border_color = THEME_READY_BORDER
			border_width = 1.8
		elif cooldown > 0.0:
			border_color = Color(0.18, 0.22, 0.20, 0.6)

		draw_rect(slot_rect, border_color, false, border_width)

		# 3. Procedural Skill Glyph Icon (Center of slot)
		var glyph_center: Vector2 = Vector2(slot_x + slot_width * 0.5, start_y + 30.0)
		var glyph_color: Color = cfg["color"] if (is_ready or cooldown <= 0.0) else Color(0.4, 0.45, 0.42, 0.5)
		_draw_skill_glyph(cfg["icon_type"], glyph_center, glyph_color)

		# 4. Radial Cooldown Sweep Overlay
		if cooldown > 0.0:
			var overlay_color: Color = Color(0.02, 0.04, 0.03, 0.75)
			draw_rect(slot_rect, overlay_color, true)

			# Cooldown Arc
			var arc_radius: float = 18.0
			var arc_end: float = -PI * 0.5 + (cd_ratio * TAU)
			draw_arc(glyph_center, arc_radius, -PI * 0.5, arc_end, 28, Color(0.9, 0.95, 0.9, 0.85), 2.2, true)

			# Countdown text
			var cd_text: String = "%.1fs" % cooldown if cooldown >= 1.0 else "%.1f" % cooldown
			var font: Font = ThemeDB.fallback_font
			var font_size: int = 13
			var text_size: Vector2 = font.get_string_size(cd_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, glyph_center + Vector2(-text_size.x * 0.5, 5.0), cd_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

		# 5. Low Stamina Shading Overlay (If off cooldown but lacking stamina)
		elif not has_stamina and not ult_active:
			draw_rect(slot_rect, Color(0.05, 0.05, 0.05, 0.45), true)

		# 6. Keybind Badge (Top-Left)
		var badge_rect: Rect2 = Rect2(slot_x + 5.0, start_y + 5.0, 18.0, 16.0)
		draw_rect(badge_rect, Color(0.12, 0.18, 0.14, 0.95), true, 4.0)
		draw_rect(badge_rect, THEME_BORDER, false, 4.0)
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(slot_x + 9.0, start_y + 17.0), cfg["key"], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.95, 0.95, 0.85))

		# 7. Energy/Stamina Cost (Top-Right)
		var cost_text: String = "%d" % int(cfg["cost"])
		var cost_color: Color = Color(0.35, 0.95, 0.6) if has_stamina else Color(0.95, 0.4, 0.3)
		draw_string(font, Vector2(slot_x + slot_width - 24.0, start_y + 17.0), cost_text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 10, cost_color)

		# 8. Skill Name Label (Bottom)
		var name_text: String = cfg["name"]
		if ult_active:
			name_text = "ĐANG SĂN"
		var name_color: Color = Color(0.9, 0.95, 0.9) if is_ready else Color(0.6, 0.65, 0.62)
		draw_string(font, Vector2(slot_x + 4.0, start_y + slot_height - 6.0), name_text, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 8.0, 10, name_color)


func _draw_skill_glyph(type: String, pos: Vector2, col: Color) -> void:
	if _icon_textures.has(type) and _icon_textures[type] is Texture2D:
		var tex: Texture2D = _icon_textures[type]
		var icon_size: Vector2 = Vector2(34.0, 34.0)
		var dest_rect: Rect2 = Rect2(pos - icon_size * 0.5, icon_size)
		draw_texture_rect(tex, dest_rect, false, col)
		return

	match type:
		"hawk":
			# Hawk silhouette above the single fish projectile.
			draw_polyline(PackedVector2Array([pos + Vector2(-11, -3), pos + Vector2(-5, -6), pos, pos + Vector2(5, -6), pos + Vector2(11, -3)]), col, 2.0, true)
			draw_circle(pos + Vector2(0, -2), 2, col)
			draw_line(pos + Vector2(-5, 6), pos + Vector2(7, 6), col, 2, true)
			draw_line(pos + Vector2(-5, 6), pos + Vector2(-8, 3), col, 1.5, true)
			draw_line(pos + Vector2(-5, 6), pos + Vector2(-8, 9), col, 1.5, true)

		"seeking":
			# Curved homing arrow arc
			draw_arc(pos + Vector2(2, 0), 8.0, PI * 0.7, PI * 1.9, 16, col, 1.8, true)
			var arrow_head: Vector2 = pos + Vector2(2, 0) + Vector2(cos(PI * 1.9), sin(PI * 1.9)) * 8.0
			draw_line(arrow_head, arrow_head + Vector2(-4, -1), col, 1.8, true)
			draw_line(arrow_head, arrow_head + Vector2(-1, 4), col, 1.8, true)
			# Magic star spark
			draw_circle(pos + Vector2(-4, 3), 1.6, col)

		"escape":
			# Leaf / Wind dash flourish
			draw_line(pos + Vector2(-8, 5), pos + Vector2(8, -5), col, 1.8, true)
			draw_line(pos + Vector2(-4, -3), pos + Vector2(6, -7), col, 1.4, true)
			draw_line(pos + Vector2(-6, 7), pos + Vector2(4, 3), col, 1.4, true)
			# Stylized leaf oval
			draw_circle(pos + Vector2(-1, 0), 3.2, Color(col.r, col.g, col.b, 0.45))

		"trex":
			# Dino Jaw silhouette / Predator fang
			draw_line(pos + Vector2(-8, -4), pos + Vector2(0, -8), col, 2.0, true)
			draw_line(pos + Vector2(0, -8), pos + Vector2(8, -2), col, 2.0, true)
			draw_line(pos + Vector2(8, -2), pos + Vector2(4, 6), col, 2.0, true)
			draw_line(pos + Vector2(4, 6), pos + Vector2(-7, 4), col, 2.0, true)
			draw_line(pos + Vector2(-7, 4), pos + Vector2(-8, -4), col, 2.0, true)
			# Eye dot
			draw_circle(pos + Vector2(2, -4), 1.8, Color(1.0, 0.25, 0.15))
			# Sharp tooth
			draw_line(pos + Vector2(2, -1), pos + Vector2(4, 2), col, 1.8, true)
