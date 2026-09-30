extends SceneTree

const TestArenaScene: PackedScene = preload("res://scenes/CombatTestArena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _training_dummy: TrainingDummy = null
var _attack_dummy: Node3D = null


func _init() -> void:
	print("=================================================================")
	print("RUNTIME TEST SUITE: COMBAT TESTING TOOL & ATTACK DUMMY")
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


func _setup() -> void:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()
	_arena = TestArenaScene.instantiate() as Node3D
	root.add_child(_arena)
	_player = _arena.get_node("Player") as PlayerController
	_training_dummy = _arena.get_node("TrainingDummy") as TrainingDummy
	_attack_dummy = _arena.get_node("AttackTrainingDummy") as Node3D


func _run_test_suite() -> void:
	_setup()
	for i in range(10): await process_frame

	# Disable auto_attack on attack dummy initially to control test sequence
	_attack_dummy.auto_attack = false
	if _attack_dummy._cycle_tween and _attack_dummy._cycle_tween.is_valid():
		_attack_dummy._cycle_tween.kill()

	# -----------------------------------------------------------------
	# TEST 1: Existing TrainingDummy starts at full HP
	# -----------------------------------------------------------------
	var dummy_hp_init: float = _training_dummy.health_component.current_health
	var t1_pass: bool = abs(dummy_hp_init - 100.0) < 0.01
	_record_result("TEST 1: Existing TrainingDummy starts at full HP", t1_pass,
		"Current HP=%.1f / %.1f" % [dummy_hp_init, _training_dummy.health_component.max_health])

	# -----------------------------------------------------------------
	# TEST 2: Player can damage Existing TrainingDummy
	# -----------------------------------------------------------------
	# Move player to training dummy (at 3.5, 0, 0)
	_player.global_position = Vector3(3.5, 0, 1.8) # 1.8m South of dummy
	_player._camera_yaw = 0.0 # Facing North (-Z) toward dummy
	_player.camera_pivot.rotation.y = 0.0
	_player.visuals.rotation.y = 0.0
	await process_frame

	var hp_before_t2: float = _training_dummy.health_component.current_health
	_player._try_combat_attack()
	while _player._is_attacking or _player.combat._cooldown_timer > 0.0:
		await process_frame
	var hp_after_t2: float = _training_dummy.health_component.current_health
	var t2_damage: float = hp_before_t2 - hp_after_t2
	var t2_pass: bool = abs(t2_damage - 25.0) < 0.01
	_record_result("TEST 2: Player can damage Existing TrainingDummy", t2_pass,
		"Damage dealt=%.1f (HP: %.1f -> %.1f)" % [t2_damage, hp_before_t2, hp_after_t2])

	# -----------------------------------------------------------------
	# TEST 3: Existing TrainingDummy reaches 0 HP
	# -----------------------------------------------------------------
	_training_dummy.take_damage(75.0)
	var t3_dead: bool = _training_dummy.health_component.is_dead()
	var t3_hp: float = _training_dummy.health_component.current_health
	var t3_pass: bool = t3_dead and (t3_hp == 0.0)
	_record_result("TEST 3: Existing TrainingDummy reaches 0 HP", t3_pass,
		"HP=%.1f, is_dead=%s" % [t3_hp, t3_dead])

	# -----------------------------------------------------------------
	# TEST 4: Existing TrainingDummy automatically resets to full HP
	# -----------------------------------------------------------------
	# Default reset_delay is 1.0s. Wait 1.25s
	await create_timer(1.25).timeout
	var hp_after_reset: float = _training_dummy.health_component.current_health
	var is_dead_after_reset: bool = _training_dummy.health_component.is_dead()
	var t4_pass: bool = abs(hp_after_reset - 100.0) < 0.01 and (not is_dead_after_reset)
	_record_result("TEST 4: Existing TrainingDummy automatically resets to full HP", t4_pass,
		"HP after reset=%.1f, is_dead=%s" % [hp_after_reset, is_dead_after_reset])

	# -----------------------------------------------------------------
	# TEST 5: Player can damage it again after reset
	# -----------------------------------------------------------------
	var hp_before_t5: float = _training_dummy.health_component.current_health
	_player._try_combat_attack()
	while _player._is_attacking or _player.combat._cooldown_timer > 0.0:
		await process_frame
	var hp_after_t5: float = _training_dummy.health_component.current_health
	var t5_damage: float = hp_before_t5 - hp_after_t5
	var t5_pass: bool = abs(t5_damage - 25.0) < 0.01 and abs(hp_after_t5 - 75.0) < 0.01
	_record_result("TEST 5: Player can damage it again after reset", t5_pass,
		"Damage dealt=%.1f (Remaining HP=%.1f)" % [t5_damage, hp_after_t5])

	# -----------------------------------------------------------------
	# TEST 6: No duplicate reset behavior
	# -----------------------------------------------------------------
	# Dummy is at 75 HP (alive). Wait 1.2s and verify it has NOT reset to 100
	await create_timer(1.20).timeout
	var hp_stable: float = _training_dummy.health_component.current_health
	var t6_pass: bool = abs(hp_stable - 75.0) < 0.01
	_record_result("TEST 6: No duplicate reset behavior while alive", t6_pass,
		"HP remained %.1f (no spurious reset triggered)" % hp_stable)

	# -----------------------------------------------------------------
	# TEST 7: AttackTrainingDummy remains stationary
	# -----------------------------------------------------------------
	var attack_dummy_init_pos: Vector3 = _attack_dummy.global_position
	var t7_pass: bool = attack_dummy_init_pos.distance_to(Vector3(0, 0, -1.8)) < 0.01
	_record_result("TEST 7: AttackTrainingDummy initial fixed position verified", t7_pass,
		"Position=%s" % attack_dummy_init_pos)

	# -----------------------------------------------------------------
	# TEST 8: AttackTrainingDummy does not have a health bar
	# -----------------------------------------------------------------
	var has_progress_bar: bool = _attack_dummy.find_child("ProgressBar", true, false) != null
	var has_health_viewport: bool = _attack_dummy.find_child("HealthBarViewport", true, false) != null
	var has_health_component: bool = _attack_dummy.find_child("HealthComponent", true, false) != null
	var t8_pass: bool = (not has_progress_bar) and (not has_health_viewport) and (not has_health_component)
	_record_result("TEST 8: AttackTrainingDummy does not have a health bar", t8_pass,
		"ProgressBar=%s, Viewport=%s, HealthComp=%s" % [has_progress_bar, has_health_viewport, has_health_component])

	# -----------------------------------------------------------------
	# TEST 9: AttackTrainingDummy automatically attacks
	# -----------------------------------------------------------------
	# Move player to center (0, 0, 0), facing dummy at (0, 0, -1.8)
	_player.global_position = Vector3(0, 0, 0)
	_player._camera_yaw = 0.0 # Facing North (-Z)
	_player.camera_pivot.rotation.y = 0.0
	_player.visuals.rotation.y = 0.0
	_player.health_component.reset_health()
	await process_frame

	_attack_dummy.trigger_attack_now()
	var attack_active_t9: bool = _attack_dummy.is_attacking()
	var t9_pass: bool = attack_active_t9
	_record_result("TEST 9: AttackTrainingDummy performs attack cycle", t9_pass,
		"Attack sequence triggered, is_attacking=%s" % attack_active_t9)

	# -----------------------------------------------------------------
	# TEST 10: AttackTrainingDummy deals 25 damage when player is in range
	# -----------------------------------------------------------------
	# Wait for the attack impact and recovery to complete (~0.75s)
	var hp_before_t10: float = _player.health_component.current_health
	await create_timer(0.85).timeout
	var hp_after_t10: float = _player.health_component.current_health
	var damage_t10: float = hp_before_t10 - hp_after_t10
	var t10_pass: bool = abs(damage_t10 - 25.0) < 0.01
	_record_result("TEST 10: AttackTrainingDummy deals 25 damage in range", t10_pass,
		"Player HP: %.1f -> %.1f (Damage=%.1f, Expected 25.0)" % [hp_before_t10, hp_after_t10, damage_t10])

	# -----------------------------------------------------------------
	# TEST 11: Player can block the AttackTrainingDummy
	# -----------------------------------------------------------------
	_player.global_position = Vector3(0, 0, 0)
	_player.health_component.reset_health()
	_player.reset_shield_durability()
	_player.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame
	var t11_pass: bool = (_player.combat_state == PlayerController.CombatState.BLOCK) and _player.is_blocking
	_record_result("TEST 11: Player can enter block against AttackTrainingDummy", t11_pass,
		"combat_state=BLOCK, is_blocking=%s" % _player.is_blocking)

	# -----------------------------------------------------------------
	# TEST 12: Frontal block correctly reduces damage
	# -----------------------------------------------------------------
	var hp_before_t12: float = _player.health_component.current_health
	_attack_dummy.trigger_attack_now()
	await create_timer(0.85).timeout
	var hp_after_t12: float = _player.health_component.current_health
	var damage_t12: float = hp_before_t12 - hp_after_t12
	var t12_pass: bool = abs(damage_t12 - 3.75) < 0.05
	_record_result("TEST 12: Frontal block correctly reduces damage", t12_pass,
		"Player HP: %.1f -> %.1f (Damage=%.2f, Expected 3.75 / 85%% reduction)" % [hp_before_t12, hp_after_t12, damage_t12])

	# -----------------------------------------------------------------
	# TEST 13: Rear attack is not blocked by player's 120-degree cone
	# -----------------------------------------------------------------
	# Player at (0, 0, 0) blocks facing South (+Z), away from dummy at (0, 0, -1.8)
	_player.global_position = Vector3(0, 0, 0)
	_player._camera_yaw = deg_to_rad(180.0)
	_player.camera_pivot.rotation.y = deg_to_rad(180.0)
	_player.visuals.rotation.y = deg_to_rad(180.0)
	_player.health_component.reset_health()
	_player.reset_shield_durability()
	await process_frame

	var hp_before_t13: float = _player.health_component.current_health
	var dur_before_t13: float = _player.shield_durability
	_attack_dummy.trigger_attack_now()
	await create_timer(0.85).timeout
	var hp_after_t13: float = _player.health_component.current_health
	var dur_after_t13: float = _player.shield_durability
	var damage_t13: float = hp_before_t13 - hp_after_t13
	var t13_pass: bool = abs(damage_t13 - 25.0) < 0.01 and (dur_after_t13 == dur_before_t13)
	_record_result("TEST 13: Rear attack bypasses block cone (full damage)", t13_pass,
		"Full Damage=%.1f (Expected 25.0), Shield dur unchanged=%.1f" % [damage_t13, dur_after_t13])

	# -----------------------------------------------------------------
	# TEST 14: AttackTrainingDummy does not move toward player
	# -----------------------------------------------------------------
	var cur_attack_dummy_pos: Vector3 = _attack_dummy.global_position
	var drift: float = cur_attack_dummy_pos.distance_to(attack_dummy_init_pos)
	var t14_pass: bool = drift < 0.001
	_record_result("TEST 14: AttackTrainingDummy did not move toward player", t14_pass,
		"Initial pos=%s, Current pos=%s (Drift=%.4fm)" % [attack_dummy_init_pos, cur_attack_dummy_pos, drift])

	# -----------------------------------------------------------------
	# TEST 15: Repeated attack cycles work without node accumulation
	# -----------------------------------------------------------------
	var initial_children: int = _attack_dummy.get_child_count()
	for i in range(2):
		_attack_dummy.trigger_attack_now()
		await create_timer(0.85).timeout
	var final_children: int = _attack_dummy.get_child_count()
	var t15_pass: bool = (initial_children == final_children)
	_record_result("TEST 15: Repeated attack cycles without node accumulation", t15_pass,
		"Child count unchanged: %s (%d -> %d)" % [t15_pass, initial_children, final_children])

	# -----------------------------------------------------------------
	# TEST 16: Successful block reduces Shield Durability by 15.0
	# -----------------------------------------------------------------
	# Face dummy again
	_player.global_position = Vector3(0, 0, 0)
	_player._camera_yaw = 0.0
	_player.camera_pivot.rotation.y = 0.0
	_player.visuals.rotation.y = 0.0
	_player.reset_shield_durability()
	_player.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var dur_before_t16: float = _player.shield_durability
	_attack_dummy.trigger_attack_now()
	await create_timer(0.85).timeout
	var dur_after_t16: float = _player.shield_durability
	var shield_loss_t16: float = dur_before_t16 - dur_after_t16
	var t16_pass: bool = abs(shield_loss_t16 - 15.0) < 0.01 and abs(dur_after_t16 - 85.0) < 0.01
	_record_result("TEST 16: Block reduces Shield Durability by 15.0", t16_pass,
		"Dur before=%.1f, Dur after=%.1f (Shield damage=%.1f, Expected 15.0)" % [dur_before_t16, dur_after_t16, shield_loss_t16])

	# -----------------------------------------------------------------
	# TEST 17: Non-blocked attacks do not reduce Shield Durability
	# -----------------------------------------------------------------
	_player.global_position = Vector3(0, 0, 0)
	_player.transition_to(PlayerController.CombatState.IDLE)
	_player.reset_shield_durability()
	await process_frame

	var dur_before_t17: float = _player.shield_durability
	_attack_dummy.trigger_attack_now()
	await create_timer(0.85).timeout
	var dur_after_t17: float = _player.shield_durability
	var t17_pass: bool = (dur_after_t17 == dur_before_t17)
	_record_result("TEST 17: Non-blocked attack does not reduce Shield Durability", t17_pass,
		"Dur before=%.1f, Dur after=%.1f (Durability unchanged)" % [dur_before_t17, dur_after_t17])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("\n=================================================================")
	var total: int = _test_results.size()
	var passed: int = 0
	for r in _test_results:
		if r["passed"]:
			passed += 1
	print("TRAINING DUMMY UPGRADE SUMMARY: %d / %d TESTS PASSED" % [passed, total])
	print("=================================================================")

	if passed == total:
		quit(0)
	else:
		quit(1)
