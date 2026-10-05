extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func run()->void:
 var v:GiantSwordVFX=GiantSwordVFX.new();root.add_child(v);await process_frame
 v.begin(Vector3(12,0,5),4.5)
 check(v.clouds.size()==48 and v.clouds[0].mesh is QuadMesh,"Cloud bank uses reusable soft billboards")
 check(v._cloud_split==0 and v.sword.position.y>GiantSwordVFX.CLOUD_HEIGHT and v.sword.position.y+24.5<GiantSwordVFX.CLOUD_HEIGHT+32,"Intact thick cloud bank surrounds entire sword before descent")
 check(v._cloud_layers[0].get_shader_parameter("origin")==v.global_position,"Cloud opening follows remote impact origin")
 for quality in 3:
  v._quality_changed(quality);v.update_cloud_hold(0)
  var count:int=0;var angles:Dictionary={}
  for i in v.clouds.size():
   if v.clouds[i].visible:count+=1;angles[i/6]=true
  check(count==[24,36,48][quality] and angles.size()==8,"Quality %d retains cloud coverage in all eight directions"%quality)
 v.update_cloud_hold(.7);check(is_equal_approx(v._cloud_time,.7),"Clouds drift while action clock is held")
 var last:float=v.sword.position.y;var monotonic:bool=true
 for i in 61:
  v.update_startup(1.4*(1-i/60.0),1.4);monotonic=monotonic and v.sword.position.y<=last;last=v.sword.position.y
 check(monotonic and is_zero_approx(last),"Sword descends continuously to ground without reversal")
 check(v._cloud_split==1 and float(v._cloud_layers[0].get_shader_parameter("split"))==1,"Sword passage opens cloud layer")
 v.impact();check(v._cracks.visible and float(v._crack_material.get_shader_parameter("spread"))==0,"Cracks start at impact without early propagation")
 v.update_impact(.3);var mid:float=v._crack_material.get_shader_parameter("spread")
 v.update_impact(.3);check(mid>0 and mid<1 and float(v._crack_material.get_shader_parameter("spread"))==1,"Cracks propagate radially in first .55 seconds")
 check(v._cracks.mesh.get_surface_count()==1 and (v._cracks.global_transform*v._cracks.mesh.get_aabb()).size.x>30,"Branching fissures use one surface across impact area")
 var nodes:int=v.get_child_count()
 for i in 50:v.begin(Vector3.ZERO,4.5);v.impact();v.update_impact(.3);v.stop()
 check(v.get_child_count()==nodes and not v._cracks.visible and not v.clouds[0].visible,"Repeated casts reuse nodes and clean cloud/crack visuals")
 v.begin(Vector3.ZERO,4.5);check(v._cloud_split==0 and not v._cracks.visible,"Next cast resets cloud opening and hides old cracks")
 v.stop()
 var arena:Node3D=load("res://scenes/EmptyArena.tscn").instantiate();root.add_child(arena);await process_frame
 v.begin(Vector3.ZERO,4.5)
 check(int(v._crack_material.get_shader_parameter("plane_count"))==8,"Fracture clips to measured eight inner arena walls")
 var radius:float=v._fracture_radius
 check(radius>18 and radius<20,"Centre cast fracture radius spans roughly three quarters of arena footprint")
 v.update_startup(.7,1.4)
 check(is_equal_approx(v._fall_wake.position.y,v.sword.position.y) and float(v._wake_material.get_shader_parameter("strength"))>.8,"Wind follows actual blade from tip to guard at stronger visibility")
 check(v._fall_wake.mesh.get_aabb().size.y>=24 and v._fall_wake.mesh.get_surface_count()==1,"Face trails and curling edge wakes share one reusable surface")
 v.begin(Vector3(18,0,0),4.5)
 check(v._fracture_radius>radius and int(v._crack_material.get_shader_parameter("plane_count"))==8,"Off-centre fracture reaches further while retaining boundary clipping")
 v.stop();v.queue_free();arena.queue_free();await process_frame
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed]);quit(1 if failed else 0)
