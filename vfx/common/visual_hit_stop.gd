extends Node
## Opt-in animation-preview hold. Never pauses physics, timers or Engine time_scale.
var enabled := false
var _visual: WeakRef
var _speed := 1.0
var _until_usec := 0

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 set_process(false)

func hit_stop(visual: AnimationPlayer, seconds: float = 0.06) -> bool:
 if not enabled or not is_instance_valid(visual):
  return false
 restore()
 _visual = weakref(visual)
 _speed = visual.speed_scale
 _until_usec = Time.get_ticks_usec()+int(clampf(seconds,0.04,0.08)*1000000)
 visual.speed_scale = 0
 set_process(true)
 return true

func _process(_delta: float) -> void:
 if not enabled or Time.get_ticks_usec() >= _until_usec:
  restore()

func restore() -> void:
 if _visual:
  var visual := _visual.get_ref() as AnimationPlayer
  if is_instance_valid(visual):
   visual.speed_scale = _speed
 _visual = null
 set_process(false)

func _exit_tree() -> void:
 restore()
