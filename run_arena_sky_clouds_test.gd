extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func step(n:int)->void:
 for i in n:await process_frame
func run()->void:
 for path in ["res://scenes/Arena.tscn","res://scenes/EmptyArena.tscn"]:
  var arena:Node3D=load(path).instantiate();root.add_child(arena);await step(3)
  var clouds:Node=arena.get_node("SkyClouds")
  check(clouds.batch.instance_count==30 and clouds.clouds.multimesh.mesh.get_surface_count()==1,"%s batches ambient clouds into one surface"%path)
  check(clouds.find_children("*","CollisionObject3D",true,false).is_empty(),"Clouds add no collisions")
  check(clouds.clouds.custom_aabb.position.y>=74 and clouds.altitude>=88,"Cloud field bounds remain above the ultimate bank")
  for q in 3:clouds._quality_changed(q);check(clouds.batch.visible_instance_count==[15,24,30][q],"Quality %d sets cloud count"%q)
  var before:float=clouds.elapsed;await step(4)
  check(clouds.elapsed>before and is_equal_approx(clouds.material.get_shader_parameter("elapsed"),clouds.elapsed),"Drift clock advances and reaches shader")
  var count:int=clouds.get_child_count();clouds._process(1000)
  check(clouds.get_child_count()==count,"Long drift reuses the same batch without new nodes")
  paused=true;before=clouds.elapsed;await step(5)
  check(clouds.elapsed==before,"Ultimate/menu pause freezes clouds too")
  paused=false;await step(3);check(clouds.elapsed>before,"Clouds resume after pause")
  arena.queue_free();await step(2)
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed]);quit(1 if failed else 0)
