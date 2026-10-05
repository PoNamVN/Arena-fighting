extends Node
## Exclusive world-pause lease. Cutscene owners advance their own timeline while
## the rest of the SceneTree (movement, AI, timers and animation) stays frozen.
signal started(owner: Node)
signal ended
const WATCHDOG_SECONDS: float = 8.0
var _owner: WeakRef
var _lease: int = 0
var _started_usec: int = 0
var _was_paused: bool = false
var _exit_callback: Callable
var _hidden_ui: Array[CanvasLayer]=[]
var active: bool:
 get:return _owner!=null

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS

func begin(owner: Node, presentation: CanvasLayer=null) -> bool:
 if not is_instance_valid(owner) or not owner.is_inside_tree():return false
 if active:return owns(owner)
 if get_tree().paused:return false
 _lease+=1;_owner=weakref(owner);_was_paused=get_tree().paused;_started_usec=Time.get_ticks_usec()
 _exit_callback=_owner_exiting.bind(_lease);owner.tree_exiting.connect(_exit_callback,CONNECT_ONE_SHOT)
 if presentation:
  for layer: CanvasLayer in get_tree().root.find_children("*","CanvasLayer",true,false):
   if layer!=presentation and layer.visible:_hidden_ui.append(layer);layer.hide()
 get_tree().paused=true;started.emit(owner);return true

func owns(owner: Node) -> bool:
 return active and _owner.get_ref()==owner

func end(owner: Node) -> void:
 if not owns(owner):return
 _release()

func _owner_exiting(lease: int) -> void:
 if active and lease==_lease:_release()

func _release() -> void:
 var owner: Node=_owner.get_ref() if _owner else null
 _owner=null
 if is_instance_valid(owner) and owner.tree_exiting.is_connected(_exit_callback):owner.tree_exiting.disconnect(_exit_callback)
 for layer in _hidden_ui:
  if is_instance_valid(layer):layer.show()
 _hidden_ui.clear()
 if is_inside_tree():get_tree().paused=_was_paused
 ended.emit()

func _process(_delta: float) -> void:
 if not active:return
 var owner: Node=_owner.get_ref()
 if not is_instance_valid(owner) or not owner.is_inside_tree():_release();return
 if Time.get_ticks_usec()-_started_usec>int(WATCHDOG_SECONDS*1000000):
  if owner.has_method("cancel_cinematic"):owner.cancel_cinematic()
  if active:_release()

func _exit_tree() -> void:
 if active:_release()
