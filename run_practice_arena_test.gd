extends SceneTree
var passed: int = 0
var total: int = 0

func _init() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	total += 1
	if value:
		passed += 1
	print("[%s] TEST %d: %s" % ["PASS" if value else "FAIL", total, description])

func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func key(arena: CombatTestArena, code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	arena._input(event)

func _run() -> void:
	root.size = Vector2i(1152, 720)
	var test_arena: CombatTestArena = load("res://scenes/CombatTestArena.tscn").instantiate()
	root.add_child(test_arena)
	await frames(5)
	test_arena.attack_dummy.auto_attack = false
	test_arena.attack_dummy.cancel_attack()
	var human: PlayerController = test_arena.player
	check(test_arena.practice_button.text.contains("ĐẤU TẬP"), "Practice entry button exists")
	check(not human.stamina_component.training_infinite and not human.health_component.training_invulnerable and not test_arena.no_cooldowns, "Cheats default OFF")
	key(test_arena, KEY_F1)
	check(human.stamina_component.consume_stamina(100) and human.stamina_component.is_full(), "F1 preserves full stamina including ultimate cost")
	key(test_arena, KEY_F1)
	check(human.stamina_component.consume_stamina(20) and is_equal_approx(human.stamina_component.current_stamina, 80), "F1 OFF restores normal consumption")
	key(test_arena, KEY_F2)
	check(human.ability_system.cast_ability("skill_1") and not human.ability_system.is_on_cooldown("skill_1"), "F2 clears cast cooldown")
	key(test_arena, KEY_F2)
	check(human.ability_system.cast_ability("skill_1") and human.ability_system.is_on_cooldown("skill_1"), "F2 OFF restores cooldown")
	key(test_arena, KEY_F3)
	human.health_component.take_damage(1000)
	check(not human.is_dead and is_equal_approx(human.health_component.current_health, 100), "F3 prevents lethal HP damage")
	key(test_arena, KEY_F3)
	human.health_component.take_damage(5)
	check(is_equal_approx(human.health_component.current_health, 95), "F3 OFF restores damage")
	test_arena.queue_free()
	await frames(2)
	var arena: PracticeArena = load("res://scenes/PracticeArena.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	check(arena.find_child("TrainingDummy", true, false) == null and arena.find_child("AttackTrainingDummy", true, false) == null, "Empty arena has no training dummies")
	check(arena.player != arena.opponent and arena.opponent.external_controlled, "Only human and separate AI combatants")
	check(root.get_camera_3d() == arena.player.camera, "AI does not steal player camera")
	check(not arena.player.controls_enabled and not arena.brain.enabled, "Countdown locks player and AI")
	check(not arena.player._try_combat_attack() and not arena.player._try_cast_ability("skill_1"), "Countdown rejects attacks and skills")
	check(not arena.player.stamina_component.training_infinite and not arena.player.health_component.training_invulnerable, "Arena Test cheats do not leak into practice")
	check(arena.countdown_remaining < 3 and arena.countdown_remaining > 0, "Intro countdown advances")
	await frames(190)
	check(arena.round_state == PracticeArena.RoundState.FIGHT and arena.brain.enabled, "3-2-1 starts real match")
	check(arena.time_remaining < 90 and arena.time_remaining > 85, "Match timer counts down")
	var start_distance: float = arena.player.global_position.distance_to(arena.opponent.global_position)
	await frames(110)
	check(arena.player.global_position.distance_to(arena.opponent.global_position) < start_distance, "AI moves toward player")
	await frames(180)
	check(arena.brain.attacks_started > 0 and arena.player.health_component.current_health < 200, "AI attacks deal actual damage")
	# Isolate two-way melee blocking through the real shared impact query.
	arena.brain.enabled = false
	await frames(100)
	arena.player.reset_shield_for_new_round()
	arena.player.global_position = Vector3(0, 0.1, 10)
	arena.opponent.global_position = Vector3(0, 0.1, 8.4)
	arena.player._camera_yaw = 0
	arena.player.camera_pivot.rotation.y = 0
	arena.player.visuals.rotation.y = 0
	arena.opponent._camera_yaw = PI
	arena.opponent.camera_pivot.rotation.y = PI
	arena.opponent.visuals.rotation.y = PI
	await frames(3)
	check(arena.player._start_block(), "Player can defend against AI")
	var hp_before: float = arena.player.health_component.current_health
	arena.opponent.combat._damage_applied_this_swing = false
	arena.opponent.combat.execute_impact()
	check(is_equal_approx(hp_before - arena.player.health_component.current_health, 3.75), "Blocked melee reduces damage once (25 to 3.75)")
	check(is_equal_approx(arena.player.shield_durability, 85), "Blocked melee removes shield once (15)")
	arena.player._release_block()
	arena.player.health_component.reset_health()
	await frames(50)
	arena.opponent.health_component.reset_health()
	arena.time_remaining = 0.04
	await frames(8)
	check(arena.round_state == PracticeArena.RoundState.FINISHED and arena.center_label.text.contains("HÒA"), "Equal HP at timeout produces draw")
	check(not arena.brain.enabled and not arena.player.controls_enabled and arena.result_buttons.visible, "Result freezes combat and exposes replay buttons")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Result restores cursor")
	arena.queue_free()
	await frames(3)
	arena = load("res://scenes/PracticeArena.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	check(arena.round_state == PracticeArena.RoundState.COUNTDOWN and is_equal_approx(arena.time_remaining, 90), "Fresh round resets timer, health and intro")
	arena._begin_fight()
	arena.opponent.health_component.take_damage(1000)
	await frames(3)
	check(arena.round_state == PracticeArena.RoundState.FINISHED and arena.center_label.text.contains("BẠN THẮNG"), "AI defeat produces player victory")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d / %d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
