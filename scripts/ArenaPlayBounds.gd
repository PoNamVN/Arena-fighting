extends Node3D
## Horizontal arena limits at every altitude. Does not constrain cameras or VFX.
@export var edge_margin:float=.55
var _arena:Node3D
var _normals:Array[Vector3]=[]
var _limits:Array[float]=[]
var _actors:Array[CharacterBody3D]=[]
func _ready()->void:
 _arena=get_parent() as Node3D
 process_physics_priority=1000
 var walls:Node=_arena.get_node("PerimeterWalls")
 for child:Node in walls.get_children():
  var wall:=child as CollisionShape3D
  if wall==null or not wall.shape is BoxShape3D:continue
  var normal:Vector3=wall.transform.basis.z.normalized()
  if normal.dot(wall.position)<0:normal=-normal
  _normals.append(normal)
  _limits.append(normal.dot(wall.position)-(wall.shape as BoxShape3D).size.z*.5-edge_margin)
 for actor:Node in _arena.find_children("*","CharacterBody3D",true,false):_register(actor)
 get_tree().node_added.connect(_register)
func _register(node:Node)->void:
 if node is CharacterBody3D and _arena.is_ancestor_of(node) and not _actors.has(node):_actors.append(node)
func _physics_process(_delta:float)->void:
 for i in range(_actors.size()-1,-1,-1):
  var actor:CharacterBody3D=_actors[i]
  if not is_instance_valid(actor):_actors.remove_at(i);continue
  constrain_actor(actor)
func constrain_actor(actor:CharacterBody3D)->void:
 var before:=actor.global_position
 _constrain_body(actor)
 if not actor is PlayerController or not actor.ragdoll:return
 var ragdoll:KnightRagdoll=actor.ragdoll
 if not ragdoll.simulator or not ragdoll.simulator.is_simulating_physics():return
 if not ragdoll._hawk_pins.is_empty():ragdoll.move_hawk_grip(actor.global_position-before)
 # Physical bones move independently of the proxy, including after the bird releases them.
 for name:String in ragdoll.physical_bones:
  var bone:PhysicalBone3D=ragdoll.physical_bones[name]
  _constrain_body(bone)
  if ragdoll._hawk_pins.has(name):bone.set("hawk_pin",bone.global_transform)
func _constrain_body(body:PhysicsBody3D)->void:
 var local:Vector3=_arena.to_local(body.global_position)
 var ratio:float=1.0
 var velocity:Vector3=(body as CharacterBody3D).velocity if body is CharacterBody3D else (body as PhysicalBone3D).linear_velocity
 # Radial clipping satisfies every plane, including very distant teleports.
 for i in _normals.size():
  var projected:float=local.dot(_normals[i])
  if projected<=_limits[i]:continue
  ratio=minf(ratio,_limits[i]/projected)
  var outward:Vector3=(_arena.global_basis*_normals[i]).normalized()
  var speed:float=velocity.dot(outward)
  if speed>0:velocity-=outward*speed
 if ratio<1.0:
  local.x*=ratio;local.z*=ratio
  body.global_position=_arena.to_global(local)
  if body is PhysicalBone3D:PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
 if body is CharacterBody3D:(body as CharacterBody3D).velocity=velocity
 else:(body as PhysicalBone3D).linear_velocity=velocity
