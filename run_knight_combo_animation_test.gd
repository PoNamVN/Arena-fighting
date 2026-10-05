extends SceneTree
var total:int=0
var passed:int=0
func _initialize()->void:call_deferred("run")
func check(label:String,ok:bool)->void:
 total+=1
 if ok:passed+=1
 print("[PASS] " if ok else "[FAIL] ",label)
func sample(p:PlayerController,clip:String,time:float)->void:
 p.anim_player.play(clip,0.0)
 p.anim_player.seek(time,true)
 p.anim_player.pause()
 p._skeleton.force_update_all_bone_transforms()
 await process_frame
 await process_frame
func run()->void:
 var p:PlayerController=load("res://scenes/Player.tscn").instantiate()
 p.external_controlled=true
 root.add_child(p)
 p.set_physics_process(false)
 p.set_process(false)
 await process_frame
 var sk:Skeleton3D=p._skeleton
 check("19-bone rig retained",sk.get_bone_count()==19)
 check("Damage/impact/window/recovery retained",p.combat.attack_damage==25.0 and p.combat.attack_range==2.2 and p.combat.attack_radius==0.85 and PlayerController.ATTACK_IMPACT_TIMESTAMP==0.35 and PlayerController.COMBO_WINDOW_START==0.35 and PlayerController.COMBO_WINDOW_END==0.70 and PlayerController.COMBO_FINISHER_RECOVERY==0.8)
 await sample(p,"idle",0)
 var idle:Array[Quaternion]=[]
 for i in sk.get_bone_count():idle.append(sk.get_bone_pose_rotation(i))
 var base_root:Transform3D=sk.get_bone_global_pose(sk.find_bone("root"))
 var sweeps:Array[Vector3]=[]
 var traces:Dictionary={}
 var tip:Marker3D=p.find_child("Socket_SwordTip",true,false) as Marker3D
 var sword:MeshInstance3D=p.find_child("Gladiator_Sword",true,false) as MeshInstance3D
 var blade_local:Vector3=Vector3.ZERO
 for surface in sword.mesh.get_surface_count():
  var arrays:Array=sword.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  for i in vertices.size():
   for j in 4:
    if weights[i*4+j]>.99:
     var local_vertex:Vector3=sword.skin.get_bind_pose(bones[i*4+j])*vertices[i]
     if local_vertex.length_squared()>blade_local.length_squared():blade_local=local_vertex
 print("MEASURED BLADE TIP ",blade_local," SOCKET ",tip.position)
 for step in range(1,4):
  var clip:String="attack_%d"%step
  var a:Animation=p.anim_player.get_animation(clip)
  check(clip+" duration 0.75s / no loop",a!=null and absf(a.length-.75)<.00001 and a.loop_mode==Animation.LOOP_NONE)
  var positions:Array[Vector3]=[]
  var rotations:Array[Quaternion]=[]
  var root_ok:bool=true
  for frame in range(46):
   await sample(p,clip,frame/60.0)
   positions.append(sk.get_bone_global_pose(sk.find_bone("hand.L"))*blade_local)
   rotations.append(sk.get_bone_pose_rotation(sk.find_bone("hand.L")))
   root_ok=root_ok and sk.get_bone_global_pose(sk.find_bone("root")).is_equal_approx(base_root)
  check(clip+" root remains stationary",root_ok)
  var max_step:float=0
  for i in range(1,46):max_step=maxf(max_step,rotations[i-1].angle_to(rotations[i]))
  print(clip," max wrist step ",rad_to_deg(max_step))
  check(clip+" no wrist quaternion flip",max_step<deg_to_rad(40))
  var endpoint_ok:bool=true
  for i in sk.get_bone_count():endpoint_ok=endpoint_ok and sk.get_bone_pose_rotation(i).angle_to(idle[i])<.001
  for i in sk.get_bone_count():
   if sk.get_bone_pose_rotation(i).angle_to(idle[i])>.001:print("ENDPOINT ",clip," ",sk.get_bone_name(i)," ",rad_to_deg(sk.get_bone_pose_rotation(i).angle_to(idle[i])))
  check(clip+" recovery returns to idle",endpoint_ok)
  await sample(p,clip,.25)
  for bone in ["hips","chest","upper_arm.L"]:
   var i:int=sk.find_bone(bone)
   check(clip+" moves "+bone,sk.get_bone_pose_rotation(i).angle_to(idle[i])>deg_to_rad(3))
  sweeps.append(positions[27]-positions[18])
  var rows:Array=[]
  for i in positions.size():rows.append([i,positions[i].x,positions[i].y,positions[i].z])
  traces[clip]=rows
 print("SWEEPS ",sweeps)
 check("Horizontal / reverse diagonal / downward sweeps differ",sweeps[0].x*sweeps[1].x<0 and sweeps[1].y>.2 and sweeps[2].y<-.35 and absf(sweeps[0].y)<.25)
 for step in range(1,4):
  p._combo_step=step
  p._play_basic_attack_animation()
  p.anim_player.advance(0)
  check("Combo step %d selects correct native clip"%step,p.anim_player.current_animation=="attack_%d"%step and p.anim_player.current_animation_position<.001)
 check("Legacy counter clip supported",p._is_basic_attack_animation(&"attack") and not p._is_basic_attack_animation(&"idle"))
 p.external_controlled=false
 p.combat.trigger_attack_telegraph(Vector3.FORWARD)
 p.combat._trigger_visual_cue()
 check("Owned Knight outline and trail hidden",not p.combat.attack_telegraph_vfx.visible and not p.combat.slash_arc_vfx.visible)
 p.external_controlled=true
 p.combat.trigger_attack_telegraph(Vector3.FORWARD)
 p.combat._trigger_visual_cue()
 check("NPC warnings retained",p.combat.attack_telegraph_vfx.visible and p.combat.slash_arc_vfx.visible)
 var file:FileAccess=FileAccess.open("C:/Users/HP VICTUS/.codex/visualizations/2026/10/03/01a10195-027c-7470-b147-d85b73d0fd85/knight_combo/sweep_trace.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(traces))
 print("RESULTS: %d/%d PASSED"%[passed,total])
 p.queue_free()
 await process_frame
 quit(0 if passed==total else 1)
