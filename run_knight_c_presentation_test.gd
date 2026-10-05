extends SceneTree
var passed: int=0
var total: int=0
var manager: Node
var events: Array[StringName]=[]
class Target:
 extends StaticBody3D
 var damage_log: Array[float]=[]
 func take_damage(damage: float,_origin: Vector3)->void:damage_log.append(damage)
func _initialize()->void:call_deferred("run")
func check(ok: bool,label: String)->void:
 total+=1
 if ok:passed+=1
 print("[PASS] " if ok else "[FAIL] ",label)
func settle()->void:
 for item in manager._active.values().duplicate():item.effect._process(5.0)
func nodes(node: Node)->int:
 var n: int=1
 for child in node.get_children():n+=nodes(child)
 return n
func pose(p: PlayerController,time: float)->void:
 p.anim_player.play("Knight_C_WhirlingBlade",0);p.anim_player.seek(time,true);p.anim_player.pause();p._skeleton.force_update_all_bone_transforms()
 await process_frame;await process_frame
func trace(enabled: bool)->Dictionary:
 manager.enabled=enabled
 var world: Node3D=Node3D.new();root.add_child(world)
 var floor_body: StaticBody3D=StaticBody3D.new();world.add_child(floor_body)
 var ground: CollisionShape3D=CollisionShape3D.new();var box: BoxShape3D=BoxShape3D.new();box.size=Vector3(100,.1,100);ground.shape=box;ground.position.y=-.05;floor_body.add_child(ground)
 var p: PlayerController=load("res://scenes/Player.tscn").instantiate();p.external_controlled=true;world.add_child(p);p.position=Vector3(0,.02,0);p.set_process(false);p.set_physics_process(false)
 var target: Target=Target.new();target.collision_layer=4;target.position=Vector3(0,.9,-1.5);world.add_child(target)
 var collision: CollisionShape3D=CollisionShape3D.new();var capsule: CapsuleShape3D=CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.8;collision.shape=capsule;target.add_child(collision)
 var spawned: Array[StringName]=[]
 p.combat.whirling_blade_vfx.effect_spawned.connect(func(name: StringName,_effect: Node3D)->void:spawned.append(name))
 for i in 3:await physics_frame
 p._try_cast_ability("skill_3")
 var rows: Array=[]
 for i in 65:
  await physics_frame
  if p.active_ability_action:p._process_stationary_ability(1.0/60.0)
  rows.append([p.active_ability_action.current_phase if p.active_ability_action else -1,p.global_position,p.velocity,p.stamina_component.current_stamina,target.damage_log.duplicate()])
 var result: Dictionary={"rows":rows,"hits":target.damage_log.duplicate(),"sparks":spawned.count(&"Sparks")}
 world.queue_free();await process_frame;settle();return result
func run()->void:
 manager=root.get_node("VFXManager")
 if not manager.warmup_complete:await manager.warmup_finished
 var before: Dictionary=await trace(false);var after: Dictionary=await trace(true)
 check(before.rows==after.rows,"VFX leaves damage, lifecycle, movement and energy logs unchanged")
 check(after.hits==[30.0] and after.sparks==1 and before.sparks==0,"A real C hit deals 30 once and emits one impact spark burst")
 var stage: Node3D=Node3D.new();root.add_child(stage)
 var floor_body: StaticBody3D=StaticBody3D.new();stage.add_child(floor_body);floor_body.set_meta("ground_color",Color("c9b48a"))
 var shape: CollisionShape3D=CollisionShape3D.new();var box: BoxShape3D=BoxShape3D.new();box.size=Vector3(100,.1,100);shape.shape=box;shape.position.y=-.05;floor_body.add_child(shape)
 var p: PlayerController=load("res://scenes/Player.tscn").instantiate();p.external_controlled=true;stage.add_child(p);p.set_process(false);p.set_physics_process(false);p.position=Vector3(0,.02,0)
 for i in 3:await physics_frame
 var fx: WhirlingBladeVFX=p.combat.whirling_blade_vfx
 fx.effect_spawned.connect(func(name: StringName,_effect: Node3D)->void:events.append(name))
 check(p._skeleton.get_bone_count()==19,"Rig remains 19 bones")
 var clip: Animation=p.anim_player.get_animation("Knight_C_WhirlingBlade")
 check(absf(clip.length-.9)<.00001 and clip.loop_mode==Animation.LOOP_NONE,"C retains .9s lifecycle")
 check(clip.get_track_count()==38,"Every bone has position and rotation reset tracks")
 var idle: Array[Quaternion]=[]
 p.anim_player.play("idle",0);p.anim_player.seek(0,true);p.anim_player.pause()
 for i in p._skeleton.get_bone_count():idle.append(p._skeleton.get_bone_pose_rotation(i))
 var root_bone: int=p._skeleton.find_bone("root");var hips: int=p._skeleton.find_bone("hips")
 var tips: Array[Vector3]=[];var yaw: Array[float]=[];var roots: bool=true
 for frame in range(0,55,3):
  await pose(p,frame/60.0)
  roots=roots and p._skeleton.get_bone_pose_position(root_bone).length()<.00001 and absf(p._skeleton.get_bone_pose_rotation(root_bone).w)>.99999
  var direction: Vector3=Basis(p._skeleton.get_bone_pose_rotation(hips))*Vector3.FORWARD
  var angle: float=atan2(direction.x,-direction.z)
  if not yaw.is_empty():angle=yaw[-1]+wrapf(angle-yaw[-1],-PI,PI)
  yaw.append(angle);tips.append(fx.tip_socket.global_position)
 check(roots,"Root remains fixed throughout C")
 var turn: float=0;var monotonic: bool=true;var spin_sign: float=signf(yaw[4]-yaw[3])
 for i in range(4,13):
  var change: float=yaw[i]-yaw[i-1];turn+=change
  if change*spin_sign<=.001:monotonic=false
 check(monotonic and absf(turn)>TAU,"Hips turn continuously through one loaded full circle")
 var sweep: float=0
 for i in range(4,13):sweep+=tips[i].distance_to(tips[i-1])
 check(sweep>4.0,"Sword tip traces a substantial physical sweep")
 await pose(p,.9)
 var seamless: bool=true
 for i in idle.size():seamless=seamless and absf(idle[i].dot(p._skeleton.get_bone_pose_rotation(i)))>.999
 check(seamless,"End pose matches idle guard")
 check(not clip.find_track(NodePath("Gladiator_Armature/Skeleton3D:head"),Animation.TYPE_SCALE_3D)>=0,"No scale track interferes with FPS head mask")
 manager.quality=manager.Quality.HIGH;events.clear();fx.trigger(p.global_position,3,.45)
 check(fx.visible and fx.air.emitting,"ACTIVE starts reusable sweep and GPU wind")
 check(events.count(&"DustRing")==1 and events.count(&"DustPuff")==2 and events.count(&"HeavyDust")==2 and events.count(&"Debris")==1,"Start combines foot dust, radial sand and small debris")
 check(absf(fx.ground_y)<.001 and fx.ground_color.is_equal_approx(Color("c9b48a")),"Actual ground height and color drive dust")
 check(not events.has(&"Sparks"),"An empty sweep creates no impact sparks")
 check(fx.active_particles()<=300,"High respects its particle cap")
 await pose(p,.22);fx._process(.016)
 await pose(p,.25);fx._process(.016)
 check(fx.previous_valid and fx.cursor>0,"Trail samples the actual sword sockets")
 fx._process(.6)
 check(not fx.visible and not fx.air.emitting,"Sweep and wind expire after ACTIVE")
 fx.stop();settle()
 for quality in 3:
  manager.quality=quality;fx.trigger(p.global_position,3,.45)
  check(roundi(fx.air.amount*fx.air.amount_ratio)==[16,28,40][quality] and fx.active_particles()<=[180,280,300][quality],"Quality changes amounts without reallocating particles: %d"%quality)
  fx.stop();settle()
 var count: int=nodes(p);var pool: int=nodes(manager._pool_root)
 for i in 50:fx.trigger(p.global_position,3,.45);fx.stop();settle()
 check(nodes(p)==count and nodes(manager._pool_root)==pool,"50 casts preserve node and pool counts")
 check(manager.common_particles()==0 and fx.leases.is_empty(),"Cancellation returns owned effects")
 manager.enabled=false;fx.trigger(p.global_position,3,.45)
 check(not fx.visible and not fx.air.emitting,"Global toggle disables C presentation")
 manager.enabled=true;manager.quality=manager.Quality.MEDIUM
 stage.queue_free();await process_frame
 print("RESULTS: %d/%d PASSED"%[passed,total]);quit(0 if passed==total else 1)
