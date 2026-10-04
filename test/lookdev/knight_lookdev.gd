extends Node3D
## This scene has no PlayerController or gameplay processing.
const PRESETS = [preload("res://test/lookdev/day.tres"), preload("res://test/lookdev/sunset.tres"), preload("res://test/lookdev/neutral.tres"), preload("res://test/lookdev/indoor.tres")]
@export_enum("Day", "Sunset", "Neutral", "Indoor") var preset_index := 0
var baseline := false
var _probe_revision := 0
var _previous_msaa := Viewport.MSAA_DISABLED
var _originals: Dictionary = {}
var _overrides: Dictionary = {}
var _toggles: Dictionary = {}
@onready var probe: ReflectionProbe = $ReflectionProbe
@onready var model: Node3D = $Knight
@onready var camera: Camera3D = $Camera3D
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var key: DirectionalLight3D = $Key
@onready var fill: DirectionalLight3D = $Fill
@onready var rim_light: OmniLight3D = $Rim
@onready var status: Label = $UI/Panel/Margin/VBox/Status

func _ready() -> void:
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 _previous_msaa = get_viewport().msaa_3d
 get_viewport().msaa_3d = Viewport.MSAA_2X
 for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
  for s in m.mesh.get_surface_count():
   var id := "%s:%d" % [model.get_path_to(m), s]
   _originals[id] = m.mesh.surface_get_material(s)
   _overrides[id] = m.get_surface_override_material(s)
 var ap: AnimationPlayer = model.get_node("AnimationPlayer")
 ap.play("idle")
 ap.seek(0.25, true)
 ap.pause()
 var selector: OptionButton = $UI/Panel/Margin/VBox/Preset
 for p in PRESETS:
  selector.add_item(p.label)
 selector.select(preset_index)
 selector.item_selected.connect(apply_preset)
 for id in ["Key", "Shadows", "Fill", "Rim", "Sky", "SkyAmbient", "Reflections", "Glow", "ACES"]:
  var button := CheckButton.new()
  button.text = "Ambient" if id == "SkyAmbient" else id
  button.button_pressed = true
  _toggles[id] = button
  $UI/Panel/Margin/VBox.add_child(button)
  button.toggled.connect(func(_on: bool): _apply_toggles())
 var before := CheckButton.new()
 before.text = "Before: original materials, no rim/glow"
 before.toggled.connect(set_baseline)
 $UI/Panel/Margin/VBox.add_child(before)
 var angles := HBoxContainer.new()
 $UI/Panel/Margin/VBox.add_child(angles)
 for i in 3:
  var button := Button.new()
  button.text = ["Front", "3/4", "Back"][i]
  button.pressed.connect(set_angle.bind(i))
  angles.add_child(button)
 apply_preset(preset_index)
 set_angle(1)

func apply_preset(index: int) -> void:
 preset_index = clampi(index, 0, PRESETS.size() - 1)
 var p: Resource = PRESETS[preset_index]
 world.environment = p.environment.duplicate(true)
 key.light_color = p.key_color
 key.light_energy = p.key_energy
 key.rotation_degrees = p.key_rotation
 fill.light_color = p.fill_color
 fill.light_energy = p.fill_energy
 fill.rotation_degrees = Vector3(-25, p.key_rotation.y + 180.0, 0)
 rim_light.light_color = p.rim_color
 rim_light.light_energy = p.rim_energy
 var floor_material := StandardMaterial3D.new()
 floor_material.albedo_color = p.floor_color
 floor_material.roughness = 0.98
 $Floor.material_override = floor_material
 _apply_toggles()
 _refresh_probe()

func _apply_toggles() -> void:
 if _toggles.is_empty():
  return
 var env := world.environment
 var p: Resource = PRESETS[preset_index]
 env.background_mode = Environment.BG_SKY if _toggles.Sky.button_pressed and p.show_sky else Environment.BG_COLOR
 env.background_color = p.backdrop_color
 key.visible = _toggles.Key.button_pressed
 key.shadow_enabled = _toggles.Shadows.button_pressed
 fill.visible = _toggles.Fill.button_pressed and not baseline
 rim_light.visible = _toggles.Rim.button_pressed and not baseline
 env.ambient_light_source = p.environment.ambient_light_source if _toggles.SkyAmbient.button_pressed else Environment.AMBIENT_SOURCE_DISABLED
 probe.visible = _toggles.Reflections.button_pressed and not baseline
 env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if _toggles.Reflections.button_pressed else Environment.REFLECTION_SOURCE_DISABLED
 env.glow_enabled = _toggles.Glow.button_pressed and not baseline
 env.tonemap_mode = Environment.TONE_MAPPER_ACES if _toggles.ACES.button_pressed else Environment.TONE_MAPPER_LINEAR

func set_baseline(on: bool) -> void:
 baseline = on
 for m: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
  for s in m.mesh.get_surface_count():
   var id := "%s:%d" % [model.get_path_to(m), s]
   m.set_surface_override_material(s, _originals[id] if on else _overrides[id])
 _apply_toggles()

func set_angle(index: int) -> void:
 var yaw := deg_to_rad([180.0, 225.0, 30.0][clampi(index, 0, 2)])
 camera.position = Vector3(sin(yaw) * 4.0, 1.95, cos(yaw) * 4.0)
 camera.look_at(Vector3(0, 0.95, 0), Vector3.UP)

func _process(_delta: float) -> void:
 status.text = "%s | %d FPS | %s\nGTX 1650 target: 60+ FPS" % [PRESETS[preset_index].label, Engine.get_frames_per_second(), "BEFORE" if baseline else "LOOK-DEV"]

func _exit_tree() -> void:
 if is_inside_tree():
  get_viewport().msaa_3d = _previous_msaa

func _refresh_probe() -> void:
 if DisplayServer.get_name() == "headless":
  return
 _probe_revision += 1
 probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
 get_tree().create_timer(0.15).timeout.connect(_freeze_probe.bind(_probe_revision))

func _freeze_probe(revision: int) -> void:
 if revision == _probe_revision:
  probe.update_mode = ReflectionProbe.UPDATE_ONCE
