extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15C-FIX: TRAINING DUMMY HP BAR TEST")
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
	assert_true(p != null, "TEST 0a: Player exists in arena")

	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	assert_true(dummy != null, "TEST 0b: TrainingDummy exists in arena")

	var sprite: Sprite3D = dummy.get_node_or_null("HealthBarSprite") as Sprite3D
	assert_true(sprite != null, "TEST 0c: HealthBarSprite exists on TrainingDummy")

	var viewport: SubViewport = dummy.get_node_or_null("HealthBarViewport") as SubViewport
	assert_true(viewport != null, "TEST 0d: HealthBarViewport exists on TrainingDummy")

	var bar: ProgressBar = dummy.progress_bar
	assert_true(bar != null, "TEST 0e: ProgressBar exists in SubViewport")

	# =========================================================================
	# TEST 1: Starts at 100%
	# =========================================================================
	assert_true(dummy.max_hp == 100.0, "TEST 1a: TrainingDummy max HP is 100.0")
	assert_true(dummy.current_hp == 100.0, "TEST 1b: TrainingDummy current HP is 100.0")
	assert_true(bar.max_value == 100.0, "TEST 1c: ProgressBar max_value is 100.0")
	assert_true(bar.value == 100.0, "TEST 1d: ProgressBar value is 100.0 (100%)")
	assert_true(sprite.visible, "TEST 1e: HealthBarSprite is visible")
	assert_true(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "TEST 1f: HealthBarSprite billboard faces active camera")
	assert_true(sprite.no_depth_test, "TEST 1g: HealthBarSprite has no_depth_test enabled (prevents occlusion)")

	# =========================================================================
	# TEST 2: Counter dummy (50 damage) → HP bar becomes 50%
	# =========================================================================
	dummy.take_damage(50.0)
	await process_frame
	assert_true(dummy.current_hp == 50.0, "TEST 2a: Dummy current HP is 50.0 after 50 damage")
	assert_true(bar.value == 50.0, "TEST 2b: ProgressBar value updated immediately to 50.0 (50%)")

	# =========================================================================
	# TEST 3: Kill dummy → 0%
	# =========================================================================
	dummy.take_damage(50.0)
	await process_frame
	assert_true(dummy.is_dead(), "TEST 3a: Dummy enters death state at 0 HP")
	assert_true(dummy.current_hp == 0.0, "TEST 3b: Dummy current HP is 0.0")
	assert_true(bar.value == 0.0, "TEST 3c: ProgressBar value is 0.0 (0%) on death")

	# =========================================================================
	# TEST 4: Wait for respawn (~1.5s) → 100%
	# =========================================================================
	await create_timer(dummy.reset_delay + 0.3).timeout
	assert_true(not dummy.is_dead(), "TEST 4a: Dummy respawned and is no longer dead")
	assert_true(dummy.current_hp == 100.0, "TEST 4b: Dummy HP restored to 100.0 on respawn")
	assert_true(bar.value == 100.0, "TEST 4c: ProgressBar value restored to 100.0 (100%) on respawn")

	# =========================================================================
	# TEST 5: Verify FPS & TPS
	# =========================================================================
	# TPS mode
	p.set_third_person(true)
	await process_frame
	assert_true(p.is_third_person, "TEST 5a: TPS mode active")
	assert_true(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "TEST 5b: Billboard active in TPS")
	assert_true(sprite.visible, "TEST 5c: HP bar visible in TPS")

	# FPS mode
	p.set_third_person(false)
	await process_frame
	assert_true(not p.is_third_person, "TEST 5d: FPS mode active")
	assert_true(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "TEST 5e: Billboard active in FPS")
	assert_true(sprite.visible, "TEST 5f: HP bar visible in FPS")

	# Restore TPS
	p.set_third_person(true)
	await process_frame

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")

	quit(0 if _failures == 0 else 1)
