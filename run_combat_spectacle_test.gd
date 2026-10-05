extends "res://run_wizard_foundation_test.gd"

func hero(name: String) -> void:
	await fresh()
	player.queue_free()
	await frames(2)
	player = load("res://scenes/Player.tscn").instantiate() as PlayerController
	player.hero_profile = name
	player.position = Vector3(0, 0.1, 3)
	arena.add_child(player)
	await frames(5)
	player.stamina_component.current_stamina = 100

func capture(name: String, position: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name()=="headless":
		return
	var preview: Camera3D=Camera3D.new()
	arena.add_child(preview)
	preview.position=position
	preview.look_at(target)
	preview.make_current()
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/spectacle_%s.png" % name)
	print("RENDER %s: draw calls=%d primitives=%d" % [name,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	preview.queue_free()
	player.camera.make_current()

func _run() -> void:
	root.size=Vector2i(1152,720)
	arena=load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await hero("wizard")
	var fx: Node=player.spectacle
	check(fx.bursts.size()==6 and not fx.is_processing(), "Fixed six-slot pool sleeps when idle")
	var count: int=fx.get_child_count()
	var hp: float=enemy.health_component.current_health
	var energy: float=player.stamina_component.current_stamina
	for i: int in range(120):
		fx.burst(Vector3(float(i%3)-1,0,-3),Color(0.3,0.65,1),2,1)
	check(fx.get_child_count()==count and fx.bursts.size()==6, "Saturation reuses slots instead of growing node count")
	var spark_count: int=0
	for slot: Dictionary in fx.bursts:
		spark_count += slot.batch.visible_instance_count
	check(spark_count==144, "Spark instances stay capped at144 per actor")
	var origin: Vector3=fx.bursts[0].root.global_position
	player.position.x=3
	check(fx.bursts[0].root.global_position.distance_to(origin)<0.001, "World burst does not follow actor")
	player.position.x=0
	var began: int=Time.get_ticks_usec()
	for i: int in range(200):
		fx._process(0)
	print("Six active bursts CPU: %.3f ms/update" % (float(Time.get_ticks_usec()-began)/200000.0))
	check(is_equal_approx(hp,enemy.health_component.current_health) and is_equal_approx(energy,player.stamina_component.current_stamina), "Visual stress does not alter damage or energy")
	await capture("pool",Vector3(5,4,7),Vector3(0,0,-2))
	await frames(65)
	check(not fx.is_processing() and not fx.bursts[0].root.visible and fx.bursts[0].batch.visible_instance_count==0, "Expired pool hides geometry and stops updates")
	fx.burst(Vector3.ZERO,Color.WHITE)
	player.controls_enabled=false
	await frames(3)
	check(not fx.is_processing() and not fx.bursts[0].root.visible, "Round lock clears visual pool")
	await hero("archer")
	var bow: ArcherCombat=player.archer_combat
	enemy.position.z=-17
	await frames(2)
	check(bow.start_seeking(), "Real X launches homing arrows")
	for i: int in range(60):
		await frames(1)
		if bow._arrows.size()==3 and bow._arrows[0].has("trail_batch"):
			break
	check(bow._arrows.size()==3, "Three physical arrows retained")
	if bow._arrows.size()==3:
		var arrow: Dictionary=bow._arrows[0]
		check(arrow.trail_batch.instance_count==28 and arrow.trail_batch.visible_instance_count<=28, "One MultiMesh stores bounded curved trail")
		var batches: Array[Node]=arrow.node.find_children("*","MultiMeshInstance3D",true,false)
		check(batches.size()==1, "Each arrow uses one trail draw batch")
	for i: int in range(45):
		if bow._arrows.size()!=3 or bow._arrows[0].guide.z < -5:
			break
		await frames(1)
	await capture("spiral",Vector3(3,2,-1),Vector3(0,1,-7))
	bow.reset()
	await frames(3)
	check(bow._arrows.is_empty(), "Arrow reset removes trail batches")
	var ult: ArcherBaitUltimate=bow.bait_ultimate
	player.stamina_component.current_stamina=100
	check(ult.begin(), "Archer Ultimate aim starts")
	await frames(25)
	check(ult.confirm(Vector3(0,0,-5)), "Archer bait confirms")
	for i: int in range(180):
		await frames(1)
		if ult.phase==ArcherBaitUltimate.Phase.BITE and ult.bite_count>=1:
			break
	await capture("trex",Vector3(11,5,10),Vector3(0,2,-5))
	ult.stop()
	await hero("knight")
	check(player._try_cast_ability("skill_1"), "Knight charge starts through existing ability system")
	await frames(20)
	check(player.spectacle._lean < -0.03, "Knight charge gains a blended forward body pose")
	if player.active_ability_action:
		player.active_ability_action.cancel()
	await frames(65)
	check(absf(player.spectacle._lean)<0.002, "Interrupted Knight body pose recovers")
	var sword_fx: GiantSwordVFX=player.combat.giant_sword_vfx
	sword_fx.begin(Vector3(0,0,-5),4.5)
	sword_fx.update_startup(0.35,1.2)
	check(not sword_fx._sigil.visible and sword_fx.ring.visible and sword_fx._fall_wake.visible and sword_fx._fall_particles.emitting and sword_fx.sword.position.y > 0 and sword_fx.sword.position.y < GiantSwordVFX.DROP_HEIGHT, "Giant sword has ground telegraph and descending physical airflow without rune")
	await capture("sword_fall",Vector3(16,20,18),Vector3(0,18,-5))
	sword_fx.impact()
	sword_fx.update_impact(0.18)
	check(sword_fx._burst.active_particles()>0 and sword_fx._burst.active_particles()+64+24<=600 and sword_fx.shockwave.visible and sword_fx._crater.visible and not sword_fx._fall_wake.visible and not sword_fx._fall_particles.emitting, "Sword landing triggers bounded pooled dust/pressure/crater and removes descent wake")
	await frames(10)
	await capture("sword_impact",Vector3(12,8,14),Vector3(0,1,-5))
	sword_fx.stop()
	await hero("wizard")
	var storm: WizardStormUltimate=player.wizard_combat.storm
	check(storm.begin(), "Wizard storm aim starts")
	await frames(25)
	check(storm.confirm(Vector3(0,0,-5)), "Wizard storm confirms")
	await frames(45)
	check(player.spectacle.triggered>0 and storm.strikes_landed>0, "Lightning triggers bounded electric bursts")
	for i: int in range(60):
		var recent: bool=false
		for strike: Dictionary in storm.strikes:
			recent = recent or (strike.hit and storm.elapsed-strike.time < 0.06)
		if recent:
			break
		await frames(1)
	await capture("storm",Vector3(12,13,16),Vector3(0,4,-5))
	storm.stop()
	player.reset_shield_for_new_round()
	check(not player.spectacle.is_processing(), "Round reset clears storm impact remnants")
	arena.queue_free()
	await frames(3)
	CombatTimeManager.reset_time()
	print("RESULTS: %d/%d PASSED" % [passed,self.total])
	quit(0 if passed==self.total else 1)
