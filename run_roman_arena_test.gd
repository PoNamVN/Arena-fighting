extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func run()->void:
 for path in ["res://scenes/Arena.tscn","res://scenes/EmptyArena.tscn"]:
  var arena:Node3D=load(path).instantiate();root.add_child(arena);await process_frame;await process_frame
  var theme:Node=arena.get_node("RomanArenaVisual")
  check(not arena.get_node("ArenaVisualModel").visible and theme.visible,"Roman visual replaces original without overwriting its model")
  var shapes:Node=arena.get_node("PerimeterWalls")
  check(shapes.get_child_count()==8 and shapes.get_child(0).shape.size==Vector3(19,5,1.8),"Eight original wall shapes unchanged")
  check(arena.get_node("FloorCollision/CollisionShape3D").shape.size==Vector3(50,1,50),"Floor collision stays 50x1x50")
  check(theme.find_children("*","CollisionObject3D",true,false).is_empty(),"Architecture and decorative crowd add no gameplay collision")
  check(arena.get_node("FloorCollision").get_meta("ground_color")==Color("c9b48a"),"Skill dust samples warm sand ground colour")
  check(theme.get_child_count()==8 and theme.get_node("RomanSand").mesh.get_surface_count()==1,"Theme uses eight baked mesh surfaces")
  check(arena.has_node("SkyClouds"),"Drifting sky clouds remain in map")
  var env:Environment=arena.get_node("WorldEnvironment").environment
  check(not env.ssao_enabled and not env.ssr_enabled and not env.sdfgi_enabled and not env.volumetric_fog_enabled,"No heavy screen-space/global illumination added")
  var before:float=theme._elapsed;await process_frame;await process_frame
  check(theme._elapsed>before,"Red banners move lightly in wind")
  paused=true;before=theme._elapsed;await process_frame;await process_frame
  check(theme._elapsed==before,"Ultimate pause freezes banner motion")
  paused=false;arena.queue_free();await process_frame
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed]);quit(1 if failed else 0)
