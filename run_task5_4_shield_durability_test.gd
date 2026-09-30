extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _dummy: TrainingDummy = null
var _dummy_health: HealthComponent = null


func _init() -> void:
	print("=================================================================")
	print("RUNTIME TEST SUITE: TASK 5.4 - SHIELD DURABILITY")
	print("=================================================================")
	call_deferred("_run_test_suite")


func _record_result(test_name: String, passed: bool, details: String) -> void:
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	var status: String = "PASS" if passed else "FAIL"
	print("[%s] %s: %s" % [status, test_name, details])


func _setup() -> PlayerController:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = ArenaScene.instantiate() as Node3D
	root.add_child(_arena)
	_player = _arena.get_node("Player") as PlayerController
	_dummy = _arena.get_node("TrainingDummy") as TrainingDummy
	_dummy_health = _dummy.get_node("HealthComponent") as HealthComponent
	return _player


func _reset_dummy() -> void:
	if _dummy_health:
		_dummy_health.current_health = _dummy_health.max_health
		_dummy_health.set("_is_dead", false)
	if _dummy:
		_dummy.reset_shield_durability()
		_dummy.global_position = Vector3(0, 0, 0)
		_dummy.rotation = Vector3.ZERO


func _run_test_suite() -> void:
	var p: PlayerController = _setup()
	for i in range(10): await process_frame
	
	var combat: PlayerCombat = p.combat
	var block_vfx: Node3D = combat.block_impact_vfx
	var hit_vfx: Node3D = combat.hit_impact_vfx
	
	# -----------------------------------------------------------------
	# TEST 1: Initial shield durability = 100
	# -----------------------------------------------------------------
	var dummy_init_dur: float = _dummy.shield_durability
	var player_init_dur: float = p.shield_durability
	var t1_pass: bool = abs(dummy_init_dur - 100.0) < 0.01 and abs(player_init_dur - 100.0) < 0.01
	_record_result("TEST 1: Initial shield durability = 100", t1_pass,
		"Dummy dur=%.1f (Max=%.1f), Player dur=%.1f (Max=%.1f)" % [dummy_init_dur, _dummy.shield_max_durability, player_init_dur, p.shield_max_durability])

	# -----------------------------------------------------------------
	# TEST 2: Successful frontal block reduces shield by exactly 15
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	_dummy.block_damage_reduction = 0.85
	
	p.set_third_person(true)
	p.global_position = Vector3(0, 0, -1.8)
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	p.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var dur_before_t2: float = _dummy.shield_durability
	var hp_before_t2: float = _dummy_health.current_health
	p._try_combat_attack()
	
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var dur_after_t2: float = _dummy.shield_durability
	var shield_damage_t2: float = dur_before_t2 - dur_after_t2
	var t2_pass: bool = abs(shield_damage_t2 - 15.0) < 0.01 and abs(dur_after_t2 - 85.0) < 0.01
	_record_result("TEST 2: Frontal block reduces shield by exactly 15", t2_pass,
		"Before=%.1f, After=%.1f, Shield damage=%.1f (Expected 15.0)" % [dur_before_t2, dur_after_t2, shield_damage_t2])

	# -----------------------------------------------------------------
	# TEST 3: Player HP still receives exactly 3.75 damage
	# -----------------------------------------------------------------
	var hp_damage_t2: float = hp_before_t2 - _dummy_health.current_health
	var t3_pass: bool = abs(hp_damage_t2 - 3.75) < 0.05
	_record_result("TEST 3: Defender HP receives exactly 3.75 damage", t3_pass,
		"HP Damage=%.2f (Expected 3.75, 85%% reduced)" % hp_damage_t2)

	# -----------------------------------------------------------------
	# TEST 4: Shield damage is independent of reduced HP damage
	# -----------------------------------------------------------------
	# Verify that combat exports normal_attack_shield_damage = 15.0 and apply_shield_damage is dedicated
	var t4_pass: bool = (combat.normal_attack_shield_damage == 15.0) and (abs(shield_damage_t2 - 15.0) < 0.01) and (abs(hp_damage_t2 - 3.75) < 0.01)
	_record_result("TEST 4: Shield damage is independent of reduced HP damage", t4_pass,
		"Shield damage constant=%.1f != HP damage=%.2f" % [combat.normal_attack_shield_damage, hp_damage_t2])

	# -----------------------------------------------------------------
	# TEST 5: Repeated blocks reduce durability: 100 -> 85 -> 70 -> 55 -> 40...
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	var expected_progression: Array[float] = [85.0, 70.0, 55.0, 40.0, 25.0, 10.0, 0.0]
	var progression_matched: bool = true
	var recorded_progression: Array[float] = []
	
	for expected_val in expected_progression:
		p._try_combat_attack()
		while p._is_attacking or combat._cooldown_timer > 0.0:
			await process_frame
		var cur_dur: float = _dummy.shield_durability
		recorded_progression.append(cur_dur)
		if abs(cur_dur - expected_val) > 0.01:
			progression_matched = false
			
	_record_result("TEST 5: Repeated blocks reduce durability (100->85->70->55->40->25->10->0)", progression_matched,
		"Progression: %s (Expected %s)" % [str(recorded_progression), str(expected_progression)])

	# -----------------------------------------------------------------
	# TEST 6: Shield clamps at 0 and never becomes negative
	# -----------------------------------------------------------------
	# One more blocked attack when durability is already 0.0
	p._try_combat_attack()
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var cur_dur_at_zero: float = _dummy.shield_durability
	var t6_pass: bool = (cur_dur_at_zero == 0.0) and (not (cur_dur_at_zero < 0.0))
	_record_result("TEST 6: Shield clamps at 0 and never becomes negative", t6_pass,
		"Durability after extra block at 0: %.1f (Clamped at 0.0)" % cur_dur_at_zero)

	# -----------------------------------------------------------------
	# TEST 7: No-block attack does not reduce shield durability
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = false
	var dur_before_t7: float = _dummy.shield_durability
	var hp_before_t7: float = _dummy_health.current_health
	p._try_combat_attack()
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var dur_after_t7: float = _dummy.shield_durability
	var hp_damage_t7: float = hp_before_t7 - _dummy_health.current_health
	var t7_pass: bool = (dur_after_t7 == dur_before_t7) and (abs(hp_damage_t7 - 25.0) < 0.05)
	_record_result("TEST 7: No-block attack does not reduce shield durability", t7_pass,
		"Dur before=%.1f, Dur after=%.1f (HP Damage=%.1f)" % [dur_before_t7, dur_after_t7, hp_damage_t7])

	# -----------------------------------------------------------------
	# TEST 8: Rear attack does not reduce shield durability
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	# Dummy faces North (-Z). Player attacks from South (+Z) behind dummy
	p.global_position = Vector3(0, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	
	var dur_before_t8: float = _dummy.shield_durability
	var hp_before_t8: float = _dummy_health.current_health
	p._try_combat_attack()
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var dur_after_t8: float = _dummy.shield_durability
	var hp_damage_t8: float = hp_before_t8 - _dummy_health.current_health
	var t8_pass: bool = (dur_after_t8 == dur_before_t8) and (abs(hp_damage_t8 - 25.0) < 0.05)
	_record_result("TEST 8: Rear attack does not reduce shield durability", t8_pass,
		"Dur before=%.1f, Dur after=%.1f (Full HP Damage=%.1f)" % [dur_before_t8, dur_after_t8, hp_damage_t8])

	# -----------------------------------------------------------------
	# TEST 9: Flank/outside-cone attack does not reduce shield durability
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	# 75° angle outside 120° block cone
	var angle_75_rad: float = deg_to_rad(75.0)
	var flank_pos: Vector3 = Vector3(1.8 * sin(angle_75_rad), 0, -1.8 * cos(angle_75_rad))
	p.global_position = flank_pos
	var to_dummy: Vector3 = (_dummy.global_position - flank_pos).normalized()
	var flank_yaw: float = atan2(-to_dummy.x, -to_dummy.z)
	p._camera_yaw = flank_yaw
	p.camera_pivot.rotation.y = flank_yaw
	p.visuals.rotation.y = flank_yaw
	await process_frame
	
	var dur_before_t9: float = _dummy.shield_durability
	var hp_before_t9: float = _dummy_health.current_health
	p._try_combat_attack()
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var dur_after_t9: float = _dummy.shield_durability
	var hp_damage_t9: float = hp_before_t9 - _dummy_health.current_health
	var t9_pass: bool = (dur_after_t9 == dur_before_t9) and (abs(hp_damage_t9 - 25.0) < 0.05)
	_record_result("TEST 9: Flank attack does not reduce shield durability", t9_pass,
		"Dur before=%.1f, Dur after=%.1f (Full HP Damage=%.1f)" % [dur_before_t9, dur_after_t9, hp_damage_t9])

	# -----------------------------------------------------------------
	# TEST 10: Block Impact VFX still works
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	p.global_position = Vector3(0, 0, -1.8)
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	p.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	p._try_combat_attack()
	var t10_block_shown: bool = false
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			t10_block_shown = true
			break
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	_record_result("TEST 10: Block Impact VFX still works", t10_block_shown,
		"Block Impact VFX triggered on block: %s" % t10_block_shown)

	# -----------------------------------------------------------------
	# TEST 11: Hit Impact VFX still works for unblocked attacks
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = false
	p._try_combat_attack()
	var t11_hit_shown: bool = false
	var t11_block_accident: bool = false
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			t11_hit_shown = true
		if block_vfx.visible:
			t11_block_accident = true
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var t11_pass: bool = t11_hit_shown and (not t11_block_accident)
	_record_result("TEST 11: Hit Impact VFX still works for unblocked attacks", t11_pass,
		"Hit VFX triggered=%s, Block VFX stayed hidden=%s" % [t11_hit_shown, not t11_block_accident])

	# -----------------------------------------------------------------
	# TEST 12: FPS block works (both attack against blocking dummy and player blocking)
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	p.set_third_person(false) # Switch to FPS
	await process_frame
	
	p.global_position = Vector3(0, 0, -1.8)
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	# Part A: Player in FPS attacks blocking dummy
	var dur_before_fps: float = _dummy.shield_durability
	p._try_combat_attack()
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var fps_attack_pass: bool = abs((dur_before_fps - _dummy.shield_durability) - 15.0) < 0.01
	
	# Part B: Player in FPS blocks incoming damage
	p.reset_shield_durability()
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame
	var p_hp_before_fps: float = p.health_component.current_health
	p.take_damage(25.0, Vector3(0, 0, 0)) # Attacker at (0, 0, 0) directly in front of player at (0, 0, -1.8)
	var p_dur_after_fps: float = p.shield_durability
	var p_hp_loss_fps: float = p_hp_before_fps - p.health_component.current_health
	var fps_defense_pass: bool = abs(p_dur_after_fps - 85.0) < 0.01 and abs(p_hp_loss_fps - 3.75) < 0.05
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame
	
	var t12_pass: bool = fps_attack_pass and fps_defense_pass
	_record_result("TEST 12: FPS block works", t12_pass,
		"FPS attack block dur reduced=15: %s, FPS player block dur reduced=15 & HP reduced=3.75: %s" % [fps_attack_pass, fps_defense_pass])

	# -----------------------------------------------------------------
	# TEST 13: TPS block works (both attack against blocking dummy and player blocking)
	# -----------------------------------------------------------------
	_reset_dummy()
	_dummy.is_blocking = true
	p.set_third_person(true) # Switch back to TPS
	await process_frame
	
	# Part A: Player in TPS attacks blocking dummy facing East
	_dummy.rotation.y = deg_to_rad(-90.0) # Faces East (+X)
	p.global_position = Vector3(1.8, 0, 0) # East of dummy, facing West (-X)
	p._camera_yaw = deg_to_rad(90.0)
	p.camera_pivot.rotation.y = deg_to_rad(90.0)
	p.visuals.rotation.y = deg_to_rad(90.0)
	await process_frame
	
	var dur_before_tps: float = _dummy.shield_durability
	p._try_combat_attack()
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
	var tps_attack_pass: bool = abs((dur_before_tps - _dummy.shield_durability) - 15.0) < 0.01
	
	# Part B: Player in TPS blocks incoming damage
	p.reset_shield_durability()
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame
	var p_hp_before_tps: float = p.health_component.current_health
	p.take_damage(25.0, Vector3(0, 0, 0)) # Attacker at (0, 0, 0) directly in front of player at (1.8, 0, 0)
	var p_dur_after_tps: float = p.shield_durability
	var p_hp_loss_tps: float = p_hp_before_tps - p.health_component.current_health
	var tps_defense_pass: bool = abs(p_dur_after_tps - 85.0) < 0.01 and abs(p_hp_loss_tps - 3.75) < 0.05
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame
	
	var t13_pass: bool = tps_attack_pass and tps_defense_pass
	_record_result("TEST 13: TPS block works", t13_pass,
		"TPS attack block dur reduced=15: %s, TPS player block dur reduced=15 & HP reduced=3.75: %s" % [tps_attack_pass, tps_defense_pass])

	# -----------------------------------------------------------------
	# TEST 14: Block lifecycle respects Task 5.5 contract (rejected at 0/broken, works after reset)
	# -----------------------------------------------------------------
	# Break shield to 0
	p.shield_durability = 10.0
	p.apply_shield_damage(15.0) # Causes break to 0
	await process_frame
	var block_rejected_at_zero: bool = (not p._start_block()) and (p.combat_state != PlayerController.CombatState.BLOCK)
	
	# Restore shield to 100
	p.reset_shield_durability()
	p._start_block()
	await process_frame
	var block_started_after_restore: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	
	# Release RMB
	p._release_block()
	while p._block_transition != "" or p.combat_state == PlayerController.CombatState.BLOCK:
		await process_frame
	var block_released_cleanly: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	
	var t14_pass: bool = block_rejected_at_zero and block_started_after_restore and block_released_cleanly
	_record_result("TEST 14: Block lifecycle respects Task 5.5 contract at 0 and restored", t14_pass,
		"Block rejected at 0 dur: %s, Block entered after restore: %s, Cleanly exited: %s" % [block_rejected_at_zero, block_started_after_restore, block_released_cleanly])

	# -----------------------------------------------------------------
	# TEST 15: No node accumulation or unrelated combat regression
	# -----------------------------------------------------------------
	var initial_children: int = combat.get_child_count()
	for i in range(3):
		p._try_combat_attack()
		for f in range(25):
			await process_frame
		while p._is_attacking or combat._cooldown_timer > 0.0:
			await process_frame
	var final_children: int = combat.get_child_count()
	var t15_pass: bool = (initial_children == final_children)
	_record_result("TEST 15: No node accumulation or combat regression", t15_pass,
		"Child count unchanged: %s (%d -> %d)" % [t15_pass, initial_children, final_children])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("\n=================================================================")
	var total: int = _test_results.size()
	var passed: int = 0
	for r in _test_results:
		if r["passed"]:
			passed += 1
	print("TASK 5.4 TEST SUMMARY: %d / %d TESTS PASSED" % [passed, total])
	print("=================================================================")
	
	if passed == total:
		quit(0)
	else:
		quit(1)
