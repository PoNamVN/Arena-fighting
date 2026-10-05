extends SceneTree
var passed: int=0
var total: int=0
var p: PlayerController
var follow: Node
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 total+=1
 if ok:passed+=1
 print("[PASS] " if ok else "[FAIL] ",label)
func fixture(fps: bool=true)->void:
 if is_instance_valid(p):p.free()
 p=load("res://scenes/Player.tscn").instantiate();p.external_controlled=true;root.add_child(p)
 await process_frame;await process_frame
 p.set_process(false);p.set_physics_process(false);p.visuals.rotation=Vector3.ZERO;p._camera_yaw=0;p._camera_pitch=0;p._update_camera_rotation();p.set_third_person(not fps);p.camera.make_current()
 p.get_node("KnightDashPresentation").set_process(false)
 follow=p.get_node("KnightDashPresentation/KnightDashCamera");follow.set_process(false)
func sample(clip: String,frame: int)->void:
 p.anim_player.play(clip,0);p.anim_player.seek(frame/60.0,true);p.anim_player.pause()
 p._skeleton.force_update_all_bone_transforms();follow._process(.03)
func run()->void:
 await fixture();check(p._try_cast_ability("skill_2"),"X starts through the existing API")
 p._sky_dive_sub_phase=1
 var source: Transform3D=p.camera.transform;var pivot: Transform3D=p.camera_pivot.transform
 var roll: float=0;var last: float=0;var first: bool=true;var inverted: bool=false;var max_step: float=0;var rotation: Quaternion=Quaternion.IDENTITY;var pose_error: float=0
 for frame in range(19,36):
  await sample("Knight_X_SkyDive",frame)
  var actual: Transform3D=follow.render_camera.global_transform
  var authored: Transform3D=p._skeleton.global_transform*p._skeleton.get_bone_global_pose(p._skeleton.find_bone("hips"))
  var rest: Transform3D=p.visuals.global_transform*follow._skeleton_reference*follow._hips_rest
  var expected_rotation: Basis=authored.basis.orthonormalized()*rest.basis.orthonormalized().inverse()*p.camera.global_basis
  pose_error=maxf(pose_error,expected_rotation.get_rotation_quaternion().angle_to(actual.basis.get_rotation_quaternion()))
  var angle: float=atan2(actual.basis.y.z,actual.basis.y.y)
  if not first:roll+=wrapf(angle-last,-PI,PI);max_step=maxf(max_step,rotation.angle_to(actual.basis.get_rotation_quaternion()))
  first=false;last=angle;rotation=actual.basis.get_rotation_quaternion();inverted=inverted or actual.basis.y.dot(Vector3.UP)<-.8
 check(follow.owns_camera and root.get_camera_3d()==follow.render_camera,"X aerial roll uses the FPS rendering camera")
 check(absf(roll)>6.0 and inverted and pose_error<.001,"X camera matches every authored somersault pose including takeoff/exit lean")
 check(max_step<.8,"X somersault camera has no discontinuous frame rotation")
 check(p.camera.transform.is_equal_approx(source) and p.camera_pivot.transform.is_equal_approx(pivot),"X camera leaves gameplay aim and look pivot unchanged")
 p._sky_dive_sub_phase=2;follow._process(.01);follow._process(.13)
 check(not follow.owns_camera and root.get_camera_3d()==p.camera,"Aerial aiming restores the authoritative view")
 p._sky_dive_sub_phase=3;p._sky_dive_direction=Vector3(0,-.7,-.7141428).normalized()
 await sample("Knight_X_SkyDive",100);p._update_sky_dive_thrust_alignment();follow._process(.04)
 var reference: Transform3D=p.visuals.global_transform*follow._skeleton_reference*follow._hips_rest
 var actual_hips: Transform3D=p._skeleton.global_transform*p._skeleton.get_bone_global_pose(p._skeleton.find_bone("hips"))
 var expected: Basis=actual_hips.basis.orthonormalized()*reference.basis.orthonormalized().inverse()*p.camera.global_basis
 check(follow.owns_camera and (-follow.render_camera.global_basis.z).dot(p._sky_dive_direction)>.999,"Straight X dive looks along the actual sword-first travel direction")
 await sample("Knight_X_SkyDive",117)
 check((-follow.render_camera.global_basis.z).dot(p._sky_dive_direction)>.999,"Holding the dive pose does not reset the rendering direction")
 p._sky_dive_direction=Vector3.DOWN;p._update_sky_dive_thrust_alignment();follow._process(.03)
 check(follow.render_camera.global_basis.is_finite() and (-follow.render_camera.global_basis.z).dot(Vector3.DOWN)>.999,"A vertical dive uses a stable camera up axis")
 p.active_ability_action.cancel();follow._process(.01);follow._process(.13)
 check(not follow.owns_camera and root.get_camera_3d()==p.camera,"X cancellation restores the original camera")
 await fixture();check(p._try_cast_ability("skill_3"),"C starts through the existing API")
 source=p.camera.transform;pivot=p.camera_pivot.transform
 var turn: float=0;first=true;last=0
 for frame in range(9,37):
  await sample("Knight_C_WhirlingBlade",frame)
  var angle: float=atan2(follow.render_camera.global_basis.z.x,follow.render_camera.global_basis.z.z)
  if not first:turn+=wrapf(angle-last,-PI,PI)
  first=false;last=angle
 check(follow.owns_camera and absf(turn)>TAU,"C FPS camera follows the full loaded circular slash")
 check(p.camera.transform.is_equal_approx(source) and p.camera_pivot.transform.is_equal_approx(pivot),"C spin leaves gameplay facing and camera yaw/pitch unchanged")
 var camera_id: int=follow.render_camera.get_instance_id()
 p.active_ability_action.cancel();follow._process(.01);follow._process(.13)
 check(not follow.owns_camera and root.get_camera_3d()==p.camera,"C cancellation blends back safely")
 check(follow.render_camera.get_instance_id()==camera_id,"Skills reuse the existing dash rendering camera")
 await fixture();p._try_cast_ability("skill_3");await sample("Knight_C_WhirlingBlade",22);p.take_damage(9999);follow._process(.02)
 check(not follow.owns_camera and root.get_camera_3d()==p.camera,"Death restores the original camera immediately")
 await fixture(false);p._try_cast_ability("skill_3");await sample("Knight_C_WhirlingBlade",22)
 check(not follow.owns_camera and root.get_camera_3d()==p.camera,"Third-person view remains unchanged")
 await fixture();p._try_cast_ability("skill_3");await sample("Knight_C_WhirlingBlade",22);p.set_third_person(true);follow._process(.02)
 check(not follow.owns_camera and root.get_camera_3d()==p.camera,"B during a skill releases FPS camera immediately")
 p.free();await process_frame
 print("RESULTS: %d/%d PASSED"%[passed,total]);quit(0 if passed==total else 1)
