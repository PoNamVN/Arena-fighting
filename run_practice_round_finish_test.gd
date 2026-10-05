extends SceneTree
var passed:int=0
var failed:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
 if ok:passed+=1;print("[PASS] ",label)
 else:failed+=1;push_error("[FAIL] "+label)
func frames(n:int)->void:
 for i in n:await physics_frame;await process_frame
func room()->PracticeArena:
 var arena:PracticeArena=load("res://scenes/PracticeArena.tscn").instantiate();root.add_child(arena)
 await frames(4);arena._begin_fight();arena.brain.enabled=false
 arena.player.stamina_component.current_stamina=100
 arena.opponent.position=Vector3(0,.1,-5)
 return arena
func run()->void:
 for slot:String in ["skill_1","skill_2","skill_3","ultimate"]:
  var arena:PracticeArena=await room();var actor:PlayerController=arena.player
  check(actor._try_cast_ability(slot),slot+" begins")
  var action:AbilityAction=actor.active_ability_action
  var events:Dictionary={"cancel":0,"finish":0}
  action.action_cancelled.connect(func():events.cancel+=1)
  action.action_finished.connect(func():events.finish+=1)
  if slot=="ultimate":
   arena.opponent.health_component.current_health=1
   actor.giant_sword_ultimate.target_position=Vector3(0,0,-5);actor.giant_sword_ultimate.target_valid=true;actor.giant_sword_ultimate._confirm_target()
   var deadline:int=Time.get_ticks_msec()+6500
   while not arena.opponent.is_dead and Time.get_ticks_msec()<deadline:await frames(1)
  else:
   var deadline:int=Time.get_ticks_msec()+2500
   if slot=="skill_2":
    while actor._sky_dive_sub_phase!=2 and Time.get_ticks_msec()<deadline:await frames(1)
    actor._sky_dive_begin_dive()
   else:
    while action.current_phase!=AbilityAction.Phase.ACTIVE and Time.get_ticks_msec()<deadline:await frames(1)
   arena.opponent.health_component.take_damage(1000)
  check(arena.opponent.is_dead and arena.round_state==PracticeArena.RoundState.ENDING,slot+" records lethal result without showing result panel")
  check(action.is_active() and events.cancel==0 and not arena.result_buttons.visible,slot+" killing animation remains active")
  check(not arena.brain.enabled and actor.external_controlled and actor.controls_enabled,slot+" blocks new input without stopping skill simulation")
  var hp:float=actor.health_component.current_health;actor.health_component.take_damage(50)
  check(actor.health_component.current_health==hp,slot+" result HP frozen during presentation")
  arena._schedule_finish()
  var deadline:int=Time.get_ticks_msec()+7000
  while arena.round_state!=PracticeArena.RoundState.FINISHED and Time.get_ticks_msec()<deadline:await frames(1)
  check(events.cancel==0 and events.finish==1,slot+" completes normally rather than cancelling")
  check(arena.result_buttons.visible and arena.center_label.text.contains("BẠN THẮNG") and not paused,slot+" shows victory after completion and releases pause")
  if slot=="ultimate":check(actor.camera.current and not actor.giant_sword_ultimate._presentation_active,"V camera restored before result")
  arena.queue_free();await frames(4)
 var arena:PracticeArena=await room()
 arena.player.transition_to(PlayerController.CombatState.ATTACK)
 arena.opponent.health_component.take_damage(1000);await frames(2)
 check(arena.round_state==PracticeArena.RoundState.ENDING and arena.player.combat_state==PlayerController.CombatState.ATTACK,"Normal finishing slash retains its follow-through")
 var basic_deadline:int=Time.get_ticks_msec()+3000
 while arena.round_state!=PracticeArena.RoundState.FINISHED and Time.get_ticks_msec()<basic_deadline:await frames(1)
 check(arena.round_state==PracticeArena.RoundState.FINISHED,"Normal finishing slash reaches result")
 arena.queue_free();await frames(4)
 arena=await room();arena.opponent.stamina_component.current_stamina=100
 arena.opponent._try_cast_ability("skill_3");var ai_action:AbilityAction=arena.opponent.active_ability_action
 arena.player.health_component.take_damage(1000);await frames(2)
 check(arena.round_state==PracticeArena.RoundState.ENDING and ai_action.is_active(),"AI killing skill also survives round ending")
 var ai_deadline:int=Time.get_ticks_msec()+6000
 while arena.round_state!=PracticeArena.RoundState.FINISHED and Time.get_ticks_msec()<ai_deadline:await frames(1)
 check(not ai_action.is_cancelled and arena.center_label.text.contains("AI THẮNG"),"AI skill completes and correct winner is shown")
 arena.queue_free();await frames(4)
 arena=await room()
 var stuck:=AbilityAction.new();var data:=AbilityData.new();data.startup_duration=100
 stuck.init_action(arena.player,"test",data);arena.player.active_ability_action=stuck
 arena.opponent.health_component.take_damage(1000);await frames(2)
 arena._finish_started_usec-=int(PracticeArena.FINISH_WATCHDOG_SECONDS*1000000)
 await create_timer(.15,true,false,true).timeout
 check(arena.round_state==PracticeArena.RoundState.FINISHED and stuck.is_cancelled,"Watchdog cleans stuck action and shows result")
 arena.queue_free();await frames(4)
 arena=await room();arena.player._try_cast_ability("skill_3");var exiting:AbilityAction=arena.player.active_ability_action
 arena.opponent.health_component.take_damage(1000);await frames(2);arena._prepare_scene_exit()
 check(exiting.is_cancelled and not paused,"Explicit scene exit cancels safely while ending")
 arena.queue_free();await frames(8)
 print("RESULTS: %d/%d PASSED"%[passed,passed+failed]);quit(1 if failed else 0)

