extends SceneTree
const NAMES = [&"DustPuff",&"DustRing",&"Debris",&"Sparks",&"Shockwave",&"GroundDecal"]
const COUNTS = [32,40,24,16,0,0]
var passed := 0
var failed := 0
var manager: Node
var rejection := &""
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:
  passed += 1
  print("[PASS] ",label)
 else:
  failed += 1
  push_error("[FAIL] "+label)
func run() -> void:
 manager = root.get_node("VFXManager")
 if not manager.warmup_complete:
  await manager.warmup_finished
 manager.spawn_rejected.connect(func(_name: StringName,reason: StringName): rejection = reason)
 var children: int = manager.get_node("Pools").get_child_count()
 var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 manager.set_quality(manager.Quality.MEDIUM)
 for i in NAMES.size():
  var name: StringName = NAMES[i]
  var ids := {}
  for cast in 100:
   var effect: Node3D = manager.spawn(name,Vector3(0,0.6,0),{"ground_y":-0.04})
   if effect:
    ids[effect.get_instance_id()] = true
    manager.release(effect)
  check(ids.size()==1 and manager.stats().active==0,"100 cast/return cycles reuse one free lease: "+name)
  for q in 3:
   manager.set_quality(q)
   var fx: Node3D = manager.spawn(name,Vector3.ZERO,{"amount_scale":0.75})
   var expected := roundi(COUNTS[i]*[0.5,1.0,1.2][q]*0.75)
   check(fx.effective_particles()==expected,"Amount scale x quality: %s/%d" % [name,q])
   if fx.particles:
    check(fx.particles.amount==ceili(COUNTS[i]*1.2),"GPU allocation never resized: "+name)
    check(fx.particles.one_shot and not fx.particles.process_material.get("collision_mode") if i<2 else true,"One-shot dust without GPU collision: "+name)
   manager.release(fx)
  manager.set_quality(manager.Quality.MEDIUM)
  var effect: Node3D = manager.spawn(name,Vector3(0,0.6,0),{"scale":1.5,"ground_y":-0.04,"color":Color("c9b48a")})
  check(effect.scale.is_equal_approx(Vector3.ONE*1.5),"Uniform effect scale: "+name)
  if i < 2:
   check(effect.motion.color.get_luminance()<Color("c9b48a").get_luminance() and is_equal_approx(effect.motion.color.a,0.6),"Dust darker than ground, alpha 0.6")
   var mat: StandardMaterial3D = effect.particles.draw_pass_1.material
   check(mat.depth_draw_mode==BaseMaterial3D.DEPTH_DRAW_DISABLED and not mat.proximity_fade_enabled and not mat.emission_enabled,"No depth writing/sampling or bright dust")
  if i == 1:
   check(effect.motion.emission_shape==ParticleProcessMaterial.EMISSION_SHAPE_RING and effect.motion.radial_velocity_min>0,"Ring particles travel outward")
  if i == 2:
   var top: float = effect.collision.global_position.y+effect.collision.size.y*effect.scale.y*0.5
   check(absf(top+0.04)<0.00001,"Debris collider top is precisely ground_y even at scaled effect")
   check(effect.motion.collision_mode==ParticleProcessMaterial.COLLISION_RIGID and effect.motion.collision_bounce>0 and effect.motion.collision_friction>0,"Rigid GPU collision bounces and settles")
  if i == 3:
   check(effect.motion.particle_flag_align_y and effect.particles.lifetime>=0.2 and effect.particles.lifetime<=0.4,"Sparks velocity-aligned and 0.3s")
  if i == 5:
   check(effect.decal.cull_mask==8 and effect.decal.texture_albedo.get_width()==128 and manager._entries[name].instances.size()==6,"Decal ground-only layer, generated 128px texture, pool six")
  manager.release(effect)
 check(manager.get_node("Pools").get_child_count()==children and int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes,"600 casts do not add or leak nodes")
 check(not manager.spawn(&"not_a_real_effect") and rejection==&"unknown_name","Unknown name reports rejection without crash")
 for name: StringName in NAMES:
  manager.spawn(name,Vector3.ZERO,{"ultimate":true})
 await create_timer(4.3).timeout
 check(manager.stats().active==0 and manager.stats().available==manager.stats().pooled,"All six effect lifetimes automatically return to pool")
 for i in 6:
  check(manager.spawn(&"GroundDecal")!=null,"Decal lease %d available" % i)
 check(not manager.spawn(&"GroundDecal") and rejection==&"pool_full","Decal seventh rejected; no node allocation")
 manager.clear()
 manager.set_quality(manager.Quality.HIGH)
 for wave in 3:
  for name: StringName in NAMES.slice(0,4):
   manager.spawn(name,Vector3.ZERO,{"ultimate":true})
 check(manager.common_particles()==402,"High stress three simultaneous particle bursts = 402")
 manager.clear()
 for wave in 3:
  for name: StringName in NAMES.slice(0,4):
   manager.spawn(name)
 check(manager.common_particles()<=300 and rejection==&"particle_budget","Normal requests enforce combined budget 300")
 manager.clear()
 check(not manager.hit_stop_enabled,"Visual hit-stop is OFF by default")
 var ap := AnimationPlayer.new()
 root.add_child(ap)
 ap.speed_scale = 1.25
 check(not manager.hit_stop(ap,0.06) and ap.speed_scale==1.25,"Disabled hit-stop does not change playback")
 manager.hit_stop_enabled = true
 var previous_time_scale := Engine.time_scale
 check(manager.hit_stop(ap,0.06) and ap.speed_scale==0 and Engine.time_scale==previous_time_scale,"Opt-in preview hold never slows engine/gameplay time")
 var until := Time.get_ticks_msec()+100
 while Time.get_ticks_msec()<until:
  await process_frame
 check(ap.speed_scale==1.25,"Preview hit-stop restores original speed using real time")
 manager.hit_stop_enabled = false
 ap.queue_free()
 var gallery: Node3D = load("res://test/vfx_gallery.tscn").instantiate()
 root.add_child(gallery)
 check(gallery.lookdev.preset_index==2 and gallery.lookdev.get_node("Floor").layers==8,"Gallery defaults to Neutral and isolated decal receiver")
 gallery.queue_free()
 print("RESULTS: %d/%d PASSED" % [passed,passed+failed])
 quit(0 if failed==0 else 1)
