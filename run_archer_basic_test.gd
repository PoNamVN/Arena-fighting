extends SceneTree
var passed: int = 0
var total: int = 0
var arena: Node3D
var player: PlayerController
var enemy: PlayerController

func _init() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	total += 1
	if value:
		passed += 1
	print("[%s] TEST %d: %s" % ["PASS" if value else "FAIL", total, description])

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func action(name: String, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = name
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func fresh() -> void:
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await frames(2)
	player = load("res://scenes/Player.tscn").instantiate() as PlayerController
	player.hero_profile = "archer"
	player.position = Vector3(0, 0.1, 3)
	arena.add_child(player)
	enemy = load("res://scenes/Player.tscn").instantiate() as PlayerController
	enemy.external_controlled = true
	enemy.position = Vector3(0, 0.1, -5)
	enemy.collision_layer = 4
	enemy.collision_mask = 3
	enemy.get_node("HealthComponent").max_health = 500.0
	arena.add_child(enemy)
	await frames(5)
	player.stamina_component.current_stamina = 0.0

func fire(charge_frames: int = 75) -> void:
	action("attack", true)
	await frames(charge_frames)
	action("attack", false)
	await frames(1)

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await fresh()
	var bow: ArcherCombat = player.archer_combat
	check(bow != null and enemy.archer_combat == null, "Archer kit isolated from Knight")
	check(player.anim_player.has_animation("run") and player._skeleton.get_bone_count() == 18, "Separate hunter model preserves locomotion and rig")
	check(player.ability_system.get_ability("skill_1").id == "archer_rapid_volley" and player.ability_system.get_ability("ultimate").id == "archer_trex_bait", "Archer loadout cannot cast Knight skills")
	check(player._start_block() and is_equal_approx(player.block_damage_reduction, 0.65), "Archer guards with weaker bow block")
	player._release_block()
	action("attack", true)
	await frames(8)
	check(bow.charging and bow.locked_target == enemy, "Real LMB press charges and acquires visible enemy")
	check(bow.shots_fired == 0 and is_equal_approx(enemy.health_component.current_health, 500), "Holding does not cause melee or auto fire")
	await frames(90)
	check(is_equal_approx(bow.charge_time, bow.MAX_CHARGE), "Charge caps while held")
	action("attack", false)
	await frames(1)
	check(bow.shots_fired == 1 and bow._arrows.size() == 1, "Release creates one moving arrow")
	check(is_equal_approx(enemy.health_component.current_health, 500), "Release does not deal hitscan damage")
	await frames(25)
	check(is_equal_approx(enemy.health_component.current_health, 464), "Fully charged physical arrow deals 36 damage once")
	check(is_equal_approx(player.stamina_component.current_stamina, 15), "Only actual hit awards 15 energy")
	await fire(1)
	await frames(35)
	check(enemy.health_component.current_health < 464 and enemy.health_component.current_health > 449, "Quick release deals less damage than full charge")
	await fresh()
	bow = player.archer_combat
	enemy.visuals.rotation.y = PI
	enemy._camera_yaw = PI
	check(enemy._start_block(), "Knight prepares front shield")
	await fire()
	await frames(25)
	check(is_equal_approx(enemy.health_component.current_health, 494.6), "Front block reduces arrow damage exactly once")
	check(is_equal_approx(enemy.shield_durability, 85), "Arrow consumes one shield hit")
	await fresh()
	bow = player.archer_combat
	await fire()
	enemy.position.x = 3.0
	await frames(30)
	check(is_equal_approx(enemy.health_component.current_health, 500), "Target can sidestep after release; normal arrow does not home")
	await frames(100)
	check(bow._arrows.is_empty(), "Missed projectile expires within range")
	await fresh()
	bow = player.archer_combat
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(5, 4, 0.2)
	collision.shape = box
	wall.add_child(collision)
	arena.add_child(wall)
	wall.position = Vector3(0, 2, 0)
	await frames(3)
	action("attack", true)
	await frames(8)
	check(bow.locked_target == null, "World wall prevents aim lock")
	action("attack", false)
	await frames(25)
	check(is_equal_approx(enemy.health_component.current_health, 500) and bow._arrows.is_empty(), "Swept projectile stops at wall")
	wall.queue_free()
	await fresh()
	bow = player.archer_combat
	action("attack", true)
	await frames(6)
	player._set_mouse_captured(false)
	action("attack", false)
	check(not bow.charging and bow.shots_fired == 0, "Esc / cursor release cancels rather than fires")
	player._set_mouse_captured(true)
	action("attack", true)
	await frames(5)
	player.apply_hit_reaction(Vector3.BACK)
	action("attack", false)
	check(not bow.charging and bow.shots_fired == 0, "Taking a hit cancels charged shot")
	await frames(15)
	player.stamina_component.current_stamina = 100
	action("attack", true)
	await frames(3)
	check(player._try_dodge() and not bow.charging, "Q dodge interrupts charge using normal energy cost")
	action("attack", false)
	await frames(45)
	player.set_third_person(false)
	await fire()
	await frames(25)
	check(bow.hits_landed == 1 and not player.is_third_person, "FPS charge and release works")
	await fresh()
	bow = player.archer_combat
	enemy.position.z = 8.0
	await frames(2)
	check(bow.start_charge() and bow.locked_target == null, "Enemy behind camera is not auto targeted")
	bow.cancel_charge()
	enemy.position.z = -24.0
	await frames(2)
	bow.start_charge()
	check(bow.locked_target == null, "Enemy outside 24 meters is not auto targeted")
	bow.cancel_charge()
	enemy.position.z = -5.0
	await frames(2)
	bow.start_charge()
	check(bow.locked_target == enemy, "Visible target is reacquired on new charge")
	wall = StaticBody3D.new()
	arena.add_child(wall)
	wall.collision_layer = 1
	collision = CollisionShape3D.new()
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 2, 0)
	await frames(4)
	check(bow.locked_target == null, "New wall during hold immediately drops lock")
	bow.release_arrow()
	await frames(25)
	check(is_equal_approx(enemy.health_component.current_health, 500), "Release after lost visibility cannot damage through wall")
	wall.queue_free()
	await frames(5)
	bow.start_charge()
	enemy.health_component.take_damage(1000)
	await frames(3)
	check(bow.locked_target == null, "Death during hold drops target")
	bow.cancel_charge()
	await fresh()
	bow = player.archer_combat
	await fire()
	check(not bow.start_charge(), "Release recovery prevents shot spam")
	await frames(5)
	# Keep receiver in the flight path to verify the real timed i-frame window.
	enemy.dodge_controller.dodge_distance = 0.0
	enemy.stamina_component.current_stamina = 100
	check(enemy._try_dodge(), "Receiver starts actual timed dodge")
	await frames(25)
	check(is_equal_approx(enemy.health_component.current_health, 500) and bow.hits_landed == 0 and enemy.dodge_controller.perfect_dodge_count == 1, "Timed dodge negates arrow and rewards receiver, not attacker")
	await fresh()
	bow = player.archer_combat
	await fire()
	player.controls_enabled = false
	await frames(30)
	check(bow._arrows.is_empty() and is_equal_approx(enemy.health_component.current_health, 500), "Round end cancels in-flight arrows before damage")
	player.controls_enabled = true
	await fire(8)
	player.health_component.take_damage(1000)
	await frames(5)
	check(player.is_dead and bow._arrows.is_empty() and not bow.charging, "Death clears charge and projectiles")
	arena.queue_free()
	await frames(3)
	PracticeArena.selected_hero = "archer"
	var practice: PracticeArena = load("res://scenes/PracticeArena.tscn").instantiate() as PracticeArena
	root.add_child(practice)
	await frames(5)
	check(practice.player.archer_combat != null and practice.opponent.archer_combat == null, "Practice selection spawns hunter versus Knight")
	check(not practice.player.archer_combat.start_charge(), "Countdown rejects archer charge")
	practice._begin_fight()
	practice.brain.enabled = false
	check(practice.player.archer_combat.start_charge(), "Fight unlocks archer control")
	practice._finish_round()
	check(not practice.player.archer_combat.charging and not practice.player.controls_enabled, "Result clears charge immediately")
	practice.queue_free()
	await frames(3)
	var test_arena: CombatTestArena = load("res://scenes/CombatTestArena.tscn").instantiate() as CombatTestArena
	root.add_child(test_arena)
	current_scene = test_arena
	await frames(5)
	check(test_arena.player.archer_combat != null and test_arena.hero_select.selected == 1, "Arena Test applies selected hunter before child ready")
	# Exercise the selector's connected UI signal and actual scene reload.
	test_arena.hero_select.select(0)
	test_arena.hero_select.item_selected.emit(0)
	await frames(6)
	test_arena = current_scene as CombatTestArena
	check(test_arena.player.archer_combat == null and test_arena.player.ability_system.get_ability("skill_1").id == "shield_charge", "Selector switches back to complete Knight kit")
	test_arena.hero_select.select(1)
	test_arena.hero_select.item_selected.emit(1)
	await frames(6)
	test_arena = current_scene as CombatTestArena
	check(test_arena.player.archer_combat != null and test_arena.player._is_mouse_captured, "Selector reloads hunter and restores gameplay camera control")
	test_arena.practice_button.pressed.emit()
	await frames(6)
	practice = current_scene as PracticeArena
	check(practice != null and practice.player.archer_combat != null, "Practice button carries selected hunter into match")
	practice._begin_fight()
	practice._finish_round()
	practice.replay()
	await frames(6)
	practice = current_scene as PracticeArena
	check(practice.player.archer_combat != null and practice.round_state == PracticeArena.RoundState.COUNTDOWN, "Replay keeps hero and starts clean countdown")
	practice.return_to_test()
	await frames(6)
	test_arena = current_scene as CombatTestArena
	check(test_arena.player.archer_combat != null and test_arena.hero_select.selected == 1, "Return keeps selected hero in Arena Test")
	PracticeArena.selected_hero = "knight"
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
