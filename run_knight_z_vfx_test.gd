extends SceneTree
class Target:
 extends Node3D
 var damage_log: Array[float] = []
 func take_damage(damage: float,_source: Vector3) -> void:
  damage_log.append(damage)
const OUT = "C:/Users/HP VICTUS/.codex/visualizations/2026/10/03/01a10195-027c-7470-b147-d85b73d0fd85/vz/"
var passed := 0
var failed := 0
var manager: Node
var arena: Node3D
var player: PlayerController
var events: Array[Dictionary] = []
var peak := 0
var peak_trails := 0
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 if ok:
  passed += 1
  print("[PASS] ",label)
 else:
  failed += 1
  push_error("[FAIL] "+label)
func create_player(baseline: bool = false) -> void:
 arena = Node3D.new()
 root.add_child(arena)
 var floor_body := StaticBody3D.new()
 arena.add_child(floor_body)
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(100,0.2,100)
 shape.shape = box
 shape.position.y = -0.1
 floor_body.add_child(shape)
 var floor_mesh := MeshInstance3D.new()
 floor_mesh.mesh = PlaneMesh.new()
 floor_mesh.mesh.size = Vector2(100,100)
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color("c9b48a")
 floor_mesh.material_override = mat
 arena.add_child(floor_mesh)
 player = load("res://scenes/Player.tscn").instantiate()
 if baseline:
  player.set_script(load(OUT+"baseline_player.gd"))
 player.external_controlled = true
 player.position = Vector3(0,0.05,10)
 arena.add_child(player)
 player.set_physics_process(false)
 player._charge_vfx.effect_spawned.connect(record)
 await physics_frame
 await physics_frame
func record(event: StringName,name: StringName,effect: Node3D) -> void:
 events.append({"event":event,"name":name,"position":effect.global_position,"amount":effect.effective_particles(),"direction":effect.motion.direction if effect.motion else Vector3.ZERO})
 peak = maxi(peak,manager.common_particles())
 peak_trails = maxi(peak_trails,player._charge_vfx.active_trails())
func count(event: StringName,name: StringName = &"") -> int:
 return events.filter(func(e: Dictionary): return e.event==event and (name.is_empty() or e.name==name)).size()
func cast() -> bool:
 player.stamina_component.current_stamina = 100
 player.ability_system.reset_cooldowns()
 player.global_position = Vector3(0,0.05,10)
 player.velocity = Vector3.ZERO
 events.clear()
 return player._try_cast_ability("skill_1")
func trace(baseline: bool) -> Array[Dictionary]:
 await create_player(baseline)
 var target := Target.new()
 target.position = Vector3(0,0,5)
 arena.add_child(target)
 target.add_to_group("enemies")
 cast()
 var result: Array[Dictionary] = []
 for frame in 120:
  await physics_frame
  if player.active_ability_action:
   player._process_shield_charge(1.0/60.0)
  result.append({"frame":frame,"phase":player.active_ability_action.current_phase if player.active_ability_action else -1,"timer":snappedf(player.active_ability_action.phase_timer,0.000001) if player.active_ability_action else 0.0,"position":player.global_position,"damage":target.damage_log.duplicate(),"stamina":player.stamina_component.current_stamina,"protected":player.is_shield_enlarged})
 arena.queue_free()
 await arena.tree_exited
 await process_frame
 return result
func run() -> void:
 manager = root.get_node("VFXManager")
 if not manager.warmup_complete:
  await manager.warmup_finished
 manager.set_quality(manager.Quality.HIGH)
 var before := await trace(true)
 manager.clear()
 var after := await trace(false)
 check(before.back().damage == after.back().damage and after.back().damage == [25.0],"Authorized motion change preserves 25 damage and single hit per target")
 check(before[0].stamina == after[0].stamina,"Authorized motion change preserves energy cost")
 FileAccess.open(OUT+"trace_before.json",FileAccess.WRITE).store_string(JSON.stringify(before,"  "))
 FileAccess.open(OUT+"trace_after.json",FileAccess.WRITE).store_string(JSON.stringify(after,"  "))
 manager.clear()
 await create_player()
 check(cast(),"Z starts with unchanged real ability path")
 check(count(&"start",&"DustPuff")==2 and count(&"start",&"DustRing")==1,"Start emits exactly two foot puffs and one ring")
 check(absf(player._charge_vfx.ground_y)<0.0001 and player._charge_vfx.ground_color.is_equal_approx(Color("c9b48a")),"Ground Y and albedo sampled from actual floor receiver")
 var active: Node3D = manager._active.values()[0].effect
 check(active.motion.direction==Vector3.UP,"Warm/default dust direction restored before start emission")
 var update_events := events.size()
 player._charge_vfx.tick(0.01,Vector3.FORWARD)
 check(events.size()==update_events,"Trail does not spawn before 50ms")
 player._charge_vfx.tick(0.04,Vector3.FORWARD)
 check(count(&"trail")==1 and events.back().direction==Vector3.BACK,"Trail fires at 50ms backwards to dash direction")
 for i in 30:
  player._charge_vfx.tick(0.05,Vector3.FORWARD)
 check(player._charge_vfx.active_trails()==8 and count(&"trail")==8,"Without expiry, strict trail cap is eight active puffs")
 var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
 var pool_nodes: int = manager.get_node("Pools").get_child_count()
 check(count(&"impact")==0,"No hit produces no collision effects")
 player._charge_vfx.impact(Vector3.FORWARD)
 check(count(&"impact",&"DustPuff")==2 and count(&"impact",&"HeavyDust")==6 and count(&"impact",&"DustRing")==1 and count(&"impact",&"Debris")==3 and count(&"impact",&"Sparks")==1 and count(&"impact",&"Shockwave")==1,"Hit adds six faceted clumps, two soft puffs, three debris layers, edge sparks and shockwave")
 check(events.filter(func(e: Dictionary): return e.name==&"Debris").all(func(e: Dictionary): return e.amount<=29),"Impact debris stays <=29 particles at High")
 var sparks: Dictionary = events.filter(func(e: Dictionary): return e.name==&"Sparks")[0]
 var actual_edge: Vector3 = player._z_shield_visual_root.global_transform*player._charge_vfx._shield_edge
 check(sparks.position.distance_to(actual_edge)<0.00001,"Sparks position comes from actual enlarged-shield mesh edge")
 player._charge_vfx.stop(false)
 check(count(&"stop")==1 and not player._charge_vfx.trailing,"Normal stop adds one small puff and disables trail")
 player._charge_vfx.stop(false)
 check(count(&"stop")==1,"Stop hook is idempotent")
 check(peak<=600 and manager.common_particles()<=600,"Worst-case start + eight trails + impact + stop <=600")
 player.active_ability_action.cancel()
 check(not player._charge_vfx.casting and not player._charge_vfx.trailing,"Cancellation stops new emission")
 var cancel_events := events.size()
 player._charge_vfx.tick(1,Vector3.FORWARD)
 check(events.size()==cancel_events,"No deferred trail burst after cancel")
 await create_timer(0.5).timeout
 check(manager.stats().active==0,"Cancel returns all leases; no hanging effect")
 for i in 50:
  check(cast(),"Repeated Z cast %d" % i)
  player._charge_vfx.tick(0.05,Vector3.FORWARD)
  if i%2==0: player._charge_vfx.impact(Vector3.FORWARD)
  player.active_ability_action.cancel()
  player._charge_vfx.stop(true,false)
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and manager.get_node("Pools").get_child_count()==pool_nodes,"50 real casts do not allocate/leak nodes")
 check(manager.stats().active==0,"50 casts/cancels leave every lease returned")
 check(not manager.hit_stop_enabled,"Z never enables hit-stop")
 manager.clear()
 cast()
 for frame in 120:
  await physics_frame
  if player.active_ability_action:
   player._process_shield_charge(1.0/60.0)
 check(count(&"trail")>0 and count(&"stop")==1 and count(&"impact")==0,"Natural no-target Z has trail and stop but no collision VFX")
 await create_timer(0.5).timeout
 check(manager.stats().active==0,"Natural miss returns all effects")
 manager.clear()
 for i in 16:
  manager.spawn(&"DustPuff",Vector3.ZERO,{"amount_scale":0.1})
 var rejects_before: int = manager.stats().dropped
 cast()
 check(count(&"start",&"DustPuff")==0 and manager.stats().dropped==rejects_before,"Full puff pool skips silently without rejection/error")
 player.active_ability_action.cancel()
 manager.clear()
 cast()
 player._shield_stun_timer = 0.2
 player._process(0.01)
 check(not player._charge_vfx.casting and not player._charge_vfx.trailing,"Shield stun stops VFX emission immediately")
 player.active_ability_action.cancel()
 player._shield_stun_timer = 0
 manager.clear()
 cast()
 player._charge_vfx.tick(0.05,Vector3.FORWARD)
 player.transition_to(PlayerController.CombatState.DEAD)
 check(not player._charge_vfx.casting,"Death cancels Z VFX")
 arena.queue_free()
 await arena.tree_exited
 await process_frame
 check(manager.stats().active==0,"Scene exit releases actor-owned effects")
 print("Z_VFX_PEAK ",peak," TRAIL_PEAK ",peak_trails)
 print("RESULTS: %d/%d PASSED" % [passed,passed+failed])
 quit(0 if failed==0 else 1)
