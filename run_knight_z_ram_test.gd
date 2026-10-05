extends SceneTree
var passed:=0
var failed:=0
var stage:Node3D
var caster:PlayerController
func _initialize() -> void:call_deferred("run")
func check(ok:bool,label:String) -> void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func player(profile:String,at:Vector3) -> PlayerController:
 var actor:PlayerController=load("res://scenes/Player.tscn").instantiate()
 actor.hero_profile=profile;actor.external_controlled=true;actor.position=at
 stage.add_child(actor);actor.set_physics_process(false)
 return actor
func cast() -> void:
 if caster.active_ability_action:caster.active_ability_action.cancel()
 caster.stamina_component.current_stamina=100
 caster.ability_system.reset_cooldowns()
 caster.velocity=Vector3.ZERO;caster.visuals.rotation.y=0;caster._camera_yaw=0
 check(caster._try_cast_ability("skill_1"),"Z cast")
 caster.active_ability_action.update(.321)
func run() -> void:
 var manager:Node=root.get_node("VFXManager")
 if not manager.warmup_complete:await manager.warmup_finished
 stage=Node3D.new();root.add_child(stage)
 var ground:=StaticBody3D.new();stage.add_child(ground)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100)
 shape.shape=box;shape.position.y=-.1;ground.add_child(shape)
 caster=player("knight",Vector3(0,.04,6))
 await physics_frame;await physics_frame
 var enemy:=player("knight",Vector3(0,.04,4.2));enemy.add_to_group("enemies")
 var farther:=player("knight",Vector3(0,.04,4));farther.add_to_group("enemies")
 await physics_frame;await physics_frame
 var hp:=enemy.health_component.current_health
 var far_hp:=farther.health_component.current_health
 cast();var at:=caster.global_position
 caster._check_shield_charge_hit(Vector3.FORWARD)
 check(enemy.health_component.current_health==hp-25 and farther.health_component.current_health==far_hp,"Nearest first target takes 25; target behind is untouched")
 check(caster.active_ability_action.custom_data.has("ram_remaining") and caster.velocity.x==0 and caster.velocity.z==0,"Ram immediately stops caster movement")
 check(enemy.is_control_impaired() and absf(enemy._impact_stun_timer-.75)<.001,"Real opponent is stunned for 0.75s")
 check(absf(enemy._knockback_vel.z+8.0)<.001 and absf(enemy._knockback_timer-.3)<.001,"Opponent receives 2.4m / 0.3s collision-resolved knockback")
 check(not enemy._try_cast_ability("skill_1") and not enemy._try_dodge(),"Stun rejects skill and dodge")
 check(caster._charge_vfx.air_burst.visible and not caster._charge_vfx.trailing,"Circular air waves fire and trail emission stops on contact")
 var brain:=PracticeOpponent.new();brain.actor=enemy;brain.target=caster;brain.enabled=true
 stage.add_child(brain);brain.set_physics_process(false)
 brain.skill_timer=0;brain.skill_warning_remaining=.4;brain.warning_ring.show()
 enemy.visuals.rotation.y=.8
 brain._physics_process(.1)
 check(brain.skill_warning_remaining==0 and not brain.warning_ring.visible and absf(enemy.visuals.rotation.y-.8)<.001 and brain.attacks_started==0,"Practice AI cannot warn, turn or attack while stunned")
 brain.queue_free()

 for i in 12:
  await physics_frame;caster._process_shield_charge(1.0/60)
 check(Vector2(caster.global_position.x-at.x,caster.global_position.z-at.z).length()<.001 and farther.health_component.current_health==far_hp,"No pass-through or second target damage during impact")
 check(caster.anim_player.current_animation=="Knight_Z_Stop","Impact pose leads to stop recovery")
 var enemy_at:=enemy.global_position
 for i in 46:
  await physics_frame;enemy._physics_process(1.0/60)
 check(absf(enemy.global_position.distance_to(enemy_at)-2.4)<.03,"Knockback physically travels 2.4m on open ground")
 check(not enemy.is_control_impaired() and enemy._impact_stun_timer==0,"Stun expires and releases control")
 if caster.active_ability_action:caster.active_ability_action.cancel()
 farther.remove_from_group("enemies")
 # A successful i-frame contact keeps existing Perfect Dodge and cannot stun.
 enemy.global_position=caster.global_position+Vector3.FORWARD*1.8
 enemy.dodge_controller.is_dodging=true
 enemy.dodge_controller._in_iframe=true
 enemy.dodge_controller._timer=.1
 var evade_hp:=enemy.health_component.current_health
 cast();caster._check_shield_charge_hit(Vector3.FORWARD)
 check(enemy.health_component.current_health==evade_hp and enemy._impact_stun_timer==0,"I-frame negates damage, knockback and stun")
 check(not caster.active_ability_action.custom_data.has("ram_remaining"),"Evaded contact does not trigger a false ram impact")
 enemy.dodge_controller.reset()
 CombatTimeManager.reset_time()
 enemy.remove_from_group("enemies")
 if caster.active_ability_action:caster.active_ability_action.cancel()
 for profile in ["archer","wizard"]:
  var actor:=player(profile,Vector3(10,.04,0))
  await physics_frame;await physics_frame
  check(actor.apply_impact_stun(.75) and actor.is_control_impaired(),profile+" uses the same physical stun")
  actor.apply_knockback(Vector3.RIGHT,2.4,.3)
  for i in 46:
   await physics_frame;actor._physics_process(1.0/60)
  check(not actor.is_control_impaired(),profile+" stun expires correctly")
  actor.queue_free();await actor.tree_exited
 # A solid wall must stop the launch instead of teleporting the opponent through it.
 enemy.global_position=Vector3(0,.04,0)
 var wall:=StaticBody3D.new();stage.add_child(wall);wall.position=Vector3(0,1,-1.3)
 var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(4,2,.2)
 wall_shape.shape=wall_box;wall.add_child(wall_shape)
 await physics_frame
 enemy.apply_impact_stun(.75);enemy.apply_knockback(Vector3.FORWARD,2.4,.3)
 for i in 46:
  await physics_frame;enemy._physics_process(1.0/60)
 check(enemy.global_position.z>-.95,"Knockback stops at solid wall")
 enemy.apply_impact_stun(.75);enemy.combat_state=PlayerController.CombatState.DEAD
 enemy.respawn(Vector3(0,.04,0))
 check(not enemy.is_control_impaired(),"Respawn clears impact stun")
 stage.queue_free();await stage.tree_exited
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed])
 quit(0 if failed==0 else 1)


