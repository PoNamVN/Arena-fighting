extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15D: STAMINA SYSTEM TEST")
	print("==================================================")
	call_deferred("_run_all_tests")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] %s" % msg)
	else:
		_failures += 1
		print("[FAIL] %s" % msg)


func _run_all_tests() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: Node3D = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.find_child("Player", true, false) as PlayerController
	assert_true(p != null and p.stamina_component != null, "TEST 1: Player and StaminaComponent initialized")

	var sc: StaminaComponent = p.stamina_component

	# 1. Verify No Passive Regen
	sc.current_stamina = 30.0
	await create_timer(0.3).timeout
	assert_true(sc.current_stamina == 30.0, "TEST 2: No passive stamina regeneration")

	# 2. Clamping Tests (0 <= stamina <= max_stamina)
	sc.add_stamina(200.0)
	assert_true(sc.current_stamina == sc.max_stamina, "TEST 3: Stamina clamped to max_stamina (100.0)")

	var consumed_huge: bool = sc.consume_stamina(150.0)
	assert_true(not consumed_huge, "TEST 4: Excessive consumption rejected")
	assert_true(sc.current_stamina == 100.0, "TEST 5: Stamina unchanged on rejected consumption")

	sc.consume_stamina(100.0)
	assert_true(sc.current_stamina == 0.0, "TEST 6: Stamina reaches 0.0 without going negative")

	sc.consume_stamina(10.0)
	assert_true(sc.current_stamina == 0.0, "TEST 7: Consumption at 0 stamina rejected and clamped")

	# 3. Dodge Consumption (Task 5.15B-FIX-2: Dash does NOT consume stamina)
	sc.current_stamina = 50.0
	p._try_dodge()
	assert_true(sc.current_stamina == 50.0, "TEST 8: Dodge does not consume stamina (remains 50.0)")

	# 4. Basic Attack Hit Generation (+15 stamina) & No Duplicate Per Swing
	sc.current_stamina = 10.0
	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	if dummy:
		dummy.global_position = p.global_position + Vector3(0, 0, -1.5)
	await process_frame
	await physics_frame

	p.combat._perform_attack()
	assert_true(sc.current_stamina == 25.0, "TEST 9: Successful basic attack hit generates +15 stamina")

	# Multiple hits simulation: add another dummy nearby from scene
	var dummy_scene: PackedScene = load("res://scenes/TrainingDummy.tscn")
	var dummy2: Node3D = dummy_scene.instantiate()
	arena.add_child(dummy2)
	dummy2.global_position = p.global_position + Vector3(0.5, 0, -1.5)
	await process_frame
	await physics_frame

	# Simulate attack with 2 targets in range: stamina should increase by only +15 (not +30)
	var stamina_before_double: float = sc.current_stamina
	p.combat._perform_attack()
	assert_true(sc.current_stamina == stamina_before_double + 15.0, "TEST 10: No duplicate stamina generation on multi-target swing")
	dummy2.queue_free()

	# 5. Skills Stamina Consumption
	var thrust_cost: float = p.ability_system.get_ability("skill_1").stamina_cost
	sc.current_stamina = 50.0
	var cast_success: bool = p.ability_system.cast_ability("skill_1")
	assert_true(cast_success, "TEST 11: Skill 1 cast successful")
	assert_true(sc.current_stamina == 50.0 - thrust_cost, "TEST 12: Skill 1 consumed accurate stamina")

	# 6. Ultimate 100% Stamina Requirement
	sc.current_stamina = 99.0
	var ult_rejected: bool = p.ability_system.cast_ability("ultimate")
	assert_true(not ult_rejected, "TEST 13: Ultimate rejected below 100 stamina")
	assert_true(sc.current_stamina == 99.0, "TEST 14: Stamina unchanged on rejected Ultimate")

	sc.current_stamina = 100.0
	var ult_accepted: bool = p.ability_system.cast_ability("ultimate")
	assert_true(ult_accepted, "TEST 15: Ultimate accepted at 100 stamina")
	assert_true(sc.current_stamina == 0.0, "TEST 16: Ultimate consumes 100 stamina on successful cast")

	# 7. Reset on Death & Respawn
	sc.current_stamina = 65.0
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(sc.current_stamina == 0.0, "TEST 17: Stamina reset to initial (0.0) on death")

	p.respawn()
	assert_true(sc.current_stamina == 0.0, "TEST 18: Stamina remains cleanly reset on respawn")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
