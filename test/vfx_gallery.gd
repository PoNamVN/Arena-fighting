extends Node3D
## Isolated presentation gallery; no skills, damage or gameplay controllers.
const EFFECTS = [&"DustPuff",&"DustRing",&"Debris",&"Sparks",&"Shockwave",&"GroundDecal"]
const STRESS_EFFECTS = [&"DustPuff",&"DustRing",&"Debris",&"Sparks",&"Shockwave"]
var manager: Node
var status: Label
var _stress_wave := 0
var _stress_clock := 0.0
var _fps_clock := 0.0
var _frames := 0
var _display_fps := 0.0
@onready var lookdev: Node3D = $Lookdev

func _ready() -> void:
 manager = get_node("/root/VFXManager")
 lookdev.get_node("UI").hide()
 lookdev.set_process(false)
 lookdev.get_node("Floor").layers = 8
 lookdev.apply_preset(2)
 var ui := CanvasLayer.new()
 ui.name = "GalleryUI"
 add_child(ui)
 var panel := PanelContainer.new()
 panel.position = Vector2(12,12)
 ui.add_child(panel)
 var box := VBoxContainer.new()
 panel.add_child(box)
 var title := Label.new()
 title.text = "Knight V0 | Neutral / Day | pooled visual library"
 box.add_child(title)
 var preset := OptionButton.new()
 preset.add_item("Neutral")
 preset.add_item("Day")
 preset.item_selected.connect(func(i: int): manager.clear(); lookdev.apply_preset(2 if i == 0 else 0))
 box.add_child(preset)
 var quality := OptionButton.new()
 for label in ["Low (0.5)","Med (1.0)","High (1.2)"]:
  quality.add_item(label)
 quality.select(1)
 quality.item_selected.connect(func(i: int): manager.set_quality(i))
 box.add_child(quality)
 for effect: StringName in EFFECTS:
  var button := Button.new()
  button.text = effect
  button.pressed.connect(cast.bind(effect))
  box.add_child(button)
 var stress := Button.new()
 stress.text = "Stress: 5 effects x 3 waves"
 stress.pressed.connect(start_stress)
 box.add_child(stress)
 status = Label.new()
 box.add_child(status)

func cast(effect: StringName, at: Vector3 = Vector3(0,-0.04,-0.9), ultimate: bool = false) -> Node3D:
 var params := {"ground_y":-0.04,"ground_layer":8,"color":lookdev.PRESETS[lookdev.preset_index].floor_color,"radius":1.3,"ultimate":ultimate}
 if effect == &"Sparks":
  params.color = Color(1,0.82,0.5)
  at.y = 0.65
 return manager.spawn(effect,at,params)

func start_stress() -> void:
 if _stress_wave > 0 or not manager.warmup_complete:
  return
 _stress_wave = 3
 _stress_clock = 0

func _process(delta: float) -> void:
 if _stress_wave > 0:
  _stress_clock -= delta
  if _stress_clock <= 0:
   for i in STRESS_EFFECTS.size():
    cast(STRESS_EFFECTS[i],Vector3((i-2)*0.55,-0.04,-0.9),true)
   _stress_wave -= 1
   _stress_clock += 0.1
 _frames += 1
 _fps_clock += delta
 if _fps_clock >= 0.25:
  _display_fps = _frames / _fps_clock
  _frames = 0
  _fps_clock = 0
  status.text = "%.1f FPS | active particle budget: %d | active effects: %d | %s" % [_display_fps,manager.common_particles(),manager.stats().active,"READY" if manager.warmup_complete else "WARMING"]
