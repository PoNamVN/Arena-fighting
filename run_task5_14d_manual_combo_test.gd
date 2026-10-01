extends SceneTree

# ==============================================================================
# Task 5.14D: Manual Click-to-Advance Basic Combo Acceptance Test Suite
# ==============================================================================

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0


func _record_result(test_name: String, condition: bool, details: String = "") -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
		print("[PASS] %s%s" % [test_name, " - " + details if details != "" else ""])
	else:
		_failed_tests += 1
		print("[FAIL] %s%s" % [test_name, " - " + details if details != "" else ""])


func _init() -> void:
	print("\n==================================================")
	print("RUNNING TASK 5.14D ACCEPTANCE TESTS: MANUAL COMBO")
	print("==================================================")
	call_deferred("_run_tests")


func _send_lmb(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _wait_for_attack_impact(p: PlayerController) -> void:
	var safety: int = 150
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _wait_for_attack_finish(p: PlayerController) -> void:
	var safety: int = 300
	while p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _run_tests() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = arena_scene.instantiate() as CombatTestArena
	root.add_child(arena)
	for i in range(10):
		await process_frame

	var p: PlayerController = arena.player
	var td: TrainingDummy = arena.training_dummy

	td.global_position = Vector3(0.0, 0.0, -1.8)
	td.rotation = Vector3.ZERO
	p.set_third_person(true)
	p.global_position = Vector3.ZERO
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	if p.visuals:
		p.visuals.rotation.y = 0.0
	await process_frame

	# -----------------------------------------------------------------
	# TEST 1: Single click starts Attack 1 and no Attack 2/3
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await process_frame

	var t1_started: bool = (p.combat_state == PlayerController.CombatState.ATTACK and p.combo_step == 1)
	await _wait_for_attack_finish(p)
	var t1_ended_clean: bool = (p.combo_step == 1 or p.combo_step == 0) and (p.combat_state != PlayerController.CombatState.ATTACK)
	_record_result("TEST 1: Single click starts Attack 1 and stops", t1_started and t1_ended_clean,
		"Started step 1: %s, Ended clean: %s" % [t1_started, t1_ended_clean])

	# -----------------------------------------------------------------
	# TEST 2: No automatic chain without input (Attack 1 -> STOP)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.3).timeout # wait for any timers to decay
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await _wait_for_attack_impact(p)
	# Wait full animation and recovery timeout
	await create_timer(0.8).timeout
	var t2_pass: bool = (p.combat_state != PlayerController.CombatState.ATTACK and p.combo_step == 0 and td.health_component.current_health == 75.0)
	_record_result("TEST 2: No automatic chain without further input", t2_pass,
		"Final state: %d, Step: %d, HP: %.1f (Expected 1 hit = 75.0)" % [p.combat_state, p.combo_step, td.health_component.current_health])

	# -----------------------------------------------------------------
	# TEST 3: Early click ignored (LMB during windup t < 0.35s)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.1).timeout

	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	# Early click at t ~ 0.10s (windup)
	for i in range(6): await process_frame
	var in_window_early: bool = p.is_in_combo_window()
	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	# Wait until Attack 1 finishes completely
	await _wait_for_attack_finish(p)
	await create_timer(0.4).timeout
	var t3_pass: bool = (not in_window_early) and (td.health_component.current_health == 75.0) and (p.combo_step == 0)
	_record_result("TEST 3: Early click during windup is ignored and does not trigger Attack 2", t3_pass,
		"In window early: %s, Target HP: %.1f (Expected 75.0, 1 hit only)" % [in_window_early, td.health_component.current_health])

	# -----------------------------------------------------------------
	# TEST 4: Multiple early clicks ignored (LMB spam during windup)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.1).timeout

	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	# Spam 4 clicks rapidly within windup phase
	for i in range(4):
		_send_lmb(true)
		await process_frame
		_send_lmb(false)
		await process_frame

	await _wait_for_attack_finish(p)
	await create_timer(0.4).timeout
	var t4_pass: bool = (td.health_component.current_health == 75.0) and (p.combo_step == 0)
	_record_result("TEST 4: Multiple early clicks ignored completely", t4_pass,
		"Target HP: %.1f (Expected 75.0, only 1 hit)" % [td.health_component.current_health])

	# -----------------------------------------------------------------
	# TEST 5: Holding LMB does not advance combo
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.1).timeout

	# Press and HOLD LMB
	_send_lmb(true)
	# Hold for 1.2 seconds across entire attack and recovery
	await create_timer(1.2).timeout
	_send_lmb(false)
	await process_frame

	var t5_pass: bool = (td.health_component.current_health == 75.0) and (p.combat_state != PlayerController.CombatState.ATTACK)
	_record_result("TEST 5: Holding LMB produces only Attack 1 and does not auto-advance", t5_pass,
		"Target HP: %.1f (Expected 75.0), CombatState: %d" % [td.health_component.current_health, p.combat_state])

	# -----------------------------------------------------------------
	# TEST 6: Valid Attack 2 (LMB -> wait for combo window -> new LMB)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.1).timeout

	# Hit 1
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await _wait_for_attack_impact(p) # reaches t = 0.35s impact

	# Wait into recovery / combo window (~0.1s after impact)
	for i in range(6): await process_frame
	var in_window_c1: bool = p.is_in_combo_window()

	# Distinct new LMB press
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await process_frame

	var reached_step_2: bool = (p.combo_step == 2 and p.combat_state == PlayerController.CombatState.ATTACK)
	await _wait_for_attack_impact(p)
	var hp_after_hit2: float = td.health_component.current_health
	var t6_pass: bool = in_window_c1 and reached_step_2 and (hp_after_hit2 == 50.0)
	_record_result("TEST 6: Valid new LMB in combo window triggers Attack 2", t6_pass,
		"In window: %s, Step reached: %d, Target HP: %.1f (Expected 50.0)" % [in_window_c1, p.combo_step, hp_after_hit2])

	# -----------------------------------------------------------------
	# TEST 7: Attack 2 requires another click (stops at Hit 2 if no input)
	# -----------------------------------------------------------------
	await _wait_for_attack_finish(p)
	await create_timer(0.4).timeout
	var t7_pass: bool = (td.health_component.current_health == 50.0) and (p.combat_state != PlayerController.CombatState.ATTACK) and (p.combo_step == 0)
	_record_result("TEST 7: Attack 2 stops cleanly without auto-advancing to Attack 3", t7_pass,
		"Target HP: %.1f (Expected 50.0, 2 hits total), Final step: %d" % [td.health_component.current_health, p.combo_step])

	# -----------------------------------------------------------------
	# TEST 8: Valid Attack 3 (Full manual 3-hit combo)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.1).timeout

	# Hit 1
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await _wait_for_attack_impact(p)
	for i in range(6): await process_frame

	# Hit 2
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await _wait_for_attack_impact(p)
	for i in range(6): await process_frame

	# Hit 3
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await process_frame
	var reached_step_3: bool = (p.combo_step == 3)
	await _wait_for_attack_impact(p)
	var hp_after_hit3: float = td.health_component.current_health
	await _wait_for_attack_finish(p)

	var t8_pass: bool = reached_step_3 and (hp_after_hit3 == 25.0)
	_record_result("TEST 8: Valid Attack 3 manual combo execution (3 hits)", t8_pass,
		"Reached step 3: %s, Target HP: %.1f (Expected 25.0)" % [reached_step_3, hp_after_hit3])

	# -----------------------------------------------------------------
	# TEST 9: Combo reset after timeout
	# -----------------------------------------------------------------
	# Let finisher recovery (0.8s) expire
	await create_timer(0.9).timeout
	td.reset_dummy()

	# Start new attack: must be Attack 1
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await process_frame
	var t9_pass: bool = (p.combo_step == 1)
	await _wait_for_attack_finish(p)
	_record_result("TEST 9: Next attack after combo timeout starts at Attack 1", t9_pass,
		"Step started: %d (Expected 1)" % [p.combo_step])

	# -----------------------------------------------------------------
	# TEST 10: Finisher recovery lockout (0.8s pause after Hit 3)
	# -----------------------------------------------------------------
	p.reset_combo()
	# Execute 3 hits to enter finisher recovery
	p.combo_step = 3
	p._combo_step = 3
	p._on_animation_finished("attack") # completes Hit 3
	var fin_active: bool = (p._combo_finisher_recovery_timer > 0.6)
	var attack_rejected: bool = (not p._try_combat_attack())
	var block_rejected: bool = (not p.transition_to(PlayerController.CombatState.BLOCK))
	var dodge_rejected: bool = (not p.transition_to(PlayerController.CombatState.DODGE))

	var t10_pass: bool = fin_active and attack_rejected and block_rejected and dodge_rejected
	_record_result("TEST 10: 0.8s finisher recovery locks out Attack, Block, and Dodge", t10_pass,
		"Timer active: %s, Attack locked: %s, Block locked: %s, Dodge locked: %s" % [fin_active, attack_rejected, block_rejected, dodge_rejected])
	p._combo_finisher_recovery_timer = 0.0

	# -----------------------------------------------------------------
	# TEST 11: Damage uniqueness (exactly 1 damage event per actual swing)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await create_timer(0.1).timeout

	# Hit 1
	p._try_combat_attack()
	await _wait_for_attack_impact(p)
	var dmg_hit1: float = 100.0 - td.health_component.current_health

	# Hit 2
	for i in range(6): await process_frame
	p._try_combat_attack()
	await _wait_for_attack_impact(p)
	var dmg_hit2: float = 100.0 - td.health_component.current_health

	# Hit 3
	for i in range(6): await process_frame
	p._try_combat_attack()
	await _wait_for_attack_impact(p)
	var dmg_hit3: float = 100.0 - td.health_component.current_health

	await _wait_for_attack_finish(p)
	var t11_pass: bool = (dmg_hit1 == 25.0) and (dmg_hit2 == 50.0) and (dmg_hit3 == 75.0)
	_record_result("TEST 11: Exactly one damage event per actual swing (25 -> 50 -> 75)", t11_pass,
		"Dmg progression: %.1f -> %.1f -> %.1f" % [dmg_hit1, dmg_hit2, dmg_hit3])

	# -----------------------------------------------------------------
	# TEST 12: Death reset
	# -----------------------------------------------------------------
	p._combo_finisher_recovery_timer = 0.0
	p.combo_step = 2
	p._combo_step = 2
	p.transition_to(PlayerController.CombatState.DEAD)
	var step_on_death: int = p.combo_step
	p.respawn()
	var step_after_respawn: int = p.combo_step
	p._try_combat_attack()
	var step_on_new_attack: int = p.combo_step
	await _wait_for_attack_finish(p)

	var t12_pass: bool = (step_on_death == 0) and (step_after_respawn == 0) and (step_on_new_attack == 1)
	_record_result("TEST 12: Death immediately resets combo; respawn starts at Attack 1", t12_pass,
		"Step on death: %d, Step on respawn: %d, New attack step: %d" % [step_on_death, step_after_respawn, step_on_new_attack])

	# -----------------------------------------------------------------
	# TEST 13: Manual combo progression in FPS perspective
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	p.set_third_person(false) # Switch to FPS
	await process_frame

	p._try_combat_attack() # Hit 1
	await _wait_for_attack_impact(p)
	for i in range(6): await process_frame
	p._try_combat_attack() # Hit 2
	await _wait_for_attack_impact(p)
	for i in range(6): await process_frame
	p._try_combat_attack() # Hit 3
	await _wait_for_attack_impact(p)
	await _wait_for_attack_finish(p)

	var t13_pass: bool = (td.health_component.current_health == 25.0)
	_record_result("TEST 13: Manual combo functions in FPS perspective", t13_pass,
		"Dummy HP: %.1f (Expected 25.0)" % [td.health_component.current_health])

	# -----------------------------------------------------------------
	# TEST 14: Manual combo progression in TPS perspective
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	p.set_third_person(true) # Switch back to TPS
	await process_frame

	p._try_combat_attack() # Hit 1
	await _wait_for_attack_impact(p)
	for i in range(6): await process_frame
	p._try_combat_attack() # Hit 2
	await _wait_for_attack_impact(p)
	for i in range(6): await process_frame
	p._try_combat_attack() # Hit 3
	await _wait_for_attack_impact(p)
	await _wait_for_attack_finish(p)

	var t14_pass: bool = (td.health_component.current_health == 25.0)
	_record_result("TEST 14: Manual combo functions in TPS perspective", t14_pass,
		"Dummy HP: %.1f (Expected 25.0)" % [td.health_component.current_health])

	# -----------------------------------------------------------------
	# TEST 15: Stamina generation (+15 per successful hit)
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	p.stamina_component.current_stamina = 10.0
	await create_timer(0.1).timeout

	p._try_combat_attack()
	await _wait_for_attack_impact(p)
	var stm_after_hit1: float = p.stamina_component.current_stamina
	await _wait_for_attack_finish(p)

	var t15_pass: bool = (stm_after_hit1 == 25.0)
	_record_result("TEST 15: Successful basic attack hit generates +15 stamina", t15_pass,
		"Stamina before: 10.0, after: %.1f (Expected 25.0)" % [stm_after_hit1])

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")
	quit(0 if _failed_tests == 0 else 1)
