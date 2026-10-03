extends "res://run_archer_volley_test.gd"

func fresh_ultimate() -> ArcherBaitUltimate:
	CombatTimeManager.reset_time()
	await fresh_volley()
	return player.archer_combat.bait_ultimate

func launch(ultimate: ArcherBaitUltimate, point: Vector3 = Vector3(0,0,-5)) -> bool:
	if not ultimate.begin():
		return false
	await frames(25)
	return ultimate.confirm(point)

func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var ult: ArcherBaitUltimate = await fresh_ultimate()
	player.stamina_component.current_stamina = 99
	check(not ult.begin() and not ult.active(), "Ultimate requires full energy")
	player.stamina_component.current_stamina = 100
	action("ultimate",true)
	action("ultimate",false)
	await frames(2)
	check(ult.phase == ArcherBaitUltimate.Phase.AIM and ult.camera.current and not player._is_mouse_captured, "Real V opens targeting camera and cursor")
	check(player.stamina_component.current_stamina == 100, "Aiming reserves no energy")
	check(not ult.confirm(Vector3(0,0,-5)), "Entry click cannot skip camera transition")
	await frames(25)
	check(not ult.confirm(Vector3(0,0,-30)) and player.stamina_component.current_stamina == 100, "Out-of-range targeting spends nothing")
	action("ui_cancel",true)
	action("ui_cancel",false)
	await frames(1)
	check(not ult.active() and player.camera.current and player._is_mouse_captured and player.stamina_component.current_stamina == 100, "ESC restores camera/cursor without cost")
	ult = await fresh_ultimate()
	ult.begin()
	await frames(25)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ult.camera.unproject_position(Vector3(0,0,-5))
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await frames(1)
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	check(ult.phase == ArcherBaitUltimate.Phase.FLIGHT and player.stamina_component.current_stamina == 0 and ult.casts == 1, "Fresh real mouse click launches physical bait and spends100 once")
	check(not ult.begin() and not player.archer_combat.start_charge(), "No cast overlap during throw")
	await frames(45)
	check(ult.tagged == enemy and ult._bait.global_position.distance_to(enemy.global_position+Vector3.UP*1.1) < 0.02, "Enemy inside outline receives attached meat")
	check(enemy.health_component.current_health == 500 and player.health_component.current_health == 100, "Tag itself causes no damage and never harms caster")
	check(player.camera.current and player._is_mouse_captured, "Gameplay camera restored after bait lands")
	check(player.archer_combat.start_charge(), "Caster regains normal actions while dinosaur hunts")
	player.archer_combat.cancel_charge()
	await frames(330)
	check(is_equal_approx(enemy.health_component.current_health,410) and ult.damage_attempts == 3, "T-rex gnaws marked enemy three times for90 total")
	check(not ult.active() and not is_instance_valid(ult._dino) and not is_instance_valid(ult._bait) and not ult._ring.visible, "Dinosaur bait and ring fully cleaned after exit")
	check(player.stamina_component.current_stamina == 0, "Ultimate hits do not refill energy")
	ult = await fresh_ultimate()
	check(await launch(ult,Vector3(5,0,-5)), "Empty ground accepts bait")
	await frames(350)
	check(enemy.health_component.current_health == 500 and ult.damage_attempts == 0 and ult._miss, "Miss branch only eats bait; no unrelated enemy damage")
	ult = await fresh_ultimate()
	check(await launch(ult,Vector3(0,0,3)), "Caster may place bait at own feet")
	await frames(350)
	check(player.health_component.current_health == 100 and ult.tagged == null and ult.damage_attempts == 0, "Caster cannot receive meat or friendly fire")
	ult = await fresh_ultimate()
	await launch(ult)
	await frames(45)
	enemy.position.x = 2
	await frames(350)
	check(enemy.health_component.current_health == 410, "Tagged moving opponent remains attached and chased")
	ult = await fresh_ultimate()
	enemy._camera_yaw = PI
	enemy.visuals.rotation.y = PI
	enemy._start_block()
	await launch(ult)
	await frames(350)
	check(is_equal_approx(enemy.health_component.current_health,486.5) and is_equal_approx(enemy.shield_durability,10), "Knight blocks three bites with90 shield damage")
	ult = await fresh_ultimate()
	ult.begin()
	await frames(25)
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10,5,0.2)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = Vector3(0,2,-1)
	await frames(2)
	check(not ult.confirm(Vector3(0,0,-5)) and player.stamina_component.current_stamina == 100, "Cannot target through world wall")
	ult.stop()
	wall.queue_free()
	ult = await fresh_ultimate()
	await launch(ult)
	await frames(4)
	wall = StaticBody3D.new()
	wall.collision_layer = 1
	collision = CollisionShape3D.new()
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = Vector3(0,2,-1)
	await frames(350)
	check(enemy.health_component.current_health == 500 and ult.damage_attempts == 0, "New wall blocks flying meat and tag does not cross wall")
	wall.queue_free()
	ult = await fresh_ultimate()
	await launch(ult)
	await frames(45)
	enemy.queue_free()
	await frames(350)
	check(not ult.active() and ult.damage_attempts == 0, "Deleted tagged enemy falls back to bait and cleans without stale reference")
	ult = await fresh_ultimate()
	await launch(ult)
	await frames(95)
	check(ult.camera.current and ult._showcase and not ult.input_busy(), "Wide summon camera shows giant T-rex while caster can move")
	player.controls_enabled = false
	await frames(5)
	check(not ult.active() and not is_instance_valid(ult._dino) and not ult._ring.visible and player.camera.current, "Round lock clears summon and restores camera")
	ult = await fresh_ultimate()
	ult.begin()
	await frames(10)
	player.health_component.take_damage(1000)
	await frames(3)
	check(not ult.active() and player.camera.current and player.stamina_component.current_stamina == 0 and ult.casts == 0, "Death during selection closes camera; shared death rule clears energy")
	ult = await fresh_ultimate()
	await launch(ult)
	await frames(95)
	player.health_component.take_damage(1000)
	await frames(3)
	check(not ult.active() and not is_instance_valid(ult._dino) and player.stamina_component.current_stamina == 0, "Death after commit removes summon without refund")
	ult = await fresh_ultimate()
	ult.begin()
	await frames(25)
	player.apply_hit_reaction(Vector3.BACK)
	check(not ult.active() and player.camera.current and player.stamina_component.current_stamina == 100, "Hit interrupts selection without spending energy")
	ult = await fresh_ultimate()
	await launch(ult)
	for frame: int in range(200):
		if ult.phase == ArcherBaitUltimate.Phase.BITE:
			break
		await frames(1)
	await frames(20)
	enemy.stamina_component.current_stamina = 100
	enemy.dodge_controller.dodge_distance = 0
	check(enemy._try_dodge(), "Defender can dodge during bite telegraph")
	await frames(5)
	ult._bite()
	check(enemy.health_component.current_health == 500 and enemy.is_counter_window_active(), "Bite respects real i-frame and Perfect Dodge")
	ult = await fresh_ultimate()
	await launch(ult)
	for frame: int in range(200):
		if ult.phase == ArcherBaitUltimate.Phase.BITE:
			break
		await frames(1)
	enemy.position.x = 8
	await frames(180)
	check(enemy.health_component.current_health == 500 and ult.damage_attempts == 0, "Escaping mouth area avoids committed bites")
	ult = await fresh_ultimate()
	player.set_third_person(false)
	await launch(ult)
	await frames(350)
	check(enemy.health_component.current_health == 410 and player.camera.current and not player.is_third_person, "FPS Ultimate restores original perspective and deals same damage")
	arena.queue_free()
	await frames(3)
	PracticeArena.selected_hero = "archer"
	var duel: PracticeArena = load("res://scenes/PracticeArena.tscn").instantiate() as PracticeArena
	root.add_child(duel)
	await frames(5)
	var duel_ult: ArcherBaitUltimate = duel.player.archer_combat.bait_ultimate
	duel.player.stamina_component.current_stamina = 100
	check(not duel_ult.begin(), "Practice countdown rejects Ultimate")
	duel._begin_fight()
	duel.brain.enabled = false
	duel.opponent.health_component.current_health = 50
	check(duel_ult.begin(), "Practice fight allows Archer Ultimate")
	await frames(25)
	check(duel_ult.confirm(Vector3(0,0,-8)), "Practice target accepts actual opponent position")
	await frames(350)
	check(duel.round_state == PracticeArena.RoundState.FINISHED and duel.center_label.text.contains("THẮNG") and not duel_ult.active() and duel.player.camera.current and not duel.player._is_mouse_captured, "Lethal bite ends match, clears summon and restores result cursor")
	duel.queue_free()
	await frames(3)
	PracticeArena.selected_hero = "knight"
	CombatTimeManager.reset_time()
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed == total else 1)
