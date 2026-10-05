extends SceneTree
var passed:=0
var failed:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func bind_for(mesh: MeshInstance3D,name: String) -> int:
 for i in mesh.skin.get_bind_count():
  if String(mesh.skin.get_bind_name(i))==name:return i
 return -1
func run() -> void:
 var p:PlayerController=load("res://scenes/Player.tscn").instantiate()
 p.external_controlled=true;root.add_child(p)
 await process_frame
 p.process_mode=Node.PROCESS_MODE_DISABLED
 var sk:Skeleton3D=p._skeleton
 var ap:AnimationPlayer=p.anim_player
 var sword:MeshInstance3D=sk.get_node("Gladiator_Sword")
 var shield:MeshInstance3D=sk.get_node("Gladiator_Shield")
 var tip:Marker3D=sk.get_node("SwordAttachment/Socket_SwordTip")
 var shield_socket:Marker3D=sk.get_node("ShieldAttachment/Socket_ShieldCenter")
 check(sk.get_bone_count()==19,"Rig still has 19 bones")
 check(sk.get_node("SwordAttachment").bone_name=="hand.L" and sk.get_node("ShieldAttachment").bone_name=="forearm.R","Sockets use the physical right sword arm and left shield arm")
 var sword_bind:=bind_for(sword,"hand.L")
 var shield_bind:=bind_for(shield,"forearm.R")
 check(sword_bind>=0 and shield_bind>=0,"Equipment skin bindings follow matching sockets")
 sk.reset_bone_poses();sk.force_update_all_bone_transforms()
 var sword_bounds:=AABB()
 var shield_bounds:=AABB()
 var blade_tip:=Vector3.ZERO
 var shortest:=INF
 var triangles:=0
 var surfaces:=0
 for instance:MeshInstance3D in [sk.get_node("Gladiator_Mesh"),sword,shield]:
  surfaces+=instance.mesh.get_surface_count()
  for s in instance.mesh.get_surface_count():
   var arrays:=instance.mesh.surface_get_arrays(s)
   var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
   triangles+=indices.size()/3
   var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   if instance==sword or instance==shield:
    var index:=sword_bind if instance==sword else shield_bind
    var name:="hand.L" if instance==sword else "forearm.R"
    var rest_skin:Transform3D=sk.get_bone_global_rest(sk.find_bone(name))*instance.skin.get_bind_pose(index)
    for i in vertices.size():
     var point:=rest_skin*vertices[i]
     if instance==sword:
      sword_bounds=sword_bounds.expand(point) if sword_bounds.size!=Vector3.ZERO else AABB(point,Vector3(.000001,.000001,.000001))
      if "Steel" in instance.mesh.surface_get_material(s).resource_name and vertices[i].z<shortest:
       shortest=vertices[i].z;blade_tip=vertices[i]
     else:shield_bounds=shield_bounds.expand(point) if shield_bounds.size!=Vector3.ZERO else AABB(point,Vector3(.000001,.000001,.000001))
     var total:=0.0
     for j in 4:total+=weights[i*4+j]
     if absf(total-1)>0.0001:check(false,"Normalized weapon weights")
 check(sword_bounds.get_center().x>0.25 and shield_bounds.get_center().x<-.4,"Facing -Z: sword is on anatomical right (+X), shield on left (-X)")
 check(triangles==2998 and surfaces==13,"Unchanged 3 meshes / 13 surfaces / 2998 triangles")
 var maximum:=0.0
 var samples:=0
 for clip in ap.get_animation_list():
  ap.play(clip)
  for fraction in [0.0,.2,.4,.6,.8,1.0]:
   ap.seek(ap.get_animation(clip).length*fraction,true)
   sk.force_update_all_bone_transforms()
   await process_frame
   var expected:Vector3=sk.global_transform*sk.get_bone_global_pose(sk.find_bone("hand.L"))*sword.skin.get_bind_pose(sword_bind)*blade_tip
   maximum=maxf(maximum,expected.distance_to(tip.global_position))
   samples+=1
 check(maximum<.001,"Sword tip socket follows actual blade in all %d clip samples; max %.7fm"%[samples,maximum])
 check(shield_socket.transform.origin.x<0,"Shield center offset reflected to physical left")
 var mesh_id:=sword.mesh.get_instance_id()
 var node_count:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 preload("res://scripts/KnightHandedness.gd").apply(p.visuals.get_node("CharacterModel"),ap)
 check(sword.mesh.get_instance_id()==mesh_id and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==node_count,"Correction is idempotent and creates no nodes")
 p.stamina_component.current_stamina=100
 p.ability_system.reset_cooldowns()
 check(p._try_cast_ability("skill_1"),"Z casts with corrected equipment")
 p.active_ability_action.current_phase=AbilityAction.Phase.ACTIVE
 var shield_start:Transform3D=p._z_shield_visual_root.transform
 var body_start:=p.global_transform
 var velocity_start:=p.velocity
 p._charge_vfx.impact(Vector3.FORWARD)
 p._charge_vfx.tick(.075,Vector3.FORWARD)
 check(absf(p._z_shield_visual_root.position.z-shield_start.origin.z-.075)<.0001,"Shield impact has a 7.5cm visual recoil")
 check(p.global_transform.is_equal_approx(body_start) and p.velocity.is_equal_approx(velocity_start),"Visual recoil never changes actor movement")
 p._charge_vfx.tick(.075,Vector3.FORWARD)
 check(p._z_shield_visual_root.transform.is_equal_approx(shield_start),"Shield recoil returns exactly after 0.15s")
 p._charge_vfx._impact_clock=0.0
 p._charge_vfx.impact(Vector3.FORWARD)
 p._charge_vfx.tick(.04,Vector3.FORWARD)
 p.active_ability_action.cancel()
 check(not p._charge_vfx._shield_recoil and not p._charge_vfx.wind.visible and p._z_shield_original.visible,"Cancellation clears recoil, wind and restores the original shield")
 p.queue_free();await p.tree_exited
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed])
 quit(0 if failed==0 else 1)
