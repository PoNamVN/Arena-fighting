extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15C: KNIGHT PERFECT DODGE COUNTER TEST")
	print("==================================================")
	call_deferred("_run_all_tests")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] %s" % msg)
	else:
		_failures += 1
		print("[FAIL] %s" % msg)


func _trigger_perfect_dodge(p: PlayerController, dc: DodgeController, payload: AttackPayload) -> void:
	CombatTimeManager.reset_time()
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.global_position = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.visuals.rotation.y = 0.0
	p._camera_yaw = 0.0
	p._try_dodge()
	for i in range(6):
		await p.get_tree().physics_frame
	p.take_damage(payload)


func _run_all_tests() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: Node3D = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.find_child("Player", true, false) as PlayerController
	assert_true(p != null, "TEST 0a: Player exists in arena")

	var dc: DodgeController = p.dodge_controller
	assert_true(dc != null, "TEST 0b: DodgeController exists on Player")

	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	assert_true(dummy != null, "TEST 0c: TrainingDummy exists in arena")

	# Baseline setup
	CombatTimeManager.reset_time()
	dc.dodge_duration = 0.25
	dc.iframe_start = 0.05
	dc.iframe_end = 0.20
	p.stamina_component.current_stamina = 100.0
	p.global_position = Vector3(0, 0, 0)
	p.visuals.rotation.y = 0.0
	p._camera_yaw = 0.0
	dummy.global_position = Vector3(0, 0, -4.0) # 4m North of player
	dummy.reset_dummy()
	await process_frame

	var atk_pos: Vector3 = p.global_position + Vector3(0, 0, -2.0)
	var payload: AttackPayload = AttackPayload.new(25.0, atk_pos, 15.0, true, true, 25.0)

	# =========================================================================
	# TEST 1 & 2: Confirmed Perfect Dodge opens Counter Window (0.6s)
	# =========================================================================
	await _trigger_perfect_dodge(p, dc, payload)

	assert_true(p.is_counter_window_active(), "TEST 1b: Confirmed Perfect Dodge opens Counter Window")
	assert_true(dc.counter_window_active, "TEST 1c: DodgeController counter_window_active is true")
	assert_true(abs(dc.counter_window_duration - 0.6) < 0.05, "TEST 2: Counter Window duration is 0.6s")

	# =========================================================================
	# TEST 3: Counter Window expires after ~0.6s
	# =========================================================================
	dc._physics_process(0.65)
	assert_true(not p.is_counter_window_active(), "TEST 3: Counter Window expires after 0.6s")

	# =========================================================================
	# TEST 4: Normal Dodge cannot counter
	# =========================================================================
	CombatTimeManager.reset_time()
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.global_position = Vector3.ZERO
	p._try_dodge()
	for i in range(16):
		await p.get_tree().physics_frame
	assert_true(not p.is_counter_window_active(), "TEST 4a: Normal Dodge does not open Counter Window")
	var counter_started: bool = p.try_counter_attack(true)
	assert_true(not counter_started, "TEST 4b: Normal Dodge cannot start Counter attack")

	# =========================================================================
	# TEST 5: Missed / Non-dodgeable attack cannot counter
	# =========================================================================
	CombatTimeManager.reset_time()
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.global_position = Vector3.ZERO
	p._try_dodge()
	for i in range(6):
		await p.get_tree().physics_frame
	var non_dodgeable_payload: AttackPayload = AttackPayload.new(10.0, atk_pos, 10.0, false, false, 0.0)
	p.take_damage(non_dodgeable_payload)
	assert_true(not p.is_counter_window_active(), "TEST 5: Non-dodgeable attack does not open Counter Window")

	# =========================================================================
	# TEST 6: Death closes Counter Window
	# =========================================================================
	await _trigger_perfect_dodge(p, dc, payload)
	assert_true(p.is_counter_window_active(), "TEST 6a: Counter window active before death")
	# Non-dodgeable lethal damage guarantees death
	var lethal_payload: AttackPayload = AttackPayload.new(999.0, atk_pos, 0.0, false, false, 0.0)
	p.take_damage(lethal_payload)
	assert_true(p.combat_state == PlayerController.CombatState.DEAD, "TEST 6b: Player is DEAD")
	assert_true(not p.is_counter_window_active(), "TEST 6c: Death closes Counter Window immediately")

	# Respawn player for further tests
	p.respawn(Vector3.ZERO, 0.0)
	await process_frame
	assert_true(p.combat_state == PlayerController.CombatState.IDLE, "TEST 6d: Player respawned in IDLE")

	# =========================================================================
	# TEST 7: No valid target → no Counter
	# =========================================================================
	dummy.global_position = Vector3(0, 0, -50.0)
	await process_frame
	await _trigger_perfect_dodge(p, dc, payload)
	assert_true(p.is_counter_window_active(), "TEST 7a: Window opened with no nearby targets")

	var target_found: Node3D = p.find_counter_target(8.0)
	assert_true(target_found == null, "TEST 7b: find_counter_target returns null when no target in range")
	var lmb_res: bool = p.try_counter_attack(true)
	assert_true(not lmb_res, "TEST 7c: try_counter_attack returns false when no valid target")
	assert_true(p.combat_state != PlayerController.CombatState.COUNTER, "TEST 7d: Player did not enter COUNTER state")

	# =========================================================================
	# TEST 8: Target outside 8m → no Counter
	# =========================================================================
	p.global_position = Vector3.ZERO
	dummy.global_position = Vector3(0, 0, -10.0) # 10m away
	await process_frame
	var target_8m: Node3D = p.find_counter_target(8.0)
	assert_true(target_8m == null, "TEST 8a: Target at 10m is outside 8m range limit")
	assert_true(not p.try_counter_attack(true), "TEST 8b: No counter triggered for target outside 8m")

	# =========================================================================
	# TEST 9: Dead target → ignored
	# =========================================================================
	dummy.global_position = Vector3(0, 0, -4.0) # 4m away
	dummy.take_damage(100.0) # Defeat dummy
	await process_frame
	assert_true(dummy.is_dead(), "TEST 9a: Dummy is dead")
	assert_true(not dummy.is_targetable(), "TEST 9b: Dead dummy is not targetable")
	var dead_target: Node3D = p.find_counter_target(8.0)
	assert_true(dead_target == null, "TEST 9c: Dead target within 8m is ignored")

	# Reset dummy to alive
	dummy.reset_dummy()
	await process_frame
	assert_true(dummy.is_alive(), "TEST 9d: Dummy is alive again")

	# =========================================================================
	# TEST 10: Valid target inside 8m → acquired
	# =========================================================================
	p.global_position = Vector3.ZERO
	dummy.global_position = Vector3(0, 0, -4.0)
	await process_frame
	var valid_target: Node3D = p.find_counter_target(8.0)
	assert_true(valid_target == dummy, "TEST 10: Valid target at 4m is acquired")

	# =========================================================================
	# TEST 11: LMB requires new press (held input rejected)
	# =========================================================================
	await _trigger_perfect_dodge(p, dc, payload)
	assert_true(p.is_counter_window_active(), "TEST 11a: Counter window open")
	var held_lmb: bool = p.try_counter_attack(false) # Not a new press
	assert_true(not held_lmb, "TEST 11b: Held LMB (is_new_press=false) is rejected")
	assert_true(p.is_counter_window_active(), "TEST 11c: Window remains open after rejected held input")

	# =========================================================================
	# TEST 12 & 13: LMB during Counter Window starts Counter & consumes window
	# =========================================================================
	var pre_counter_step: int = p.combo_step
	var counter_ok: bool = p.try_counter_attack(true)
	assert_true(counter_ok, "TEST 12a: try_counter_attack succeeds with valid target")
	assert_true(p.combat_state == PlayerController.CombatState.COUNTER, "TEST 12b: Player entered COUNTER state")
	assert_true(not p.is_counter_window_active(), "TEST 13: Counter Window is consumed immediately upon counter start")
	assert_true(p.combo_step == 0, "TEST 14: Basic combo reset cleanly on counter start (was %d)" % pre_counter_step)

	# =========================================================================
	# TEST 15 & 16: Knight lunges toward target via physics (not teleport)
	# =========================================================================
	var initial_pos: Vector3 = p.global_position
	var pos_samples: Array[Vector3] = []
	for i in range(6):
		await p.get_tree().physics_frame
		pos_samples.append(p.global_position)

	var moved_dist: float = (p.global_position - initial_pos).length()
	assert_true(moved_dist > 0.2, "TEST 15: Knight actually moves toward target (Dist: %.2fm)" % moved_dist)

	var max_step_dist: float = 0.0
	for i in range(1, pos_samples.size()):
		var step_d: float = (pos_samples[i] - pos_samples[i-1]).length()
		if step_d > max_step_dist:
			max_step_dist = step_d
	assert_true(max_step_dist < 2.5, "TEST 16: Knight does not teleport (Max frame step: %.2fm)" % max_step_dist)

	# =========================================================================
	# TEST 17: Knight faces target during lunge
	# =========================================================================
	var dummy_pos: Vector3 = dummy.global_position
	var to_dummy: Vector3 = (dummy_pos - p.global_position).normalized()
	to_dummy.y = 0.0
	var expected_yaw: float = atan2(-to_dummy.x, -to_dummy.z)
	assert_true(abs(p.visuals.rotation.y - expected_yaw) < 0.2, "TEST 17: Knight faces target during lunge")

	# =========================================================================
	# TEST 18: Counter does not inherit/extend Dodge i-frame
	# =========================================================================
	assert_true(not p.is_in_dodge_iframe(), "TEST 18a: Counter does not inherit Dodge i-frame")
	assert_true(not p.is_invulnerable, "TEST 18b: Player is not invulnerable during Counter")

	# =========================================================================
	# TEST 19, 20, 21: Counter deals expected damage (50) & single event
	# =========================================================================
	var dummy_hp_before: float = dummy.current_hp
	# Wait for lunge arrival and strike
	for i in range(20):
		await p.get_tree().physics_frame

	var dummy_hp_after: float = dummy.current_hp
	var dmg_dealt: float = dummy_hp_before - dummy_hp_after
	assert_true(abs(dmg_dealt - 50.0) < 0.1, "TEST 19: Counter attack deals expected 50 damage (HP: %.1f -> %.1f)" % [dummy_hp_before, dummy_hp_after])

	# Wait additional frames, verify no duplicate damage
	for i in range(10):
		await p.get_tree().physics_frame
	var dummy_hp_stable: float = dummy.current_hp
	assert_true(dummy_hp_stable == dummy_hp_after, "TEST 20: Exactly one damage event per counter (HP remains %.1f)" % dummy_hp_stable)

	# Wait for counter recovery to finish and return to IDLE
	var timeout: int = 30
	while p.combat_state == PlayerController.CombatState.COUNTER and timeout > 0:
		await p.get_tree().physics_frame
		timeout -= 1
	assert_true(p.combat_state == PlayerController.CombatState.IDLE, "TEST 21a: Counter returns to IDLE after recovery")
	assert_true(p.combo_step == 0, "TEST 21b: Combo step remains 0 after Counter completes")

	# =========================================================================
	# TEST 22 & 23: Second counter attack reduces Dummy HP to 0 -> Death
	# =========================================================================
	p.global_position = Vector3(0, 0, 0)
	dummy.global_position = Vector3(0, 0, -3.5)
	await process_frame
	await _trigger_perfect_dodge(p, dc, payload)
	assert_true(p.is_counter_window_active(), "TEST 22a: Second counter window open")

	var counter2_ok: bool = p.try_counter_attack(true)
	assert_true(counter2_ok, "TEST 22b: Second counter attack started")

	# Wait for lunge and strike
	for i in range(25):
		await p.get_tree().physics_frame

	assert_true(dummy.current_hp == 0.0, "TEST 23a: Dummy HP reached 0 (Current: %.1f)" % dummy.current_hp)
	assert_true(dummy.is_dead(), "TEST 23b: Dummy enters death state at 0 HP")

	# =========================================================================
	# TEST 24 & 25: Auto respawn after ~1.5s restores full HP & targetable
	# =========================================================================
	assert_true(not dummy.is_targetable(), "TEST 24a: Dead dummy is not targetable")
	# Wait for dummy auto-respawn (~1.5s)
	await create_timer(dummy.reset_delay + 0.3).timeout
	assert_true(dummy.current_hp == 100.0, "TEST 24b: Dummy respawns with full 100 HP (Current: %.1f)" % dummy.current_hp)
	assert_true(not dummy.is_dead(), "TEST 24c: Dummy is no longer dead")
	assert_true(dummy.is_targetable(), "TEST 25: Respawed dummy is targetable again")

	# =========================================================================
	# SUMMARY
	# =========================================================================
	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")

	quit(0 if _failures == 0 else 1)
