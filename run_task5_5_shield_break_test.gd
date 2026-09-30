extends SceneTree

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _results: Array[Dictionary] = []

var _player: PlayerController
var _combat: PlayerCombat
var _dummy: TrainingDummy
var _dummy_health: HealthComponent


func _init() -> void:
	call_deferred("_run_tests")


func _record_result(test_name: String, passed: bool, details: String = "") -> void:
	_total_tests += 1
	if passed:
		_passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed_tests += 1
		print("  [FAIL] %s - %s" % [test_name, details])
	_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})


func _setup_environment() -> void:
	var root_node: Node3D = Node3D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	var player_scene: PackedScene = load("res://scenes/Player.tscn")
	_player = player_scene.instantiate() as PlayerController
	_player.position = Vector3.ZERO
	root_node.add_child(_player)
	_combat = _player.combat

	var dummy_scene: PackedScene = load("res://scenes/TrainingDummy.tscn")
	_dummy = dummy_scene.instantiate() as TrainingDummy
	_dummy.position = Vector3(0, 0, 1.8)
	root_node.add_child(_dummy)
	_dummy_health = _dummy.health_component


func _run_tests() -> void:
	print("==================================================")
	print("RUNNING TASK 5.5 ACCEPTANCE TESTS: SHIELD BREAK")
	print("==================================================")

	_setup_environment()
	await process_frame
	await process_frame

	var p: PlayerController = _player
	var combat: PlayerCombat = _combat
	var block_vfx: Node3D = combat.block_impact_vfx
	var break_vfx: Node3D = combat.shield_break_vfx

	# Attacker position directly in front of player (facing +Z)
	var attacker_pos: Vector3 = Vector3(0, 0, 10.0)
	p.visuals.rotation.y = deg_to_rad(180.0) # Faces +Z
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)

	# -----------------------------------------------------------------
	# TEST 1: Shield starts at 100 and blocks normally
	# -----------------------------------------------------------------
	p.reset_shield_durability()
	p.health_component.current_health = 100.0
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var t1_initial_dur: float = p.shield_durability
	var t1_hp_before: float = p.health_component.current_health
	p.take_damage(25.0, attacker_pos, 15.0)
	var t1_dur_after: float = p.shield_durability
	var t1_hp_loss: float = t1_hp_before - p.health_component.current_health

	var t1_pass: bool = (t1_initial_dur == 100.0) and (abs(t1_dur_after - 85.0) < 0.01) and (abs(t1_hp_loss - 3.75) < 0.05)
	_record_result("TEST 1: Shield starts at 100 and blocks normally", t1_pass,
		"Init Dur=%.1f, After=%.1f (expected 85.0), HP Loss=%.2f (expected 3.75)" % [t1_initial_dur, t1_dur_after, t1_hp_loss])

	# -----------------------------------------------------------------
	# TEST 2: Repeated blocks reduce shield correctly
	# 85 -> 70 -> 55 -> 40 -> 25 -> 10
	# -----------------------------------------------------------------
	var expected_durations: Array[float] = [70.0, 55.0, 40.0, 25.0, 10.0]
	var t2_all_steps_valid: bool = true
	var t2_err: String = ""

	for expected_dur in expected_durations:
		var hp_prev: float = p.health_component.current_health
		p.take_damage(25.0, attacker_pos, 15.0)
		var hp_loss: float = hp_prev - p.health_component.current_health
		if abs(p.shield_durability - expected_dur) > 0.01 or abs(hp_loss - 3.75) > 0.05:
			t2_all_steps_valid = false
			t2_err = "Dur=%.1f (expected %.1f), HP Loss=%.2f" % [p.shield_durability, expected_dur, hp_loss]
			break

	_record_result("TEST 2: Repeated blocks reduce shield correctly (85 -> 10)", t2_all_steps_valid, t2_err)

	# -----------------------------------------------------------------
	# TEST 3: Final block from 10 -> 0 triggers Shield Break exactly once
	# -----------------------------------------------------------------
	var dur_before_break: float = p.shield_durability # Should be 10.0
	var hp_before_break: float = p.health_component.current_health
	var break_count_before: int = p._shield_break_count

	# Final 7th attack: 10 -> 0
	p.take_damage(25.0, attacker_pos, 15.0)

	var t3_pass: bool = (dur_before_break == 10.0) and (p.shield_durability == 0.0) and p.is_shield_broken and (p._shield_break_count == break_count_before + 1)
	_record_result("TEST 3: Final block from 10 -> 0 triggers Shield Break exactly once", t3_pass,
		"Dur before=%.1f, Dur after=%.1f, is_broken=%s, break_count=%d" % [dur_before_break, p.shield_durability, p.is_shield_broken, p._shield_break_count])

	# -----------------------------------------------------------------
	# TEST 4: Final attack still receives the existing blocked damage reduction
	# -----------------------------------------------------------------
	var hp_loss_final_block: float = hp_before_break - p.health_component.current_health
	var t4_pass: bool = abs(hp_loss_final_block - 3.75) < 0.05
	_record_result("TEST 4: Final attack still receives the existing blocked damage reduction", t4_pass,
		"HP Loss on final block=%.2f (expected 3.75)" % hp_loss_final_block)

	# -----------------------------------------------------------------
	# TEST 5: Shield Break VFX triggers exactly once
	# -----------------------------------------------------------------
	var t5_pass: bool = break_vfx != null and break_vfx.visible == true
	_record_result("TEST 5: Shield Break VFX triggers exactly once", t5_pass,
		"Break VFX exists: %s, Break VFX visible: %s" % [break_vfx != null, break_vfx.visible if break_vfx else false])

	# -----------------------------------------------------------------
	# TEST 6: Player enters temporary broken/stagger state
	# -----------------------------------------------------------------
	var horiz_vel_zero: bool = abs(p.velocity.x) < 0.001 and abs(p.velocity.z) < 0.001
	var t6_pass: bool = p.is_shield_broken and p.is_shield_stunned and (p.combat_state == PlayerController.CombatState.IDLE) and horiz_vel_zero
	_record_result("TEST 6: Player enters temporary broken/stagger state", t6_pass,
		"is_broken=%s, is_stunned=%s, combat_state=%s, horiz_vel_zero=%s" % [p.is_shield_broken, p.is_shield_stunned, p.combat_state, horiz_vel_zero])

	# -----------------------------------------------------------------
	# TEST 7: RMB cannot re-enter BLOCK while shield is broken
	# -----------------------------------------------------------------
	var block_start_attempt: bool = p._start_block()
	var combat_state_after_rmb: PlayerController.CombatState = p.combat_state
	p.is_blocking = true
	var is_blocking_prop: bool = p.is_blocking
	var t7_pass: bool = (not block_start_attempt) and (combat_state_after_rmb == PlayerController.CombatState.IDLE) and (not is_blocking_prop)
	_record_result("TEST 7: RMB cannot re-enter BLOCK while shield is broken", t7_pass,
		"_start_block returned=%s, state=%s, is_blocking=%s" % [block_start_attempt, combat_state_after_rmb, is_blocking_prop])

	# -----------------------------------------------------------------
	# TEST 8: Incoming attack while broken deals FULL damage
	# -----------------------------------------------------------------
	if block_vfx:
		block_vfx.visible = false
	var hp_before_broken_hit: float = p.health_component.current_health
	p.take_damage(25.0, attacker_pos, 15.0)
	var hp_loss_broken_hit: float = hp_before_broken_hit - p.health_component.current_health
	var t8_pass: bool = abs(hp_loss_broken_hit - 25.0) < 0.05
	_record_result("TEST 8: Incoming attack while broken deals FULL damage", t8_pass,
		"HP Loss while broken=%.2f (expected 25.0)" % hp_loss_broken_hit)

	# -----------------------------------------------------------------
	# TEST 9: Block Impact VFX does NOT trigger while broken
	# -----------------------------------------------------------------
	var t9_pass: bool = block_vfx != null and (not block_vfx.visible)
	_record_result("TEST 9: Block Impact VFX does NOT trigger while broken", t9_pass,
		"Block VFX visible: %s (expected false)" % (block_vfx.visible if block_vfx else false))

	# -----------------------------------------------------------------
	# TEST 10: Shield remains at 0 during broken/recovery state
	# -----------------------------------------------------------------
	var t10_pass: bool = (p.shield_durability == 0.0) and p.is_shield_broken
	_record_result("TEST 10: Shield remains at 0 during broken/recovery state", t10_pass,
		"Shield durability=%.1f, is_broken=%s" % [p.shield_durability, p.is_shield_broken])

	# -----------------------------------------------------------------
	# TEST 11: Shield restores to 100 after recovery
	# -----------------------------------------------------------------
	var sim_time: float = 0.0
	while p.is_shield_broken and sim_time < 3.5:
		p._physics_process(0.05)
		sim_time += 0.05
		await process_frame

	var t11_pass: bool = (p.shield_durability == 100.0) and (not p.is_shield_broken) and (not p.is_shield_stunned)
	_record_result("TEST 11: Shield restores to 100 after recovery", t11_pass,
		"Restored dur=%.1f (expected 100.0), is_broken=%s, is_stunned=%s in %.2fs" % [p.shield_durability, p.is_shield_broken, p.is_shield_stunned, sim_time])

	# -----------------------------------------------------------------
	# TEST 12: Player can block normally again after recovery
	# -----------------------------------------------------------------
	var can_block_now: bool = p.can_block()
	var block_started: bool = p._start_block()
	var state_in_block: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	var hp_before_rec_hit: float = p.health_component.current_health
	p.take_damage(25.0, attacker_pos, 15.0)
	var hp_loss_rec_hit: float = hp_before_rec_hit - p.health_component.current_health
	var dur_after_rec_hit: float = p.shield_durability
	p._release_block()
	await process_frame

	var t12_pass: bool = can_block_now and block_started and state_in_block and (abs(hp_loss_rec_hit - 3.75) < 0.05) and (abs(dur_after_rec_hit - 85.0) < 0.01)
	_record_result("TEST 12: Player can block normally again after recovery", t12_pass,
		"can_block=%s, started=%s, state_in_block=%s, HP loss=%.2f, Dur=%.1f" % [can_block_now, block_started, state_in_block, hp_loss_rec_hit, dur_after_rec_hit])

	# -----------------------------------------------------------------
	# TEST 13: No duplicate break events
	# -----------------------------------------------------------------
	p.health_component.current_health = 100.0 # Replenish health so extra hits don't kill player
	p.shield_durability = 10.0
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame
	var breaks_before_dup: int = p._shield_break_count
	p.take_damage(25.0, attacker_pos, 15.0) # Causes break
	var breaks_after_first: int = p._shield_break_count
	p.take_damage(25.0, attacker_pos, 15.0) # Extra hit while broken
	p.take_damage(25.0, attacker_pos, 15.0) # Extra hit while broken
	p.apply_shield_damage(15.0) # Direct call while broken
	var breaks_after_extras: int = p._shield_break_count

	var t13_pass: bool = (breaks_after_first == breaks_before_dup + 1) and (breaks_after_extras == breaks_after_first)
	_record_result("TEST 13: No duplicate break events", t13_pass,
		"Breaks before=%d, after first=%d, after extra hits=%d" % [breaks_before_dup, breaks_after_first, breaks_after_extras])

	# -----------------------------------------------------------------
	# TEST 14: No node accumulation
	# -----------------------------------------------------------------
	var initial_child_count: int = combat.get_child_count()
	for i in range(3):
		combat.trigger_shield_break(Vector3(0, 1, 0), Vector3.FORWARD)
		combat.trigger_block_impact(Vector3(0, 1, 0), Vector3.BACK)
		await process_frame
	var final_child_count: int = combat.get_child_count()
	var t14_pass: bool = (initial_child_count == final_child_count)
	_record_result("TEST 14: No node accumulation", t14_pass,
		"Initial children=%d, Final children=%d" % [initial_child_count, final_child_count])

	# -----------------------------------------------------------------
	# TEST 15: FPS works
	# -----------------------------------------------------------------
	p.set_third_person(false) # First-person mode
	p.reset_shield_durability()
	p.health_component.current_health = 100.0
	p._camera_yaw = deg_to_rad(180.0) # Face +Z toward attacker
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	p.visuals.rotation.y = deg_to_rad(180.0)
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	p.take_damage(25.0, attacker_pos, 15.0) # 100 -> 85
	var fps_block_valid: bool = abs(p.shield_durability - 85.0) < 0.01

	# Force to 10 and break
	p.shield_durability = 10.0
	p.take_damage(25.0, attacker_pos, 15.0) # 10 -> 0, break
	var fps_break_valid: bool = p.is_shield_broken and p.is_shield_stunned and (p.shield_durability == 0.0)

	# Recovery in FPS
	sim_time = 0.0
	while p.is_shield_broken and sim_time < 3.0:
		p._physics_process(0.05)
		sim_time += 0.05
		await process_frame
	var fps_rec_valid: bool = (p.shield_durability == 100.0) and (not p.is_shield_broken)

	var t15_pass: bool = fps_block_valid and fps_break_valid and fps_rec_valid
	_record_result("TEST 15: FPS works", t15_pass,
		"FPS Block: %s, FPS Break: %s, FPS Recovery: %s" % [fps_block_valid, fps_break_valid, fps_rec_valid])

	# -----------------------------------------------------------------
	# TEST 16: TPS works
	# -----------------------------------------------------------------
	p.set_third_person(true) # Third-person mode
	p.reset_shield_durability()
	p.health_component.current_health = 100.0
	p._camera_yaw = deg_to_rad(180.0) # Face +Z toward attacker
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	p.visuals.rotation.y = deg_to_rad(180.0)
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	p.take_damage(25.0, attacker_pos, 15.0) # 100 -> 85
	var tps_block_valid: bool = abs(p.shield_durability - 85.0) < 0.01

	p.shield_durability = 10.0
	p.take_damage(25.0, attacker_pos, 15.0) # 10 -> 0, break
	var tps_break_valid: bool = p.is_shield_broken and p.is_shield_stunned and (p.shield_durability == 0.0)

	sim_time = 0.0
	while p.is_shield_broken and sim_time < 3.0:
		p._physics_process(0.05)
		sim_time += 0.05
		await process_frame
	var tps_rec_valid: bool = (p.shield_durability == 100.0) and (not p.is_shield_broken)

	var t16_pass: bool = tps_block_valid and tps_break_valid and tps_rec_valid
	_record_result("TEST 16: TPS works", t16_pass,
		"TPS Block: %s, TPS Break: %s, TPS Recovery: %s" % [tps_block_valid, tps_break_valid, tps_rec_valid])

	# -----------------------------------------------------------------
	# TEST 17: Existing attack behavior remains functional
	# -----------------------------------------------------------------
	# Attack while in broken recovery (after stun)
	p.health_component.current_health = 100.0
	p.break_shield()
	p._shield_stun_timer = 0.0 # Stun ended, recovery still active
	combat._cooldown_timer = 0.0
	var can_atk_in_rec: bool = p._try_combat_attack()
	var is_in_atk: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	while p.combat_state == PlayerController.CombatState.ATTACK or combat._cooldown_timer > 0.0:
		p._physics_process(0.05)
		combat._physics_process(0.05)
		await process_frame

	p.reset_shield_durability()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame
	combat._cooldown_timer = 0.0
	var normal_atk_attempt: bool = p._try_combat_attack()
	var normal_is_in_atk: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	while p.combat_state == PlayerController.CombatState.ATTACK or combat._cooldown_timer > 0.0:
		p._physics_process(0.05)
		combat._physics_process(0.05)
		await process_frame

	var t17_pass: bool = can_atk_in_rec and is_in_atk and normal_atk_attempt and normal_is_in_atk
	_record_result("TEST 17: Existing attack behavior remains functional", t17_pass,
		"Atk in rec: %s (state=%s), Normal atk: %s (state=%s)" % [can_atk_in_rec, is_in_atk, normal_atk_attempt, normal_is_in_atk])

	# -----------------------------------------------------------------
	# TEST 18: Existing death behavior remains functional
	# -----------------------------------------------------------------
	p.health_component.take_damage(200.0) # Lethal damage
	await process_frame
	var is_dead_state: bool = (p.combat_state == PlayerController.CombatState.DEAD)
	var cannot_block_dead: bool = not p._start_block()
	var cannot_attack_dead: bool = not p._try_combat_attack()
	var break_count_dead: int = p._shield_break_count
	p.break_shield() # Should be ignored when dead
	var cannot_break_dead: bool = (p._shield_break_count == break_count_dead)

	var t18_pass: bool = is_dead_state and cannot_block_dead and cannot_attack_dead and cannot_break_dead
	_record_result("TEST 18: Existing death behavior remains functional", t18_pass,
		"Dead state=%s, Block dead rejected=%s, Atk dead rejected=%s, Break dead ignored=%s" % [is_dead_state, cannot_block_dead, cannot_attack_dead, cannot_break_dead])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	quit(_failed_tests)
