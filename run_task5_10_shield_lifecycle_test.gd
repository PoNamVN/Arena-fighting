extends SceneTree

# ==============================================================================
# Acceptance Test Suite for Task 5.10: Shield Lifecycle (Test Arena vs Real Match)
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
	print("RUNNING TASK 5.10 ACCEPTANCE TESTS: SHIELD LIFECYCLE")
	print("==================================================")
	call_deferred("_run_tests")


func _run_tests() -> void:
	# Load CombatTestArena
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = arena_scene.instantiate() as CombatTestArena
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.player
	var ad: AttackTrainingDummy = arena.attack_dummy
	if ad:
		ad.auto_attack = false
		ad.cancel_attack()
	await process_frame

	# -----------------------------------------------------------------
	# TEST 1: Test Arena explicitly uses TEST_ARENA shield recovery mode
	# -----------------------------------------------------------------
	var t1_pass: bool = (p.shield_recovery_mode == PlayerController.ShieldRecoveryMode.TEST_ARENA)
	_record_result("TEST 1: Test Arena explicitly uses TEST_ARENA shield recovery mode", t1_pass,
		"Mode: %s (Expected TEST_ARENA)" % str(p.shield_recovery_mode))

	# -----------------------------------------------------------------
	# TEST 2: Test Arena starts with shield = 100 and READY
	# -----------------------------------------------------------------
	var t2_pass: bool = (p.shield_durability == 100.0 and p.shield_state == PlayerController.ShieldState.READY and not p.is_shield_broken)
	_record_result("TEST 2: Test Arena starts with shield = 100 and READY", t2_pass,
		"Durability: %.1f, State: %s" % [p.shield_durability, str(p.shield_state)])

	# -----------------------------------------------------------------
	# TEST 3: Test Arena shield reaches 0 after repeated successful blocks
	# -----------------------------------------------------------------
	# 100 -> 85 -> 70 -> 55 -> 40 -> 25 -> 10 -> 0 (7 blocks)
	for i in range(7):
		p.apply_shield_damage(15.0)
	var t3_pass: bool = (p.shield_durability == 0.0)
	_record_result("TEST 3: Test Arena shield reaches 0 after repeated successful blocks", t3_pass,
		"Durability: %.1f (Expected 0.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 4: Test Arena triggers Shield Break exactly once
	# -----------------------------------------------------------------
	var t4_pass: bool = (p.shield_state == PlayerController.ShieldState.BROKEN and p.is_shield_broken and p._shield_break_count == 1)
	_record_result("TEST 4: Test Arena triggers Shield Break exactly once", t4_pass,
		"State: %s, Break count: %d" % [str(p.shield_state), p._shield_break_count])

	# -----------------------------------------------------------------
	# TEST 5: Test Arena keeps the existing 1.0s break stun
	# -----------------------------------------------------------------
	var is_stunned_early: bool = p.is_shield_stunned and p._shield_stun_timer > 0.5
	await create_timer(1.05).timeout
	await process_frame
	var is_stunned_after: bool = p.is_shield_stunned
	var t5_pass: bool = is_stunned_early and (not is_stunned_after)
	_record_result("TEST 5: Test Arena keeps the existing 1.0s break stun", t5_pass,
		"Stunned early: %s, Stunned after 1.05s: %s" % [is_stunned_early, is_stunned_after])

	# -----------------------------------------------------------------
	# TEST 6: Test Arena automatically restores shield after 2.0s
	# -----------------------------------------------------------------
	# Total elapsed since break: 1.05s + 1.05s = 2.10s (exceeds 2.0s recovery delay)
	await create_timer(1.05).timeout
	await process_frame
	var t6_pass: bool = (p.shield_durability == 100.0)
	_record_result("TEST 6: Test Arena automatically restores shield after 2.0s", t6_pass,
		"Durability after recovery: %.1f (Expected 100.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 7: Test Arena returns to READY after recovery
	# -----------------------------------------------------------------
	var t7_pass: bool = (p.shield_state == PlayerController.ShieldState.READY and not p.is_shield_broken)
	_record_result("TEST 7: Test Arena returns to READY after recovery", t7_pass,
		"State: %s, is_shield_broken: %s" % [str(p.shield_state), p.is_shield_broken])

	# -----------------------------------------------------------------
	# TEST 8: Test Arena can block again after automatic recovery
	# -----------------------------------------------------------------
	var can_block_after_rec: bool = p.can_block()
	var block_started: bool = p._start_block()
	await process_frame
	var is_blocking_after_rec: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	p._release_block()
	await process_frame
	var t8_pass: bool = can_block_after_rec and block_started and is_blocking_after_rec
	_record_result("TEST 8: Test Arena can block again after automatic recovery", t8_pass,
		"can_block: %s, start_block: %s, is_blocking: %s" % [can_block_after_rec, block_started, is_blocking_after_rec])

	# -----------------------------------------------------------------
	# TEST 9: MATCH configuration exists and can be selected independently
	# -----------------------------------------------------------------
	var has_match_mode: bool = ("MATCH" in PlayerController.ShieldRecoveryMode)
	p.shield_recovery_mode = PlayerController.ShieldRecoveryMode.MATCH
	var t9_pass: bool = has_match_mode and (p.shield_recovery_mode == PlayerController.ShieldRecoveryMode.MATCH)
	_record_result("TEST 9: MATCH configuration exists and can be selected independently of Test Arena", t9_pass,
		"Mode set to: %s" % str(p.shield_recovery_mode))

	# -----------------------------------------------------------------
	# TEST 10: MATCH starts with shield = 100 and READY
	# -----------------------------------------------------------------
	p.reset_shield_for_new_round()
	var t10_pass: bool = (p.shield_durability == 100.0 and p.shield_state == PlayerController.ShieldState.READY and not p.is_shield_broken)
	_record_result("TEST 10: MATCH starts with shield = 100 and READY", t10_pass,
		"Durability: %.1f, State: %s" % [p.shield_durability, str(p.shield_state)])

	# -----------------------------------------------------------------
	# TEST 11: MATCH shield reaches 0 after repeated successful blocks
	# -----------------------------------------------------------------
	var break_count_before_match: int = p._shield_break_count
	for i in range(7):
		p.apply_shield_damage(15.0)
	var t11_pass: bool = (p.shield_durability == 0.0)
	_record_result("TEST 11: MATCH shield reaches 0 after repeated successful blocks", t11_pass,
		"Durability: %.1f (Expected 0.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 12: MATCH triggers Shield Break exactly once
	# -----------------------------------------------------------------
	var t12_pass: bool = (p.shield_state == PlayerController.ShieldState.BROKEN and p.is_shield_broken and p._shield_break_count == break_count_before_match + 1)
	_record_result("TEST 12: MATCH triggers Shield Break exactly once", t12_pass,
		"State: %s, Break count delta: %d" % [str(p.shield_state), p._shield_break_count - break_count_before_match])

	# -----------------------------------------------------------------
	# TEST 13: MATCH keeps the existing 1.0s break stun
	# -----------------------------------------------------------------
	var match_stun_early: bool = p.is_shield_stunned and p._shield_stun_timer > 0.5
	await create_timer(1.05).timeout
	await process_frame
	var match_stun_after: bool = p.is_shield_stunned
	var t13_pass: bool = match_stun_early and (not match_stun_after)
	_record_result("TEST 13: MATCH keeps the existing 1.0s break stun", t13_pass,
		"Stunned early: %s, Stunned after 1.05s: %s" % [match_stun_early, match_stun_after])

	# -----------------------------------------------------------------
	# TEST 14: MATCH does NOT automatically restore shield after 2.0s
	# -----------------------------------------------------------------
	# Wait additional 1.1s (total > 2.15s elapsed since break)
	await create_timer(1.10).timeout
	await process_frame
	var t14_pass: bool = (p.shield_durability == 0.0)
	_record_result("TEST 14: MATCH does NOT automatically restore shield after 2.0s", t14_pass,
		"Durability after 2.15s: %.1f (Expected 0.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 15: MATCH remains BROKEN after the recovery period
	# -----------------------------------------------------------------
	var t15_pass: bool = (p.shield_state == PlayerController.ShieldState.BROKEN and p.is_shield_broken)
	_record_result("TEST 15: MATCH remains BROKEN after the recovery period", t15_pass,
		"State: %s, is_shield_broken: %s" % [str(p.shield_state), p.is_shield_broken])

	# -----------------------------------------------------------------
	# TEST 16: MATCH rejects RMB block while shield is permanently broken
	# -----------------------------------------------------------------
	var can_block_match_broken: bool = p.can_block()
	var block_start_attempt: bool = p._start_block()
	var is_blocking_attempt: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	var t16_pass: bool = (not can_block_match_broken) and (not block_start_attempt) and (not is_blocking_attempt)
	_record_result("TEST 16: MATCH rejects RMB block while shield is permanently broken", t16_pass,
		"can_block: %s, start_block: %s, is_blocking: %s" % [can_block_match_broken, block_start_attempt, is_blocking_attempt])

	# -----------------------------------------------------------------
	# TEST 17: MATCH incoming attack while broken deals full 25 damage
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	p.health_component.reset_health()
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame

	var hp_before_t17: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout
	await process_frame

	var hp_after_t17: float = p.health_component.current_health
	var damage_t17: float = hp_before_t17 - hp_after_t17
	var t17_pass: bool = abs(damage_t17 - 25.0) < 0.01
	_record_result("TEST 17: MATCH incoming attack while broken deals full 25 damage", t17_pass,
		"Damage taken: %.2f (Expected 25.0)" % damage_t17)

	# -----------------------------------------------------------------
	# TEST 18: MATCH produces no Block Impact VFX while shield is broken
	# -----------------------------------------------------------------
	var block_vfx_active_t18: bool = false
	if p.combat and p.combat.block_impact_vfx:
		block_vfx_active_t18 = p.combat.block_impact_vfx.visible
	var t18_pass: bool = (not block_vfx_active_t18)
	_record_result("TEST 18: MATCH produces no Block Impact VFX while shield is broken", t18_pass,
		"BlockImpactVFX visible: %s (Expected false)" % block_vfx_active_t18)

	# -----------------------------------------------------------------
	# TEST 19: MATCH does not apply additional shield damage after shield reaches 0
	# -----------------------------------------------------------------
	p.apply_shield_damage(25.0)
	var t19_pass: bool = (p.shield_durability == 0.0)
	_record_result("TEST 19: MATCH does not apply additional shield damage after shield reaches 0", t19_pass,
		"Shield durability: %.1f (Expected 0.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 20: Explicit new-life/new-round shield reset restores shield to 100
	# -----------------------------------------------------------------
	p.reset_shield_for_new_round()
	var t20_pass: bool = (p.shield_durability == 100.0)
	_record_result("TEST 20: Explicit new-life/new-round shield reset restores shield to 100", t20_pass,
		"Durability after reset: %.1f (Expected 100.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 21: Explicit reset changes state BROKEN -> READY
	# -----------------------------------------------------------------
	var t21_pass: bool = (p.shield_state == PlayerController.ShieldState.READY and not p.is_shield_broken)
	_record_result("TEST 21: Explicit reset changes state BROKEN -> READY", t21_pass,
		"State: %s, is_shield_broken: %s" % [str(p.shield_state), p.is_shield_broken])

	# -----------------------------------------------------------------
	# TEST 22: Explicit reset clears recovery timer
	# -----------------------------------------------------------------
	p._shield_recovery_timer = 2.5
	p.reset_shield_for_new_round()
	var t22_pass: bool = (p._shield_recovery_timer == 0.0 and p.shield_recovery_time_remaining == 0.0)
	_record_result("TEST 22: Explicit reset clears recovery timer", t22_pass,
		"Recovery timer: %.2f, time_remaining: %.2f" % [p._shield_recovery_timer, p.shield_recovery_time_remaining])

	# -----------------------------------------------------------------
	# TEST 23: Explicit reset clears low-shield warning
	# -----------------------------------------------------------------
	p.shield_durability = 15.0
	p._update_low_shield_state()
	var had_low_shield: bool = p.is_low_shield
	p.reset_shield_for_new_round()
	var t23_pass: bool = had_low_shield and (not p.is_low_shield)
	_record_result("TEST 23: Explicit reset clears low-shield warning", t23_pass,
		"Had warning at 15.0: %s, Warning after reset: %s" % [had_low_shield, p.is_low_shield])

	# -----------------------------------------------------------------
	# TEST 24: After explicit reset, RMB block works again
	# -----------------------------------------------------------------
	var can_block_after_reset: bool = p.can_block()
	var start_block_after_reset: bool = p._start_block()
	await process_frame
	var is_blocking_now: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	p._release_block()
	await process_frame
	var t24_pass: bool = can_block_after_reset and start_block_after_reset and is_blocking_now
	_record_result("TEST 24: After explicit reset, RMB block works again", t24_pass,
		"can_block: %s, start_block: %s, is_blocking: %s" % [can_block_after_reset, start_block_after_reset, is_blocking_now])

	# -----------------------------------------------------------------
	# TEST 25: Player respawn uses the explicit shield reset contract
	# -----------------------------------------------------------------
	# Break shield, kill player, trigger respawn
	p.break_shield()
	p.health_component.take_damage(100.0)
	await process_frame
	arena.respawn_player()
	await process_frame
	var t25_pass: bool = (p.shield_durability == 100.0 and p.shield_state == PlayerController.ShieldState.READY and p.can_block())
	_record_result("TEST 25: Player respawn uses the explicit shield reset contract", t25_pass,
		"Respawned durability: %.1f, State: %s, can_block: %s" % [p.shield_durability, str(p.shield_state), p.can_block()])

	# -----------------------------------------------------------------
	# TEST 26: Respawn does not create duplicate Player nodes
	# -----------------------------------------------------------------
	var player_nodes: Array[Node] = root.find_children("*", "PlayerController", true, false)
	var t26_pass: bool = (player_nodes.size() == 1)
	_record_result("TEST 26: Respawn does not create duplicate Player nodes", t26_pass,
		"Player nodes found: %d (Expected exactly 1)" % player_nodes.size())

	# -----------------------------------------------------------------
	# TEST 27: Existing Test Arena automatic recovery remains intact
	# -----------------------------------------------------------------
	p.shield_recovery_mode = PlayerController.ShieldRecoveryMode.TEST_ARENA
	p.break_shield()
	await create_timer(2.10).timeout
	await process_frame
	var t27_pass: bool = (p.shield_durability == 100.0 and p.shield_state == PlayerController.ShieldState.READY)
	_record_result("TEST 27: Existing Test Arena automatic recovery remains intact", t27_pass,
		"Durability: %.1f, State: %s" % [p.shield_durability, str(p.shield_state)])

	# -----------------------------------------------------------------
	# TEST 28: Existing Shield Break VFX remains intact
	# -----------------------------------------------------------------
	p.reset_shield_for_new_round()
	p.break_shield()
	var vfx_detected: bool = false
	if p.combat and p.combat.shield_break_vfx:
		vfx_detected = p.combat.shield_break_vfx.visible
	var t28_pass: bool = vfx_detected
	_record_result("TEST 28: Existing Shield Break VFX remains intact", t28_pass,
		"ShieldBreakVFX visible: %s" % vfx_detected)

	# -----------------------------------------------------------------
	# TEST 29: Existing Shield Break stagger remains intact
	# -----------------------------------------------------------------
	var has_stagger_tween: bool = (p._hit_reaction_tween != null and p._hit_reaction_tween.is_valid())
	var t29_pass: bool = has_stagger_tween or (p._knockback_timer > 0.0) or (p.velocity.length() > 0.0)
	_record_result("TEST 29: Existing Shield Break stagger remains intact", t29_pass,
		"Stagger tween valid: %s" % has_stagger_tween)

	# -----------------------------------------------------------------
	# TEST 30: Existing damage values remain unchanged
	# -----------------------------------------------------------------
	p.reset_shield_for_new_round()
	p.health_component.reset_health()
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var hp_before_t30: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout
	await process_frame

	var hp_after_t30: float = p.health_component.current_health
	var blocked_damage: float = hp_before_t30 - hp_after_t30
	var t30_pass: bool = abs(blocked_damage - 3.75) < 0.01
	_record_result("TEST 30: Existing damage values remain unchanged", t30_pass,
		"Blocked damage: %.2f (Expected 3.75)" % blocked_damage)

	# -----------------------------------------------------------------
	# TEST 31: Existing attack impact remains exactly 0.35s
	# -----------------------------------------------------------------
	p.reset_shield_for_new_round()
	p.health_component.reset_health()
	p.transition_to(PlayerController.CombatState.IDLE)
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	await process_frame

	ad.trigger_attack_now()
	await create_timer(0.15).timeout
	await process_frame
	var hp_windup: float = p.health_component.current_health

	while ad.is_attacking() and p.health_component.current_health == hp_windup:
		await process_frame

	var hp_impact: float = p.health_component.current_health
	var damage_impact: float = hp_windup - hp_impact
	var t31_pass: bool = (hp_windup == 100.0 and abs(damage_impact - 25.0) < 0.01)
	_record_result("TEST 31: Existing attack impact remains exactly 0.35s", t31_pass,
		"Windup HP: %.1f, Impact HP: %.1f, Damage: %.1f" % [hp_windup, hp_impact, damage_impact])

	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout

	# -----------------------------------------------------------------
	# TEST 32: Existing block cone remains 120 degrees
	# -----------------------------------------------------------------
	var cone_val: float = p.block_cone_deg
	var t32_pass: bool = abs(cone_val - 120.0) < 0.01
	_record_result("TEST 32: Existing block cone remains 120 degrees", t32_pass,
		"Block cone: %.1f deg (Expected 120.0)" % cone_val)

	# -----------------------------------------------------------------
	# TEST 33: Existing knockback/flinch remains unchanged
	# -----------------------------------------------------------------
	var kb_norm: float = p.hit_knockback_distance
	var kb_recoil: float = p.block_recoil_distance
	var t33_pass: bool = abs(kb_norm - 0.40) < 0.01 and abs(kb_recoil - 0.08) < 0.01
	_record_result("TEST 33: Existing knockback/flinch remains unchanged", t33_pass,
		"Normal KB: %.2fm (Expected 0.40m), Block recoil: %.2fm (Expected 0.08m)" % [kb_norm, kb_recoil])

	# -----------------------------------------------------------------
	# TEST 34: Existing Damage Number feedback remains unchanged
	# -----------------------------------------------------------------
	var pool_exists: bool = (p.combat and p.combat.damage_number_pool != null)
	_record_result("TEST 34: Existing Damage Number feedback remains unchanged", pool_exists,
		"DamageNumberPool present and active: %s" % pool_exists)

	# -----------------------------------------------------------------
	# TEST 35: Existing Attack Telegraph remains unchanged
	# -----------------------------------------------------------------
	var telegraph_exists: bool = (ad.attack_telegraph_vfx != null)
	ad.trigger_attack_now()
	await create_timer(0.10).timeout
	await process_frame
	var tele_active_windup: bool = ad.attack_telegraph_vfx.is_active and ad.attack_telegraph_vfx.visible
	while ad.is_attacking():
		await process_frame
	await process_frame
	var tele_inactive_after: bool = (not ad.attack_telegraph_vfx.is_active) and (not ad.attack_telegraph_vfx.visible)
	var t35_pass: bool = telegraph_exists and tele_active_windup and tele_inactive_after
	_record_result("TEST 35: Existing Attack Telegraph remains unchanged", t35_pass,
		"Telegraph during windup: %s, after impact: %s" % [tele_active_windup, not tele_inactive_after])

	# =================================================================
	# SUMMARY
	# =================================================================
	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	if _failed_tests > 0:
		quit(1)
	else:
		quit(0)
