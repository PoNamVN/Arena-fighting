extends SceneTree
var passed:=0
var failed:=0
var arena: Node3D
var p: PlayerController
class Target:
 extends Node3D
 var hits:=0
 var damage:=0.0
 func take_damage(amount: float,_origin: Vector3) -> void:
  hits+=1;damage+=amount
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func cast() -> void:
 if p.active_ability_action:p.active_ability_action.cancel()
 p.stamina_component.current_stamina=100
 p.ability_system.reset_cooldowns()
 p.global_position=Vector3(0,.04,10);p.velocity=Vector3.ZERO
 p._camera_yaw=0;p.visuals.rotation.y=0
 check(p._try_cast_ability("skill_1"),"Z casts")
func run() -> void:
 var manager: Node=root.get_node("VFXManager")
 if not manager.warmup_complete:await manager.warmup_finished
 arena=Node3D.new();root.add_child(arena)
 var floor_body:=StaticBody3D.new();arena.add_child(floor_body)
 var floor_shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100)
 floor_shape.shape=box;floor_shape.position.y=-.1;floor_body.add_child(floor_shape)
 p=load("res://scenes/Player.tscn").instantiate();p.external_controlled=true;arena.add_child(p)
 p.set_physics_process(false)
 await physics_frame;await physics_frame
 var ability: AbilityData=p.ability_system.get_ability("skill_1")
 check(ability.damage==25 and ability.stamina_cost==20 and ability.cooldown==4 and ability.range==2.5,"Damage/energy/cooldown/hit radius preserved")
 check(ability.startup_duration==.32 and ability.active_duration==.95,"Intentional slower Z phase durations")
 for clip in ["Start","Charge","Impact","Stop"]:
  var anim: Animation=p.anim_player.get_animation("Knight_Z_"+clip)
  check(anim!=null and anim.get_track_count()>=19,"Z clip exists: "+clip)
  for track in anim.get_track_count():
   if anim.track_get_path(track).get_concatenated_subnames()=="root" and anim.track_get_type(track)==Animation.TYPE_POSITION_3D:
    for key in anim.track_get_key_count(track):check(anim.track_get_key_value(track,key).length()<.00001,"No animation root motion")
 var distances:Array[float]=[]
 for hz in [30,60,120]:
  Engine.physics_ticks_per_second=hz
  await physics_frame;await physics_frame
  cast()
  var previous:=p.global_position
  var travelled:=0.0
  var max_speed:=0.0
  var initial_speed:=0.0
  var last_speed:=0.0
  for frame in int(hz*2.1):
   await physics_frame
   if p.active_ability_action:p._process_shield_charge(1.0/hz)
   var movement:=p.global_position-previous;movement.y=0;travelled+=movement.length();previous=p.global_position
   var speed:=Vector2(p.velocity.x,p.velocity.z).length()
   if p.active_ability_action and p.active_ability_action.current_phase==AbilityAction.Phase.ACTIVE:
    if initial_speed==0:initial_speed=speed
    max_speed=maxf(max_speed,speed);last_speed=speed
  distances.append(travelled)
  check(travelled>10.8 and travelled<=11.001,"Bounded ~11m travel at %d Hz: %.4f"%[hz,travelled])
  check(initial_speed<3 and max_speed>14 and last_speed<1,"Slow launch, acceleration, brake at %d Hz"%hz)
  check(p.velocity.x==0 and p.velocity.z==0 and p.active_ability_action==null,"No drift after recovery")
  check(not p._charge_vfx.wind.visible and p._z_shield_original.visible,"Wind hidden and original shield restored")
 check(distances.max()-distances.min()<.02,"Travel stable across 30/60/120 Hz")
 Engine.physics_ticks_per_second=60
 await physics_frame;await physics_frame
 cast()
 for frame in 35:
  await physics_frame
  p._process_shield_charge(1.0/60)
 var target:=Target.new();arena.add_child(target);target.add_to_group("enemies")
 target.global_position=p.global_position+Vector3.FORWARD*1.8
 p._check_shield_charge_hit(Vector3.FORWARD)
 check(target.hits==1 and target.damage==25,"First collision deals exactly 25")
 check(p.active_ability_action.current_phase==AbilityAction.Phase.ACTIVE and p.anim_player.current_animation=="Knight_Z_Impact","Collision recoils visually while push stays active")
 var before:=p.global_position
 for frame in 12:
  await physics_frame
  p._process_shield_charge(1.0/60)
 check(p.global_position.distance_to(before)<.001 and target.hits==1,"Stops at first impact without crossing through or repeating damage")
 check(p.anim_player.current_animation=="Knight_Z_Stop","Ram recoil enters recovery instead of charging through")
 target.free();p.active_ability_action.cancel()
 var wall:=StaticBody3D.new();arena.add_child(wall)
 var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(10,4,.25)
 wall_shape.shape=wall_box;wall.position=Vector3(0,2,6);wall.add_child(wall_shape)
 await physics_frame
 cast()
 for frame in 110:
  await physics_frame
  if p.active_ability_action:p._process_shield_charge(1.0/60)
 check(p.global_position.z>6.4 and p._charge_distance<4,"Wall collision stops charge without crossing obstacle")
 check(p._z_shield_original.visible and not p._charge_vfx.wind.visible,"Wall stop cleans shield and wind")
 arena.queue_free();await arena.tree_exited
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed])
 quit(0 if failed==0 else 1)
