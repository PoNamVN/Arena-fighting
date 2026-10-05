extends SceneTree
var passed: int=0
var total: int=0
var manager: Node
var events: Array[Dictionary]=[]
class Target:
 extends StaticBody3D
 var damage_log: Array[float]=[]
 func take_damage(damage: float,_source: Vector3)->void:damage_log.append(damage)
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 total+=1
 if ok:passed+=1
 print("[PASS] " if ok else "[FAIL] ",label)
func record(event: StringName,name: StringName,effect: Node3D)->void:
 events.append({"event":event,"name":name,"position":effect.global_position})
func count(event: StringName,name: StringName)->int:
 var n: int=0
 for item in events:
  if item.event==event and item.name==name:n+=1
 return n
func arena()->Node3D:
 var stage: Node3D=Node3D.new();root.add_child(stage)
 var floor_body: StaticBody3D=StaticBody3D.new();stage.add_child(floor_body)
 floor_body.set_meta("ground_color",Color("c9b48a"))
 var shape: CollisionShape3D=CollisionShape3D.new();var box: BoxShape3D=BoxShape3D.new()
 box.size=Vector3(100,.1,100);shape.shape=box;shape.position.y=-.05;floor_body.add_child(shape)
 return stage
func player(stage: Node3D)->PlayerController:
 var p: PlayerController=load("res://scenes/Player.tscn").instantiate()
 p.external_controlled=true;stage.add_child(p);p.set_physics_process(false);p.set_process(false)
 p.global_position=Vector3(0,.02,0)
 return p
func settle()->void:
 for item in manager._active.values().duplicate():item.effect._process(5.0)
func trace(enabled: bool)->Array:
 manager.enabled=enabled
 var stage: Node3D=arena();var p: PlayerController=player(stage)
 var target: Target=Target.new();target.collision_layer=4;target.position=Vector3(0,.9,-4);stage.add_child(target)
 var shape: CollisionShape3D=CollisionShape3D.new();var capsule: CapsuleShape3D=CapsuleShape3D.new()
 capsule.radius=.35;capsule.height=1.8;shape.shape=capsule;target.add_child(shape)
 p._camera_pitch=-PI/4;p._camera_yaw=0
 for i in 3:await physics_frame
 p._try_cast_ability("skill_2")
 var samples: Array=[];var aim_frames: int=0;var confirmed: bool=false
 for i in 100:
  await physics_frame
  if p._sky_dive_sub_phase==2:
   aim_frames+=1
   if aim_frames>=3 and not confirmed:Input.action_press("attack");confirmed=true
  elif confirmed:Input.action_release("attack")
  if p.active_ability_action:p._process_sky_dive(1.0/60.0)
  samples.append([p.global_position,p.velocity,p._sky_dive_sub_phase,p.active_ability_action.current_phase if p.active_ability_action else -1,target.damage_log.duplicate(),p.stamina_component.current_stamina])
 Input.action_release("attack");stage.queue_free();await process_frame;settle()
 return samples
func node_count(node: Node)->int:
 var n: int=1
 for child in node.get_children():n+=node_count(child)
 return n
func run()->void:
 manager=root.get_node("VFXManager")
 if not manager.warmup_complete:await manager.warmup_finished
 var before: Array=await trace(false)
 var after: Array=await trace(true)
 check(before==after,"VFX cannot change movement, damage, energy or lifecycle logs")
 check(after.any(func(row: Array):return row[4]==[35.0]),"Actual landing still deals 35 damage exactly once")
 var stage: Node3D=arena();var p: PlayerController=player(stage);var fx: Node=p._dive_vfx
 fx.effect_spawned.connect(record)
 for i in 3:await physics_frame
 manager.quality=manager.Quality.HIGH
 events.clear();fx.prepare()
 check(events.is_empty(),"Startup prepares without premature launch dust")
 fx.launch();fx._process(.016)
 check(count(&"launch",&"HeavyDust")==2 and count(&"launch",&"DustPuff")==2,"Both feet kick faceted and soft sand")
 check(count(&"launch",&"DustRing")==1 and count(&"launch",&"Debris")==1,"Launch creates outward sand ring and pebbles")
 check(fx.ground_color.is_equal_approx(Color("c9b48a")) and absf(fx.ground_y)<.001,"Dust reads actual ground height and color")
 check(fx.active_particles()<=380,"Launch stays inside High particle cap")
 fx.aim();fx._process(.02)
 check(not fx.wind.visible and not fx.streaks.emitting,"Aerial aim holds without emitting an endless trail")
 fx.stop(true);settle();events.clear()
 fx.prepare();fx.dive(Vector3(0,-.5,-.866025).normalized());fx._process(.15)
 check(fx.wind.visible and fx.streaks.emitting,"Dive enables reusable ribbons and GPU air streaks")
 check((-fx.wind.global_basis.z).dot(Vector3(0,-.5,-.866025).normalized())>.999,"Air envelope follows actual dive direction")
 check(fx.stream_material.get_shader_parameter("strength")>.5,"Dive airflow reaches full pressure")
 fx.impact();fx._process(.016)
 check(count(&"impact",&"DustRing")==1 and count(&"impact",&"Debris")==1 and count(&"impact",&"HeavyDust")>=3,"Landing combines debris, rolling dust and outward ring")
 check(fx.ground_root.visible and absf(fx.ground_power-3.5)<.001,"Landing pressure front expands to the existing skill radius")
 var amount: int=events.size();fx.impact()
 check(events.size()==amount,"Landing burst is idempotent")
 check(fx.active_particles()<=380,"Dense landing stays inside High particle cap")
 fx.stop(false)
 check(not fx.wind.visible and fx.ground_root.visible,"Normal finish stops air but preserves short impact tail")
 fx._process(1.0);settle()
 check(manager.common_particles()==0,"All ground emitters return to their shared pool")
 for quality in 3:
  manager.quality=quality;fx.prepare();fx.dive(Vector3.FORWARD);fx._process(.1)
  check(roundi(fx.streaks.amount*fx.streaks.amount_ratio)==[32,56,80][quality],"Air quality uses fixed allocation, level %d"%quality)
  fx.stop(true);settle()
 var nodes: int=node_count(p);var pools: int=node_count(manager._pool_root)
 var bounded: bool=true
 for i in 50:
  fx.prepare();fx.launch();fx._process(.03);fx.aim();settle()
  fx.dive(Vector3(0,-.5,-.866025).normalized());fx._process(.10);fx.impact();fx._process(.016)
  bounded=bounded and fx.active_particles()<=[180,280,380][manager.quality]
  fx.stop(true);settle()
 check(bounded,"50 casts never exceed the particle budget")
 check(node_count(p)==nodes and node_count(manager._pool_root)==pools,"50 casts allocate no extra effect nodes")
 check(manager.common_particles()==0 and fx.leases.is_empty(),"Cancellation returns owned leases with no leaks")
 check(not fx.wind.visible and not fx.streaks.emitting and not fx.ground_root.visible,"Cancellation clears all persistent wind and pressure geometry")
 manager.enabled=false;fx.prepare();fx.launch();fx.dive(Vector3.DOWN);fx._process(.1)
 check(not fx.wind.visible and manager.common_particles()==0,"Global VFX toggle disables X presentation")
 manager.enabled=true;manager.quality=manager.Quality.MEDIUM
 stage.queue_free();await process_frame
 print("RESULTS: %d/%d PASSED"%[passed,total]);quit(0 if passed==total else 1)
