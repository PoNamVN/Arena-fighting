extends SceneTree
var passed:int=0
var failed:int=0
class Probe:
 extends Node
 var ticks:int=0
 func _physics_process(_d:float)->void:ticks+=1
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func step(n:int)->void:
 for i in n:await physics_frame;await process_frame
func run()->void:
 var service:Node=root.get_node("UltimateCinematic")
 var owner:Node=Node.new();root.add_child(owner)
 var other:Node=Node.new();root.add_child(other)
 var probe:Probe=Probe.new();root.add_child(probe);await step(3)
 var before:int=probe.ticks
 check(service.begin(owner) and paused,"Lease freezes world")
 await step(8);check(probe.ticks==before,"Other actor physics stays frozen")
 check(service.begin(owner) and not service.begin(other),"Exclusive owner and repeated begin")
 service.end(other);check(paused,"Non-owner cannot unlock world")
 service.end(owner);service.end(owner);await step(2)
 check(not paused and probe.ticks>before,"Idempotent end resumes world")
 paused=true;check(not service.begin(owner),"Menu pause is preserved");service.end(owner);check(paused,"No lease never unpauses menu");paused=false
 check(service.begin(owner),"Second lease opens");owner.queue_free();await step(2);check(not paused and not service.active,"Owner deletion automatically resumes world")
 service.begin(other);service._started_usec-=9000000;service._process(0)
 check(not paused and not service.active,"Watchdog clears abandoned cutscene")
 var arena:Node3D=Node3D.new();root.add_child(arena)
 var floor_body:StaticBody3D=StaticBody3D.new();var shape:CollisionShape3D=CollisionShape3D.new();var box:BoxShape3D=BoxShape3D.new();box.size=Vector3(200,.1,200);shape.shape=box;floor_body.add_child(shape);floor_body.position.y=-.05;arena.add_child(floor_body)
 var p:PlayerController=load("res://scenes/Player.tscn").instantiate();p.external_controlled=true;arena.add_child(p);p.position=Vector3(0,.02,6);p.set_third_person(true);p.camera.make_current();await step(8)
 p.stamina_component.current_stamina=100;check(p._try_cast_ability("ultimate"),"V begins selection");await step(32)
 check(not paused,"Unconfirmed targeting does not freeze world")
 var test_hud:CanvasLayer=CanvasLayer.new();root.add_child(test_hud)
 var ult:GiantSwordUltimate=p.giant_sword_ultimate
 ult.target_position=Vector3.ZERO;ult.target_valid=true;ult._confirm_target()
 var position:Vector3=p.global_position;var remaining:float=p.active_ability_action.phase_timer;var scale_before:float=Engine.time_scale
 await step(20)
 check(not test_hud.visible and ult._hud.visible,"Cutscene hides other HUD and retains presentation")
 check(paused and p.global_position.distance_to(position)<.001,"Committed V holds caster and world")
 check(is_equal_approx(remaining,p.active_ability_action.phase_timer),"Opening cloud reveal holds action clock without early damage")
 await step(40)
 check(absf(remaining-p.active_ability_action.phase_timer-(1.0-GiantSwordUltimate.CLOUD_REVEAL_SECONDS)*GiantSwordUltimate.DESCENT_PLAYBACK)<.04,"Slower descent advances action clock once after reveal")
 check(Engine.time_scale==scale_before,"World freeze does not change Engine time scale")
 check(ult.cinematic_camera.position.y>10 and (-ult.cinematic_camera.global_basis.z).y>.7,"Opening camera frames sword from below its tip")
 p.active_ability_action.cancel();await step(2)
 check(test_hud.visible,"Cancellation restores previous HUD visibility")
 check(not paused and p.camera.current and not p.combat.giant_sword_vfx.visible,"Cancellation restores camera and world")
 p.stamina_component.current_stamina=100;p._try_cast_ability("ultimate");await step(32);ult.target_position=Vector3.ZERO;ult.target_valid=true;ult._confirm_target();await step(3)
 p.health_component.take_damage(1000);await step(3)
 check(not paused and not service.active,"Caster death releases freeze")
 p.queue_free();await step(2)
 var vfx:GiantSwordVFX=GiantSwordVFX.new();arena.add_child(vfx);await step(3)
 var bank:Node=vfx._burst;var nodes:int=bank.get_child_count()
 var manager:Node=root.get_node("VFXManager");var counts:Array[int]=[]
 for quality in 3:
  manager.quality=quality;bank.impact(Vector3.ZERO,4.5);counts.append(bank.active_particles());bank.stop()
 check(counts[0]<counts[1] and counts[1]<counts[2],"Low/Med/High scale actual particle counts")
 check(counts[2]+64+24<=600,"High including fall tail and shards remains under 600")
 for i in 50:
  vfx.begin(Vector3.ZERO,4.5);vfx.impact();vfx.update_impact(.25);vfx.update_recovery(.5,2);vfx.stop()
 check(bank.get_child_count()==nodes and bank.active_particles()==0,"50 casts reuse bank without node leaks")
 check(not vfx.visible and not vfx._fall_particles.emitting and not vfx._metal_shards.emitting,"Stop clears all emitters")
 vfx.begin(Vector3.ZERO,4.5)
 check(float(vfx._sword_materials[0].get_shader_parameter("impact_heat"))==0,"Next cast resets impact heat")
 vfx.impact();await step(130)
 check(bank.active_particles()==0,"Effect bank expires without manual cleanup")
 vfx.stop();vfx.queue_free();arena.queue_free();probe.queue_free();other.queue_free();test_hud.queue_free();await step(2)
 print("RESULTS: %d / %d PASSED (%d FAILED)"%[passed,passed+failed,failed]);quit(1 if failed else 0)
