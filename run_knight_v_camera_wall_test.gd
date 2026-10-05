extends SceneTree
var passed:int=0
var failed:int=0
var arena:Node3D
var p:PlayerController
var shape_query:PhysicsShapeQueryParameters3D=PhysicsShapeQueryParameters3D.new()
var ray:PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.new()
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;print("[FAIL] ",label)
func clear_at(at:Vector3,radius:float)->bool:
 shape_query.shape.radius=radius;shape_query.transform=Transform3D(Basis.IDENTITY,at);shape_query.motion=Vector3.ZERO
 return p.get_world_3d().direct_space_state.intersect_shape(shape_query,1).is_empty()
func visible(at:Vector3,target:Vector3)->bool:
 ray.from=at;ray.to=target+Vector3.UP*.6
 return p.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func run()->void:
 arena=load("res://scenes/EmptyArena.tscn").instantiate();root.add_child(arena)
 p=load("res://scenes/Player.tscn").instantiate();p.external_controlled=true;arena.add_child(p);p.set_third_person(true)
 for i in 5:await physics_frame;await process_frame
 p.set_physics_process(false)
 shape_query.shape=SphereShape3D.new();shape_query.collision_mask=1;ray.collision_mask=1
 var cases:Array[Vector3]=[Vector3.ZERO]
 for i in 8:cases.append(Vector3(cos(i*TAU/8),0,sin(i*TAU/8))*18)
 for i in 8:cases.append(Vector3(cos((i+.5)*TAU/8),0,sin((i+.5)*TAU/8))*20.8)
 for target in cases:
  for yaw in [0.0,PI/2,PI,3*PI/2]:
   p.position=target*.6+Vector3.UP*.05;p._camera_yaw=yaw;p.stamina_component.current_stamina=100
   p.camera.global_position=p.position+Vector3(0,1.6,0);p.camera.make_current()
   if not p._try_cast_ability("ultimate"):check(false,"fixture cast");continue
   var ult:GiantSwordUltimate=p.giant_sword_ultimate
   var opening_safe:bool=true
   for frame in 32:
    ult.tick(1.0/60,p.active_ability_action);opening_safe=opening_safe and clear_at(ult.cinematic_camera.global_position,.12)
   check(opening_safe,"Opening lift avoids walls target=%s yaw=%.2f"%[target,yaw])
   ult.target_position=target;ult.target_valid=true;ult._confirm_target()
   var action:AbilityAction=p.active_ability_action
   var safe:bool=true;var los:bool=true
   for progress in [0.0,.25,.5,.75,.99]:
    action.phase_timer=action.data.startup_duration*(1-progress);ult.tick(0,action)
    safe=safe and clear_at(ult.cinematic_camera.global_position,1.0)
    los=los and visible(ult.cinematic_camera.global_position,target)
   action.current_phase=AbilityAction.Phase.ACTIVE;ult.tick(0,action)
   safe=safe and clear_at(ult.cinematic_camera.global_position,1.0);los=los and visible(ult.cinematic_camera.global_position,target)
   check(safe,"Camera + shake clearance target=%s yaw=%.2f"%[target,yaw])
   check(los,"Ground impact remains visible target=%s yaw=%.2f"%[target,yaw])
   action.current_phase=AbilityAction.Phase.RECOVERY
   var return_safe:bool=true
   for frame in 27:
    action.phase_timer=.45-(frame+1)/60.0;ult.tick(0,action)
    var radius:float=lerpf(1.0,.12,smoothstep(0,1,1-action.phase_timer/.45))
    return_safe=return_safe and clear_at(ult.cinematic_camera.global_position,radius)
   check(return_safe,"Return to gameplay avoids walls target=%s yaw=%.2f"%[target,yaw])
   action.cancel()
 check(not paused,"All casts release world pause")
 p.queue_free();arena.queue_free();await process_frame
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed]);quit(1 if failed else 0)
