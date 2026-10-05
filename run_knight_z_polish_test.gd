extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func run() -> void:
 var manager:Node=root.get_node("VFXManager")
 if not manager.warmup_complete:await manager.warmup_finished
 manager.clear()
 var p:PlayerController=load("res://scenes/Player.tscn").instantiate()
 p.external_controlled=true;root.add_child(p);await process_frame
 p.process_mode=Node.PROCESS_MODE_DISABLED
 var sk:Skeleton3D=p._skeleton
 var body:MeshInstance3D=sk.get_node("Gladiator_Mesh")
 check(sk.get_bone_count()==19 and p._z_shield_fit.prepared,"Original 19-bone rig; real mesh clearance prepared")
 var before:=p.global_transform
 p._enlarge_giant_shield();p._shield_visual_tween.kill()
 var worst:=-INF;var tested:=0
 # Skin actual vertices independently; check interpolated visual transforms too.
 for clip in ["Knight_Z_Start","Knight_Z_Charge","Knight_Z_Impact","Knight_Z_Stop"]:
  for frame in 13:
   p.anim_player.play(clip);p.anim_player.seek(p.anim_player.get_animation(clip).length*frame/12.0,true);p.anim_player.pause()
   sk.force_update_all_bone_transforms();await process_frame
   for blend in [.3,.6,1.0]:
    p._blend_z_shield_out(blend,p.visuals.global_transform.affine_inverse()*p._z_shield_socket.global_transform.orthonormalized())
    var inverse:=p._z_shield_visual_root.global_transform.affine_inverse()*sk.global_transform
    var panel:AABB=p._z_shield_fit.panel
    for surface in body.mesh.get_surface_count():
     var arrays:=body.mesh.surface_get_arrays(surface)
     var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
     var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
     var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
     for v in vertices.size():
      var selected:=false;var point:=Vector3.ZERO
      for i in 4:
       if weights[v*4+i]<=.0001:continue
       var bind:=bones[v*4+i];var bone:=sk.find_bone(body.skin.get_bind_name(bind))
       selected=selected or body.skin.get_bind_name(bind) in ["hand.R","forearm.R","hand.L","forearm.L","head","chest","upper_arm.R","upper_arm.L"]
       point+=(sk.get_bone_global_pose(bone)*body.skin.get_bind_pose(bind)*vertices[v])*weights[v*4+i]
      if not selected:continue
      var local:Vector3=inverse*point
      if local.x<panel.position.x or local.x>panel.end.x or local.y<panel.position.y or local.y>panel.end.y:continue
      worst=maxf(worst,(local.z-panel.position.z)*p._z_shield_visual_root.global_basis.z.length());tested+=1
 check(tested>10000 and worst<=-.159,"156 sampled pose/blend states: actual arm/head/chest vertices behind wooden/steel panel by >=159mm")
 check(p.global_transform.is_equal_approx(before),"Shield fitting never moves the actor or collision")
 p._restore_z_shield_visual(true)
 check(not p._z_shield_visual_root.visible and p._z_shield_original.visible and p._z_shield_visual_root.global_transform.is_equal_approx(p._z_shield_socket.global_transform.orthonormalized()),"Restore returns exact socket; only original shield visible")
 p.queue_free();await p.tree_exited
 var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 var counts:=[]
 for quality in [manager.Quality.LOW,manager.Quality.MEDIUM,manager.Quality.HIGH]:
  manager.set_quality(quality)
  var e:Node3D=manager.try_spawn(&"HeavyDust",Vector3.ZERO,{"amount_scale":1.0})
  counts.append(roundi(e.particles.amount*e.particles.amount_ratio))
  check(e.particles.draw_pass_1 is ArrayMesh and e.particles.draw_pass_1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==60,"HeavyDust uses a 20-triangle flat clump mesh")
  var material:StandardMaterial3D=e.particles.draw_pass_1.surface_get_material(0)
  check(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and e.particles.draw_pass_1.surface_get_arrays(0)[Mesh.ARRAY_COLOR].size()==60 and not e.motion.turbulence_enabled,"Opaque dust has baked face colors and no per-particle lighting/alpha/turbulence cost")
  manager.release(e)
 check(counts==[16,32,38],"Low/Med/High counts = 16/32/38")
 for i in 100:
  var e:Node3D=manager.try_spawn(&"HeavyDust",Vector3.ZERO,{"amount_scale":.5})
  if e:manager.release(e)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and manager.stats().active==0,"100 clump spawns return to pool without node growth")
 var e:Node3D=manager.try_spawn(&"HeavyDust",Vector3.ZERO,{"particle_lifetime":.1})
 await create_timer(.35).timeout
 check(not e.active and manager.stats().active==0,"Faceted dust naturally finishes and returns to pool")
 print("CLEARANCE worst_m=",worst," vertices=",tested)
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed]);quit(1 if failed else 0)
