extends SceneTree

# ==============================================================================
# Acceptance Test Suite for Task 5.14: Basic 3-Hit Attack Combo
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
	print("RUNNING TASK 5.14 ACCEPTANCE TESTS: 3-HIT ATTACK COMBO")
	print("==================================================")
	call_deferred("_run_tests")


func _wait_for_player_attack_impact(p: PlayerController) -> void:
	var safety: int = 150
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _wait_for_combo_window(p: PlayerController) -> void:
	var safety: int = 150
	while not p.is_in_combo_window() and p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _wait_for_player_attack_finish(p: PlayerController) -> void:
	var safety: int = 180
	while p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _run_tests() -> void:
	# -----------------------------------------------------------------
	# TEST 1: Combat Arena loads successfully
	# -----------------------------------------------------------------
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = arena_scene.instantiate() as CombatTestArena
	root.add_child(arena)
	await process_frame
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
	_record_result("TEST 1: Combat Arena loads successfully", t1_pass,
		"All core combat entities initialized")

	# Position player facing dummy
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation = Vector3.ZERO
	p.set_third_person(true)
	p.global_position = Vector3(3.5, 0, 1.8) # 1.8m away, facing -Z
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame

	# -----------------------------------------------------------------
	# TEST 2: Single attack still works (Combo 1 deals 25 damage, finishes to IDLE)
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	var hp_before_t2: float = td.health_component.current_health
	var started_t2: bool = p._try_combat_attack()
	var step_on_start_t2: int = p.combo_step
	await _wait_for_player_attack_impact(p)
	var hp_impact_t2: float = td.health_component.current_health
	var damage_t2: float = hp_before_t2 - hp_impact_t2
	await _wait_for_player_attack_finish(p)
	var t2_pass: bool = started_t2 and (step_on_start_t2 == 1) and (damage_t2 == 25.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 2: Single attack still works", t2_pass,
		"Started: %s, Step: %d, Damage: %.1f, Final state: %s" % [started_t2, step_on_start_t2, damage_t2, p.combat_state])

	# -----------------------------------------------------------------
	# TEST 3: Attack 1 -> Attack 2 works (Combo window queuing)
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await process_frame

	# Start Attack 1
	p._try_combat_attack()
	await _wait_for_combo_window(p)
	var in_window_c1: bool = p.is_in_combo_window()
	var queued_c2: bool = p._try_combat_attack() # Queues Combo 2
	var is_queued_c2: bool = p.is_combo_queued()

	# Wait for Attack 1 to complete and Attack 2 to start
	var safety_t3: int = 150
	while p.combo_step < 2 and p.combat_state == PlayerController.CombatState.ATTACK and safety_t3 > 0:
		await process_frame
		safety_t3 -= 1
	var step_c2: int = p.combo_step
	var state_c2: int = p.combat_state

	# Wait for Attack 2 impact
	await _wait_for_player_attack_impact(p)
	var hp_after_c2: float = td.health_component.current_health
	var total_dmg_c2: float = 100.0 - hp_after_c2
	await _wait_for_player_attack_finish(p)

	var t3_pass: bool = in_window_c1 and queued_c2 and is_queued_c2 and (step_c2 == 2) and (state_c2 == PlayerController.CombatState.ATTACK) and (total_dmg_c2 == 50.0)
	_record_result("TEST 3: Attack 1 -> Attack 2 works", t3_pass,
		"In window: %s, Queued: %s, Step reached: %d, Total Damage: %.1f (Expected 50.0)" % [in_window_c1, queued_c2, step_c2, total_dmg_c2])

	# -----------------------------------------------------------------
	# TEST 4: Attack 1 -> Attack 2 -> Attack 3 works (Full 3-Hit Combo)
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await process_frame

	# Start Attack 1
	p._try_combat_attack()
	await _wait_for_combo_window(p)
	p._try_combat_attack() # Queue Combo 2

	# Wait for Attack 2 to start
	var safety_t4_1: int = 150
	while p.combo_step < 2 and safety_t4_1 > 0:
		await process_frame
		safety_t4_1 -= 1

	# Wait for Attack 2 combo window
	await _wait_for_combo_window(p)
	var queued_c3: bool = p._try_combat_attack() # Queue Combo 3

	# Wait for Attack 3 to start
	var safety_t4_2: int = 150
	while p.combo_step < 3 and safety_t4_2 > 0:
		await process_frame
		safety_t4_2 -= 1
	var step_c3: int = p.combo_step

	# Wait for Attack 3 impact
	await _wait_for_player_attack_impact(p)
	var hp_after_c3: float = td.health_component.current_health
	var total_dmg_c3: float = 100.0 - hp_after_c3
	await _wait_for_player_attack_finish(p)

	var t4_pass: bool = queued_c3 and (step_c3 == 3) and (total_dmg_c3 == 75.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 4: Attack 1 -> Attack 2 -> Attack 3 works", t4_pass,
		"Step reached: %d, Total Damage: %.1f (Expected 75.0), Final state: %s" % [step_c3, total_dmg_c3, p.combat_state])

	# -----------------------------------------------------------------
	# TEST 5: Early input is buffered into combo (Windup phase)
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await process_frame

	p._try_combat_attack()
	# Check at early windup (t = 0.10s)
	for i in range(6):
		await process_frame
	var in_window_early: bool = p.is_in_combo_window()
	var early_press_accepted: bool = p._try_combat_attack()
	var queued_early: bool = p.is_combo_queued()

	# Wait for Attack 1 and buffered Attack 2 to finish completely
	await _wait_for_player_attack_finish(p)
	var hp_early: float = td.health_component.current_health

	# Early press before window is buffered; Attack 2 plays after Attack 1 (2 hits = 50 damage)
	var t5_pass: bool = (not in_window_early) and early_press_accepted and queued_early and (hp_early == 50.0)
	_record_result("TEST 5: Early input is buffered into combo", t5_pass,
		"In window at early windup: %s, Press accepted: %s, Damage: %.1f (Expected 2 hits: 50.0)" % [in_window_early, early_press_accepted, 100.0 - hp_early])

	# -----------------------------------------------------------------
	# TEST 6: Spam input cannot exceed 3 attacks (Max combo length = 3)
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await process_frame

	var max_step_seen: int = 0

	# Continuously spam attack while in attack state (up to safety limit)
	p._try_combat_attack()
	var safety_spam: int = 400
	while p.combat_state == PlayerController.CombatState.ATTACK and safety_spam > 0:
		p._try_combat_attack()
		if p.combo_step > max_step_seen:
			max_step_seen = p.combo_step
		await process_frame
		safety_spam -= 1

	await _wait_for_player_attack_finish(p)

	var hp_after_spam: float = td.health_component.current_health
	var damage_spam: float = 100.0 - hp_after_spam
	# Exactly 3 hits (75.0 damage) must be applied
	var t6_pass: bool = (max_step_seen == 3) and (damage_spam == 75.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 6: Spam input cannot exceed 3 attacks", t6_pass,
		"Max step seen: %d, Damage: %.1f (Expected 75.0 / exactly 3 hits)" % [max_step_seen, damage_spam])

	# -----------------------------------------------------------------
	# TEST 7: Each attack applies damage only once
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await _wait_for_player_attack_finish(p)
	await process_frame

	# Check damages at each step
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var dmg_hit1: float = 100.0 - td.health_component.current_health
	await _wait_for_combo_window(p)
	p._try_combat_attack() # Queue 2

	var safety_t7_1: int = 150
	while p.combo_step < 2 and safety_t7_1 > 0:
		await process_frame
		safety_t7_1 -= 1
	await _wait_for_player_attack_impact(p)
	var dmg_hit2: float = 100.0 - td.health_component.current_health - dmg_hit1
	await _wait_for_combo_window(p)
	p._try_combat_attack() # Queue 3

	var safety_t7_2: int = 150
	while p.combo_step < 3 and safety_t7_2 > 0:
		await process_frame
		safety_t7_2 -= 1
	await _wait_for_player_attack_impact(p)
	var dmg_hit3: float = 100.0 - td.health_component.current_health - dmg_hit1 - dmg_hit2
	await _wait_for_player_attack_finish(p)

	var t7_pass: bool = (dmg_hit1 == 25.0 and dmg_hit2 == 25.0 and dmg_hit3 == 25.0)
	_record_result("TEST 7: Each attack applies damage only once", t7_pass,
		"Hit 1: %.1f, Hit 2: %.1f, Hit 3: %.1f (All exactly 25.0)" % [dmg_hit1, dmg_hit2, dmg_hit3])

	# -----------------------------------------------------------------
	# TEST 8: Block still works during and after combo
	# -----------------------------------------------------------------
	p.reset_combo()
	p._try_combat_attack()
	await process_frame
	# Mid-swing block attempt must be rejected
	var block_mid_swing: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	var is_still_attacking: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	await _wait_for_player_attack_finish(p)

	# Block immediately after attack must succeed
	var block_after_attack: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	var is_blocking_after: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	var combo_reset_on_block: bool = (p.combo_step == 0)
	p.transition_to(PlayerController.CombatState.IDLE)

	var t8_pass: bool = (not block_mid_swing) and is_still_attacking and block_after_attack and is_blocking_after and combo_reset_on_block
	_record_result("TEST 8: Block still works during and after combo", t8_pass,
		"Blocked mid-swing rejected: %s, Block after attack accepted: %s, Combo reset on block: %s" % [not block_mid_swing, block_after_attack, combo_reset_on_block])

	# -----------------------------------------------------------------
	# TEST 9: Shield damage and shield break work during combo
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.rotation.y = PI
	td.is_blocking = true
	td.shield_durability = 35.0 # Will break on hit 3 (15 + 15 = 30, remaining 5 -> break on hit 3)
	p.reset_combo()
	await process_frame

	# Hit 1
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var shield_after_h1: float = td.shield_durability
	await _wait_for_combo_window(p)
	p._try_combat_attack()

	# Hit 2
	var safety_t9_1: int = 150
	while p.combo_step < 2 and safety_t9_1 > 0:
		await process_frame
		safety_t9_1 -= 1
	await _wait_for_player_attack_impact(p)
	var shield_after_h2: float = td.shield_durability
	await _wait_for_combo_window(p)
	p._try_combat_attack()

	# Hit 3 (Shield break)
	var safety_t9_2: int = 150
	while p.combo_step < 3 and safety_t9_2 > 0:
		await process_frame
		safety_t9_2 -= 1
	await _wait_for_player_attack_impact(p)
	var shield_after_h3: float = td.shield_durability
	var broken_on_h3: bool = td.is_shield_broken
	var vfx_on_break: bool = combat.shield_break_vfx != null and combat.shield_break_vfx.visible
	await _wait_for_player_attack_finish(p)

	var t9_pass: bool = (shield_after_h1 == 20.0) and (shield_after_h2 == 5.0) and (shield_after_h3 == 0.0) and broken_on_h3 and vfx_on_break
	_record_result("TEST 9: Shield damage and shield break work during combo", t9_pass,
		"Shield H1: %.1f, H2: %.1f, H3: %.1f, Broken: %s, VFX: %s" % [shield_after_h1, shield_after_h2, shield_after_h3, broken_on_h3, vfx_on_break])

	# -----------------------------------------------------------------
	# TEST 10: Existing VFX still trigger correctly on combo hits
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.reset_combo()
	await process_frame

	p._try_combat_attack()
	await process_frame
	var telegraph_visible: bool = combat.attack_telegraph_vfx != null and combat.attack_telegraph_vfx.visible
	await _wait_for_player_attack_impact(p)
	var slash_visible: bool = combat.slash_arc_vfx != null and combat.slash_arc_vfx.visible
	var hit_impact_visible: bool = combat.hit_impact_vfx != null and combat.hit_impact_vfx.visible
	var damage_num_active: bool = combat.damage_number_pool.get_active_count() > 0
	await _wait_for_player_attack_finish(p)

	var t10_pass: bool = telegraph_visible and slash_visible and hit_impact_visible and damage_num_active
	_record_result("TEST 10: Existing VFX still trigger correctly on combo hits", t10_pass,
		"Telegraph: %s, SlashArc: %s, HitImpact: %s, DamageNumbers: %s" % [telegraph_visible, slash_visible, hit_impact_visible, damage_num_active])

	# -----------------------------------------------------------------
	# TEST 11: Combo resets after recovery timeout
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.reset_combo()
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	await _wait_for_player_attack_finish(p)

	# Immediately after attack finish, player is in recovery window
	var in_recovery_timer: bool = p._combo_recovery_timer > 0.0
	var step_in_recovery: int = p.combo_step

	# Wait for recovery timeout (0.25s)
	var safety_rec: int = 180
	while p.combo_step != 0 and safety_rec > 0:
		await process_frame
		safety_rec -= 1

	var step_after_timeout: int = p.combo_step
	var t11_pass: bool = (step_in_recovery == 1) and in_recovery_timer and (step_after_timeout == 0)
	_record_result("TEST 11: Combo resets after recovery timeout", t11_pass,
		"In recovery: step=%d (timer > 0: %s), After timeout: step=%d (Expected 0)" % [step_in_recovery, in_recovery_timer, step_after_timeout])

	# -----------------------------------------------------------------
	# TEST 12: Death interrupts combo safely
	# -----------------------------------------------------------------
	p.reset_combo()
	p._try_combat_attack()
	await process_frame
	var attacking_before_death: bool = (p.combat_state == PlayerController.CombatState.ATTACK)

	# Die mid-combo
	p.transition_to(PlayerController.CombatState.DEAD)
	var state_dead: bool = (p.combat_state == PlayerController.CombatState.DEAD)
	var combo_cleared_on_death: bool = (p.combo_step == 0) and (not p.is_combo_queued())
	var cannot_attack_while_dead: bool = not p._try_combat_attack()

	# Restore for next test
	p.respawn(Vector3(3.5, 0, 1.8), 0.0)
	await process_frame

	var t12_pass: bool = attacking_before_death and state_dead and combo_cleared_on_death and cannot_attack_while_dead
	_record_result("TEST 12: Death interrupts combo safely", t12_pass,
		"Attacking before death: %s, Dead state: %s, Combo reset: %s, Attack rejected: %s" % [attacking_before_death, state_dead, combo_cleared_on_death, cannot_attack_while_dead])

	# -----------------------------------------------------------------
	# TEST 13: FPS mode supports 3-hit combo identically
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.set_third_person(false)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.reset_combo()
	await process_frame

	# Execute 3-hit combo in FPS
	p._try_combat_attack()
	await _wait_for_combo_window(p)
	p._try_combat_attack()
	var safety_fps1: int = 150
	while p.combo_step < 2 and safety_fps1 > 0:
		await process_frame
		safety_fps1 -= 1

	await _wait_for_combo_window(p)
	p._try_combat_attack()
	var safety_fps2: int = 150
	while p.combo_step < 3 and safety_fps2 > 0:
		await process_frame
		safety_fps2 -= 1

	await _wait_for_player_attack_impact(p)
	await _wait_for_player_attack_finish(p)
	var fps_dmg: float = 100.0 - td.health_component.current_health

	p.set_third_person(true)
	await process_frame

	var t13_pass: bool = (fps_dmg == 75.0) and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 13: FPS mode supports 3-hit combo identically", t13_pass,
		"FPS combo total damage: %.1f (Expected 75.0)" % fps_dmg)

	# -----------------------------------------------------------------
	# TEST 14: Combat invariants remain unchanged
	# -----------------------------------------------------------------
	var inv_damage: bool = (combat.attack_damage == 25.0)
	var inv_shield_dmg: bool = (combat.normal_attack_shield_damage == 15.0)
	var inv_cone: bool = (p.block_cone_deg == 120.0)
	var inv_kb: bool = (p.hit_knockback_distance == 0.40)
	var inv_recoil: bool = (p.block_recoil_distance == 0.08)
	var inv_impact_time: bool = (PlayerController.ATTACK_IMPACT_TIMESTAMP == 0.35)
	var inv_range: bool = (combat.attack_range == 2.2)

	var t14_pass: bool = inv_damage and inv_shield_dmg and inv_cone and inv_kb and inv_recoil and inv_impact_time and inv_range
	_record_result("TEST 14: Combat invariants remain unchanged", t14_pass,
		"Damage=25, ShieldDmg=15, Cone=120°, KB=0.4m, Recoil=0.08m, Impact=0.35s, Range=2.2m")

	# -----------------------------------------------------------------
	# FINAL SUMMARY
	# -----------------------------------------------------------------
	print("\n==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	quit(0 if _failed_tests == 0 else 1)
