extends SceneTree

# ==============================================================================
# Acceptance Test Suite for Task 5.14A: Combo Input Buffer
# ==============================================================================

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0


func _record_result(test_name: String, condition: bool, details: String = "") -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
		print("  [PASS] %s%s" % [test_name, " - " + details if details != "" else ""])
	else:
		_failed_tests += 1
		print("  [FAIL] %s%s" % [test_name, " - " + details if details != "" else ""])


func _init() -> void:
	print("\n==================================================")
	print("RUNNING TASK 5.14A ACCEPTANCE TESTS: COMBO INPUT BUFFER")
	print("==================================================")
	call_deferred("_run_tests")


func _send_lmb(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _wait_for_player_attack_impact(p: PlayerController) -> void:
	var safety: int = 150
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _wait_for_player_attack_finish(p: PlayerController) -> void:
	var safety: int = 800
	while p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _run_tests() -> void:
	# -----------------------------------------------------------------
	# TEST 1: Combat Arena and player combat initialized
	# -----------------------------------------------------------------
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = arena_scene.instantiate() as CombatTestArena
	root.add_child(arena)
	for i in range(15):
		await process_frame

	var p: PlayerController = arena.player
	var ad: AttackTrainingDummy = arena.attack_dummy
	var td: TrainingDummy = arena.training_dummy
	var combat: PlayerCombat = p.combat

	# Ensure attack dummy doesn't auto-swing
	ad.set("auto_attack", false)
	var ad_tween: Tween = ad.get("_cycle_tween")
	if ad_tween and ad_tween.is_valid():
		ad_tween.kill()

	var t1_pass: bool = (arena != null and is_instance_valid(arena) and p != null and td != null and combat != null)
	_record_result("TEST 1: Combat Arena and player combat initialized", t1_pass,
		"Player, dummies, and combat systems ready")

	td.global_position = Vector3(3.5, 0, 0)
	td.rotation = Vector3.ZERO
	p.set_third_person(true)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame

	# -----------------------------------------------------------------
	# TEST 2: Rapid human LMB clicks during windup do not buffer combo
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	# Click 1
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	var step_after_c1: int = p.combo_step
	var buf_after_c1: int = p.combo_buffer

	# Click 2 during early windup (~100ms)
	for i in range(6): await process_frame
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	var buf_after_c2: int = p.combo_buffer

	# Click 3 during early windup (~200ms)
	for i in range(6): await process_frame
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	var buf_after_c3: int = p.combo_buffer

	# Track max step reached during execution
	var max_step_t2: int = p.combo_step
	var safety_t2: int = 350
	while p.combat_state == PlayerController.CombatState.ATTACK and safety_t2 > 0:
		if p.combo_step > max_step_t2:
			max_step_t2 = p.combo_step
		await process_frame
		safety_t2 -= 1

	await _wait_for_player_attack_finish(p)
	var dmg_t2: float = 100.0 - td.health_component.current_health
	var t2_pass: bool = (step_after_c1 == 1) and (buf_after_c1 == 0) and (buf_after_c2 == 0) and (buf_after_c3 == 0) and (max_step_t2 == 1) and (dmg_t2 == 25.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 2: Rapid human LMB clicks during windup do not buffer combo", t2_pass,
		"Buffer: %d->%d->%d, Max step: %d, Damage: %.1f (Expected 25.0)" % [buf_after_c1, buf_after_c2, buf_after_c3, max_step_t2, dmg_t2])

	# -----------------------------------------------------------------
	# TEST 3: Spam 10 rapid clicks during windup are ignored without buffering
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	var max_step_t3: int = 0
	# Spam 10 clicks rapidly
	for i in range(10):
		_send_lmb(true)
		await process_frame
		_send_lmb(false)
		await process_frame
		if p.combo_step > max_step_t3:
			max_step_t3 = p.combo_step

	var safety_t3: int = 350
	while p.combat_state == PlayerController.CombatState.ATTACK and safety_t3 > 0:
		if p.combo_step > max_step_t3:
			max_step_t3 = p.combo_step
		await process_frame
		safety_t3 -= 1

	await _wait_for_player_attack_finish(p)
	var dmg_t3: float = 100.0 - td.health_component.current_health
	var t3_pass: bool = (max_step_t3 == 1) and (dmg_t3 == 25.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 3: Spam 10 rapid clicks during windup are ignored without buffering", t3_pass,
		"Max step seen: %d, Damage: %.1f (Expected 25.0 / single hit)" % [max_step_t3, dmg_t3])

	# -----------------------------------------------------------------
	# TEST 4: Single click produces only 1 attack (damage 25.0)
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await _wait_for_player_attack_finish(p)
	var dmg_t4: float = 100.0 - td.health_component.current_health
	var t4_pass: bool = (dmg_t4 == 25.0) and (p.combat_state == PlayerController.CombatState.IDLE) and (p.combo_step == 1)
	_record_result("TEST 4: Single click produces only 1 attack", t4_pass,
		"Damage: %.1f (Expected 25.0), Final state: %s" % [dmg_t4, p.combat_state])

	# -----------------------------------------------------------------
	# TEST 5: Rapid 2 clicks during windup ignores second click
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	for i in range(6): await process_frame
	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	var max_step_t5: int = p.combo_step
	var safety_t5: int = 350
	while p.combat_state == PlayerController.CombatState.ATTACK and safety_t5 > 0:
		if p.combo_step > max_step_t5:
			max_step_t5 = p.combo_step
		await process_frame
		safety_t5 -= 1

	await _wait_for_player_attack_finish(p)
	var dmg_t5: float = 100.0 - td.health_component.current_health
	var t5_pass: bool = (max_step_t5 == 1) and (dmg_t5 == 25.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 5: Rapid 2 clicks during windup ignores second click", t5_pass,
		"Max step seen: %d, Damage: %.1f (Expected 25.0)" % [max_step_t5, dmg_t5])

	# -----------------------------------------------------------------
	# TEST 6: Timed combo clicks still work identically
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	# Wait until anim_pos reaches 0.40s
	var ap: AnimationPlayer = p.anim_player
	var w1: int = 150
	while ap.current_animation_position < 0.40 and p.combat_state == PlayerController.CombatState.ATTACK and w1 > 0:
		await process_frame
		w1 -= 1

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	var w2: int = 150
	while (p.combo_step < 2 or ap.current_animation_position < 0.40) and p.combat_state == PlayerController.CombatState.ATTACK and w2 > 0:
		await process_frame
		w2 -= 1

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	await _wait_for_player_attack_finish(p)
	var dmg_t6: float = 100.0 - td.health_component.current_health
	var t6_pass: bool = (dmg_t6 == 75.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 6: Timed combo clicks still work identically", t6_pass,
		"Damage: %.1f (Expected 75.0)" % dmg_t6)

	# -----------------------------------------------------------------
	# TEST 7: Combo resets after recovery timeout
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await _wait_for_player_attack_finish(p)

	var in_rec_timer: bool = p._combo_recovery_timer > 0.0
	var step_in_rec: int = p.combo_step

	var safety_rec: int = 180
	while p.combo_step != 0 and safety_rec > 0:
		await process_frame
		safety_rec -= 1

	var step_after_rec: int = p.combo_step
	var t7_pass: bool = (step_in_rec == 1) and in_rec_timer and (step_after_rec == 0)
	_record_result("TEST 7: Combo resets after recovery timeout", t7_pass,
		"In recovery: step=%d (timer > 0: %s), After timeout: step=%d" % [step_in_rec, in_rec_timer, step_after_rec])

	# -----------------------------------------------------------------
	# TEST 8: Death interrupts combo and clears state
	# -----------------------------------------------------------------
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	# Start attack
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	# Die mid-combo
	p.transition_to(PlayerController.CombatState.DEAD)
	var is_dead_state: bool = (p.combat_state == PlayerController.CombatState.DEAD)
	var buf_after_death: int = p.combo_buffer
	var step_after_death: int = p.combo_step

	p.respawn(Vector3(3.5, 0, 1.8), 0.0)
	await process_frame

	var t8_pass: bool = is_dead_state and (buf_after_death == 0) and (step_after_death == 0)
	_record_result("TEST 8: Death interrupts combo and clears state", t8_pass,
		"Buffer after death: %d, step: %d" % [buf_after_death, step_after_death])

	# -----------------------------------------------------------------
	# TEST 9: Hit reaction clears combo state
	# -----------------------------------------------------------------
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	# Player receives a hit reaction
	p.apply_hit_reaction(Vector3.BACK, false)
	var buf_after_hit: int = p.combo_buffer
	var step_after_hit: int = p.combo_step
	await _wait_for_player_attack_finish(p)

	var t9_pass: bool = (buf_after_hit == 0) and (step_after_hit == 0)
	_record_result("TEST 9: Hit reaction clears combo state", t9_pass,
		"Buffer after hit: %d, step: %d" % [buf_after_hit, step_after_hit])

	# -----------------------------------------------------------------
	# TEST 10: Shield break clears combo state
	# -----------------------------------------------------------------
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	p.break_shield()
	var buf_after_break: int = p.combo_buffer
	var step_after_break: int = p.combo_step
	p.reset_shield_for_new_round()
	await process_frame

	var t10_pass: bool = (buf_after_break == 0) and (step_after_break == 0)
	_record_result("TEST 10: Shield break clears combo state", t10_pass,
		"Buffer after break: %d, step: %d" % [buf_after_break, step_after_break])

	# -----------------------------------------------------------------
	# TEST 11: Block during combo rejects mid-swing block; manual reset works
	# -----------------------------------------------------------------
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)
	await process_frame

	var block_mid_swing: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	var is_still_attacking: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	await _wait_for_player_attack_finish(p)

	var block_after: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	var is_blocking: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	var buf_on_block: int = p.combo_buffer
	p.transition_to(PlayerController.CombatState.IDLE)

	var t11_pass: bool = (not block_mid_swing) and is_still_attacking and block_after and is_blocking and (buf_on_block == 0)
	_record_result("TEST 11: Block during combo rejects mid-swing block", t11_pass,
		"Mid-swing block rejected: %s, Block after: %s, Buffer on block: %d" % [not block_mid_swing, block_after, buf_on_block])

	# -----------------------------------------------------------------
	# TEST 12: Shield durability & break logic intact during manual combo
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.rotation.y = PI
	td.is_blocking = true
	td.shield_durability = 35.0 # Will break on hit 3 (15 + 15 = 30, remaining 5 -> break)
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	# Timed 3 clicks into blocking dummy
	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	var ap_t12: AnimationPlayer = p.anim_player
	var w1_t12: int = 150
	while ap_t12.current_animation_position < 0.40 and p.combat_state == PlayerController.CombatState.ATTACK and w1_t12 > 0:
		await process_frame
		w1_t12 -= 1

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	var w2_t12: int = 150
	while (p.combo_step < 2 or ap_t12.current_animation_position < 0.40) and p.combat_state == PlayerController.CombatState.ATTACK and w2_t12 > 0:
		await process_frame
		w2_t12 -= 1

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	await _wait_for_player_attack_finish(p)
	var final_shield: float = td.shield_durability
	var broken: bool = td.is_shield_broken
	var t12_pass: bool = (final_shield == 0.0) and broken
	_record_result("TEST 12: Shield durability & break logic intact during manual combo", t12_pass,
		"Final shield durability: %.1f, Is shield broken: %s" % [final_shield, broken])

	# -----------------------------------------------------------------
	# TEST 13: FPS mode supports manual 3-hit combo identically
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.set_third_person(false)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	var ap_t13: AnimationPlayer = p.anim_player
	var w1_t13: int = 150
	while ap_t13.current_animation_position < 0.40 and p.combat_state == PlayerController.CombatState.ATTACK and w1_t13 > 0:
		await process_frame
		w1_t13 -= 1

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	var w2_t13: int = 150
	while (p.combo_step < 2 or ap_t13.current_animation_position < 0.40) and p.combat_state == PlayerController.CombatState.ATTACK and w2_t13 > 0:
		await process_frame
		w2_t13 -= 1

	_send_lmb(true)
	await process_frame
	_send_lmb(false)

	await _wait_for_player_attack_finish(p)
	var fps_dmg: float = 100.0 - td.health_component.current_health
	p.set_third_person(true)
	await process_frame

	var t13_pass: bool = (fps_dmg == 75.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 13: FPS mode supports manual 3-hit combo identically", t13_pass,
		"FPS combo total damage: %.1f (Expected 75.0)" % fps_dmg)

	# -----------------------------------------------------------------
	# TEST 14: Invariants preserved
	# -----------------------------------------------------------------
	var inv_damage: bool = (combat.attack_damage == 25.0)
	var inv_shield_dmg: bool = (combat.normal_attack_shield_damage == 15.0)
	var inv_cone: bool = (p.block_cone_deg == 120.0)
	var inv_kb: bool = (p.hit_knockback_distance == 0.40)
	var inv_recoil: bool = (p.block_recoil_distance == 0.08)
	var inv_impact_time: bool = (PlayerController.ATTACK_IMPACT_TIMESTAMP == 0.35)
	var inv_range: bool = (combat.attack_range == 2.2)

	var t14_pass: bool = inv_damage and inv_shield_dmg and inv_cone and inv_kb and inv_recoil and inv_impact_time and inv_range
	_record_result("TEST 14: Invariants preserved", t14_pass,
		"Damage=25, ShieldDmg=15, Cone=120°, KB=0.4m, Recoil=0.08m, Impact=0.35s, Range=2.2m")

	# -----------------------------------------------------------------
	# FINAL SUMMARY
	# -----------------------------------------------------------------
	print("\n==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	quit(0 if _failed_tests == 0 else 1)
