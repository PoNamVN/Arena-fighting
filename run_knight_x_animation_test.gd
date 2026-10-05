extends SceneTree
var total:int=0
var passed:int=0
func _initialize()->void:call_deferred("run")
func check(label:String,ok:bool)->void:
 total+=1
 if ok:passed+=1
 print("[PASS] " if ok else "[FAIL] ",label)
func sample(p:PlayerController,frame:int)->void:
 p.anim_player.play("Knight_X_SkyDive",0.0)
 p.anim_player.seek(frame/60.0,true);p.anim_player.pause()
 p._skeleton.force_update_all_bone_transforms()
 await process_frame
func run()->void:
 var source:Node=load("res://assets/models/knight_k3_style3.glb").instantiate()
 var source_player:AnimationPlayer=source.find_child("AnimationPlayer",true,false) as AnimationPlayer
 var source_id:int=source_player.get_animation("Knight_X_SkyDive").get_instance_id()
 var p:PlayerController=load("res://scenes/Player.tscn").instantiate()
 p.external_controlled=true;root.add_child(p);p.set_physics_process(false);p.set_process(false)
 await process_frame
 var sk:Skeleton3D=p._skeleton
 var a:Animation=p.anim_player.get_animation("Knight_X_SkyDive")
 check("Imported source animation library stays unchanged",source_player.get_animation("Knight_X_SkyDive").get_instance_id()==source_id)
 source.free()
 check("Rig has 19 bones",sk.get_bone_count()==19)
 check("Original clip name, 2.5s and one-shot retained",a.length==2.5 and a.loop_mode==Animation.LOOP_NONE)
 var ability:AbilityData=KnightAbilities.create_sky_dive()
 check("X damage/cost/cooldown/radius/startup/recovery/speed unchanged",ability.damage==35 and ability.stamina_cost==25 and ability.cooldown==6 and ability.range==3.5 and ability.startup_duration==.3 and ability.recovery_duration==.5 and ability.movement_speed==20)
 p.anim_player.play("idle",0);p.anim_player.seek(0,true);p.anim_player.pause();sk.force_update_all_bone_transforms()
 var idle:Array[Quaternion]=[]
 for i in sk.get_bone_count():idle.append(sk.get_bone_pose_rotation(i))
 var root_pose:Transform3D=sk.get_bone_global_pose(sk.find_bone("root"))
 var positions:Dictionary={};var rotations:Dictionary={}
 var previous:Quaternion=Quaternion.IDENTITY;var max_wrist:float=0;var still_root:bool=true
 for f in range(151):
  await sample(p,f)
  var wrist:Quaternion=sk.get_bone_pose_rotation(sk.find_bone("hand.L"))
  if f>0:max_wrist=maxf(max_wrist,previous.angle_to(wrist))
  previous=wrist
  still_root=still_root and root_pose.is_equal_approx(sk.get_bone_global_pose(sk.find_bone("root")))
  if f in [0,12,18,45,75,90,117,120,132,150]:
   var joints:Array[Quaternion]=[]
   for i in sk.get_bone_count():joints.append(sk.get_bone_pose_rotation(i))
   rotations[f]=joints
   positions[f]=sk.get_bone_pose_position(sk.find_bone("hips"))
 check("No root-motion added",still_root)
 print("MAX_WRIST_STEP_DEG ",rad_to_deg(max_wrist))
 check("No wrist quaternion flip",max_wrist<deg_to_rad(40))
 for frame in [0,150]:
  var matches:bool=true
  for i in sk.get_bone_count():matches=matches and rotations[frame][i].angle_to(idle[i])<.001
  check("Guard endpoint f%d matches idle"%frame,matches)
 var hover_same:bool=true
 for i in sk.get_bone_count():hover_same=hover_same and rotations[45][i].angle_to(rotations[75][i])<.001
 check("Aim-to-dive seek has matching joints",hover_same and positions[45].distance_to(positions[75])<.001)
 check("Hips load before launching",positions[12].y<positions[0].y-.1 and positions[18].y>positions[12].y+.05)
 check("Landing unfolds then lowers hips to absorb impact",positions[132].y<positions[120].y-.2)
 for name in ["hips","upper_arm.L","forearm.L","thigh.L","shin.L"]:
  var i:int=sk.find_bone(name)
  check("Coordinated movement: "+name,rotations[90][i].angle_to(idle[i])>deg_to_rad(3))
 await sample(p,90)
 var hand:Transform3D=sk.get_bone_global_pose(sk.find_bone("hand.L"))
 var blade:Vector3=hand.basis.z.normalized()
 var body_axis:Vector3=sk.get_bone_global_pose(sk.find_bone("hips")).basis.y.normalized()
 check("Straight thrust aligns sword with torso axis",blade.dot(body_axis)>.999)
 check("Both knees remain straight during arrow flight",sk.get_bone_pose_rotation(sk.find_bone("shin.L")).angle_to(Quaternion.IDENTITY)<.001 and sk.get_bone_pose_rotation(sk.find_bone("shin.R")).angle_to(Quaternion.IDENTITY)<.001)
 check("Spine and chest stay straight during arrow flight",sk.get_bone_pose_rotation(sk.find_bone("spine")).angle_to(Quaternion.IDENTITY)<.001 and sk.get_bone_pose_rotation(sk.find_bone("chest")).angle_to(Quaternion.IDENTITY)<.001)
 var shoulder:Vector3=sk.get_bone_global_pose(sk.find_bone("upper_arm.L")).origin
 var elbow:Vector3=sk.get_bone_global_pose(sk.find_bone("forearm.L")).origin
 check("Sword arm fully extends ahead of the body",shoulder.distance_to(hand.origin)>.95*(shoulder.distance_to(elbow)+elbow.distance_to(hand.origin)))
 var last_angle:float=0.0;var roll:float=0.0;var monotonic:bool=true
 for f in range(19,36):
  await sample(p,f)
  var axis:Vector3=sk.get_bone_global_pose(sk.find_bone("hips")).basis.y
  var angle:float=atan2(-axis.z,axis.y)
  if f>19:
   var step:float=wrapf(angle-last_angle,-PI,PI)
   roll+=step;monotonic=monotonic and step>=-.01 and step<deg_to_rad(40)
  last_angle=angle
 print("AERIAL_ROLL_DEG ",rad_to_deg(roll))
 check("Aerial somersault completes one continuous forward turn",monotonic and roll>deg_to_rad(340) and roll<deg_to_rad(370))
 var model:Node3D=p.visuals.get_node("CharacterModel")
 var rest:Transform3D=model.transform
 var camera_rest:Transform3D=p.camera_pivot.transform
 p._sky_dive_model_rest=rest;p._sky_dive_model_cached=true
 for pitch in [-20.0,-45.0,-75.0,-90.0]:
  await sample(p,90)
  var angle:float=deg_to_rad(pitch)
  p._sky_dive_direction=Vector3(0,sin(angle),-cos(angle))
  p._update_sky_dive_thrust_alignment()
  var world_blade:Vector3=(sk.global_basis*sk.get_bone_global_pose(sk.find_bone("hand.L")).basis.z).normalized()
  var world_body:Vector3=(sk.global_basis*sk.get_bone_global_pose(sk.find_bone("hips")).basis.y).normalized()
  check("Blade and stretched body follow %.0f-degree aim"%pitch,world_blade.dot(p._sky_dive_direction)>.999 and world_body.dot(p._sky_dive_direction)>.999)
 p.active_ability_action=AbilityAction.new()
 p.active_ability_action.init_action(p,"skill_2",ability)
 for phase in [AbilityAction.Phase.STARTUP,AbilityAction.Phase.ACTIVE,AbilityAction.Phase.RECOVERY]:
  p.active_ability_action.current_phase=phase
  p._update_sky_dive_thrust_alignment()
  var owned_transform:Transform3D=model.transform
  p.spectacle._process(1.0/60.0)
  check("VFX cannot overwrite X posture in phase %d"%phase,model.transform.is_equal_approx(owned_transform))
 p.active_ability_action=null
 p.spectacle.set_process(false)
 p._clear_sky_dive_state()
 check("Cancel restores model transform without rotating collision or camera",model.transform.is_equal_approx(rest) and p.rotation==Vector3.ZERO and p.camera_pivot.transform.is_equal_approx(camera_rest))
 p._clear_sky_dive_state()
 check("Repeated restoration is idempotent",model.transform.is_equal_approx(rest))
 p.velocity=Vector3(1,2,3);var start:Vector3=p.global_position
 p.anim_player.play("Knight_X_SkyDive");p.anim_player.seek(2.1,true)
 p._hold_sky_dive_air_pose()
 check("Long dive holds at f117 until physical contact",not p.anim_player.is_playing() and absf(p.anim_player.current_animation_position-1.95)<.00001)
 check("Pose hold cannot alter movement",p.velocity==Vector3(1,2,3) and p.global_position==start)
 p._clear_sky_dive_state()
 check("Cancel clears paused X animation",not p.anim_player.is_playing() and p.anim_player.speed_scale==1)
 print("RESULTS: %d/%d PASSED"%[passed,total]);p.queue_free();await process_frame;quit(0 if passed==total else 1)
