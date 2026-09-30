extends SceneTree

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0
var _results: Array[Dictionary] = []

var _arena: Node3D
var _player: PlayerController
var _attack_dummy: AttackTrainingDummy
var _training_dummy: TrainingDummy
var _hud: CanvasLayer


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


func _setup_scene() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	_arena = arena_scene.instantiate() as Node3D
	root.add_child(_arena)
	
	_player = _arena.get_node("Player") as PlayerController
	_attack_dummy = _arena.get_node("AttackTrainingDummy") as AttackTrainingDummy
	_training_dummy = _arena.get_node("TrainingDummy") as TrainingDummy
	_hud = _arena.get_node_or_null("CombatTestHUD") as CanvasLayer


func _run_tests() -> void:
	print("==================================================")
	print("RUNNING TASK 5.6 ACCEPTANCE TESTS: COMBAT TEST ARENA")
	print("==================================================")

	_setup_scene()
	for i in range(10):
		await process_frame

	var p: PlayerController = _player
	var ad: AttackTrainingDummy = _attack_dummy
	var td: TrainingDummy = _training_dummy
	var hud: CanvasLayer = _hud

	# Array for by-reference capture in lambda closures
	var break_vfx_record: Array[bool] = [false]
	p.shield_broken.connect(func() -> void:
		if p.combat and p.combat.shield_break_vfx:
			break_vfx_record[0] = p.combat.shield_break_vfx.visible
	)

	# -----------------------------------------------------------------
	# TEST 1: CombatTestArena loads correctly
	# -----------------------------------------------------------------
	var t1_pass: bool = (_arena != null) and is_instance_valid(_arena)
	_record_result("TEST 1: CombatTestArena loads correctly", t1_pass, "Arena valid: %s" % t1_pass)

	# -----------------------------------------------------------------
	# TEST 2: Player spawns at expected position
	# -----------------------------------------------------------------
	var expected_spawn: Vector3 = Vector3(0, 0.1, 0)
	var spawn_dist: float = p.global_position.distance_to(expected_spawn)
	var t2_pass: bool = (spawn_dist < 0.25)
	_record_result("TEST 2: Player spawns at expected position", t2_pass,
		"Player pos=%s (expected %s, dist=%.3fm)" % [p.global_position, expected_spawn, spawn_dist])

	# -----------------------------------------------------------------
	# TEST 3: AttackTrainingDummy exists
	# -----------------------------------------------------------------
	var t3_pass: bool = (ad != null) and is_instance_valid(ad)
	_record_result("TEST 3: AttackTrainingDummy exists", t3_pass, "AttackDummy valid: %s" % t3_pass)

	# -----------------------------------------------------------------
	# TEST 4: TrainingDummy exists
	# -----------------------------------------------------------------
	var t4_pass: bool = (td != null) and is_instance_valid(td)
	_record_result("TEST 4: TrainingDummy exists", t4_pass, "TrainingDummy valid: %s" % t4_pass)

	# -----------------------------------------------------------------
	# TEST 5: AttackTrainingDummy remains stationary
	# -----------------------------------------------------------------
	var initial_ad_pos: Vector3 = ad.global_position
	for f in range(20):
		ad._physics_process(0.016)
		await process_frame
	var ad_drift: float = ad.global_position.distance_to(initial_ad_pos)
	var t5_pass: bool = (ad_drift < 0.001)
	_record_result("TEST 5: AttackTrainingDummy remains stationary", t5_pass,
		"Initial pos=%s, Current pos=%s, Drift=%.4fm" % [initial_ad_pos, ad.global_position, ad_drift])

	# -----------------------------------------------------------------
	# TEST 6: Automatic attack works
	# -----------------------------------------------------------------
	ad.auto_attack = true
	var auto_started: bool = false
	for f in range(180): # up to 3 seconds
		await process_frame
		if ad.is_attacking():
			auto_started = true
			break
	_record_result("TEST 6: Automatic attack works", auto_started, "Auto attack started: %s" % auto_started)

	# -----------------------------------------------------------------
	# TEST 7: One dummy swing applies damage exactly once
	# -----------------------------------------------------------------
	# Wait for any in-flight attack to complete
	while ad.is_attacking():
		await process_frame

	ad.auto_attack = false # Temporarily disable auto attack to test single manual swing
	p.health_component.reset_health()
	p.reset_shield_durability()
	p.transition_to(PlayerController.CombatState.IDLE)
	p.global_position = Vector3(0, 0.1, 0)
	await process_frame

	var hits_record: Array[int] = [0]
	var hit_callable: Callable = func(_amount: float) -> void:
		hits_record[0] += 1
	p.health_component.damaged.connect(hit_callable)

	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	p.health_component.damaged.disconnect(hit_callable)

	var t7_pass: bool = (hits_record[0] == 1)
	_record_result("TEST 7: One dummy swing applies damage exactly once", t7_pass,
		"Hits recorded during single swing: %d (expected 1)" % hits_record[0])

	# -----------------------------------------------------------------
	# TEST 8: Verify actual damage amount
	# -----------------------------------------------------------------
	var unblocked_damage: float = 100.0 - p.health_component.current_health
	var t8_pass: bool = abs(unblocked_damage - 25.0) < 0.05
	_record_result("TEST 8: Verify actual damage amount (25.0 unblocked)", t8_pass,
		"Damage dealt=%.2f (expected 25.0)" % unblocked_damage)

	# -----------------------------------------------------------------
	# TEST 9: Player can block dummy attack
	# -----------------------------------------------------------------
	p.health_component.reset_health()
	p.reset_shield_durability()
	# Face dummy at (0, 0, -1.8) -> player at (0, 0, 0) faces -Z (yaw = 0)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var hp_before_block: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame

	var blocked_hp_loss: float = hp_before_block - p.health_component.current_health
	var t9_pass: bool = abs(blocked_hp_loss - 3.75) < 0.05
	_record_result("TEST 9: Player can block dummy attack", t9_pass,
		"HP loss while blocking=%.2f (expected 3.75, 85%% reduced)" % blocked_hp_loss)

	# -----------------------------------------------------------------
	# TEST 10: Shield decreases by 15 per successful block
	# -----------------------------------------------------------------
	var t10_pass: bool = abs(p.shield_durability - 85.0) < 0.01
	_record_result("TEST 10: Shield decreases by 15 per successful block", t10_pass,
		"Durability after 1 block=%.1f (expected 85.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 11: Shield reaches 0 after expected number of blocks (6 more blocks)
	# -----------------------------------------------------------------
	for b in range(5):
		ad.trigger_attack_now()
		while ad.is_attacking():
			await process_frame

	var dur_at_10: float = p.shield_durability # Should be 10.0
	# 7th block: 10 -> 0
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame

	var t11_pass: bool = (dur_at_10 == 10.0) and (p.shield_durability == 0.0)
	_record_result("TEST 11: Shield reaches 0 after expected number of blocks", t11_pass,
		"Dur before 7th=%.1f, Dur after 7th=%.1f" % [dur_at_10, p.shield_durability])

	# -----------------------------------------------------------------
	# TEST 12: Shield Break event triggers exactly once
	# -----------------------------------------------------------------
	var t12_pass: bool = p.is_shield_broken and (p._shield_break_count == 1)
	_record_result("TEST 12: Shield Break event triggers exactly once", t12_pass,
		"is_broken=%s, break_count=%d (expected 1)" % [p.is_shield_broken, p._shield_break_count])

	# -----------------------------------------------------------------
	# TEST 13: ShieldBreakVFX triggers
	# -----------------------------------------------------------------
	var t13_pass: bool = break_vfx_record[0]
	_record_result("TEST 13: ShieldBreakVFX triggers", t13_pass,
		"Break VFX was visible on break event: %s" % break_vfx_record[0])

	# -----------------------------------------------------------------
	# TEST 14: Shield status UI changes to BROKEN
	# -----------------------------------------------------------------
	var status_text: String = ""
	if hud and hud.has_node("RootControl/StatsPanel/VBoxContainer/StatusContainer/StatusLabel"):
		status_text = (hud.get_node("RootControl/StatsPanel/VBoxContainer/StatusContainer/StatusLabel") as Label).text
	var t14_pass: bool = status_text.begins_with("BROKEN")
	_record_result("TEST 14: Shield status UI changes to BROKEN", t14_pass,
		"HUD status text='%s'" % status_text)

	# -----------------------------------------------------------------
	# TEST 15: Player cannot block while shield is broken
	# -----------------------------------------------------------------
	var block_attempt_broken: bool = p._start_block()
	var state_broken: PlayerController.CombatState = p.combat_state
	var t15_pass: bool = (not block_attempt_broken) and (state_broken == PlayerController.CombatState.IDLE)
	_record_result("TEST 15: Player cannot block while shield is broken", t15_pass,
		"_start_block returned=%s, state=%s" % [block_attempt_broken, state_broken])

	# -----------------------------------------------------------------
	# TEST 16: Shield restores to 100 after 2 seconds
	# -----------------------------------------------------------------
	var sim_time: float = 0.0
	while p.is_shield_broken and sim_time < 3.0:
		p._physics_process(0.05)
		sim_time += 0.05
		await process_frame

	var t16_pass: bool = (p.shield_durability == 100.0) and (not p.is_shield_broken)
	_record_result("TEST 16: Shield restores to 100 after 2 seconds", t16_pass,
		"Restored dur=%.1f, is_broken=%s, elapsed=%.2fs" % [p.shield_durability, p.is_shield_broken, sim_time])

	# -----------------------------------------------------------------
	# TEST 17: Player can block again after recovery
	# -----------------------------------------------------------------
	var can_block_after: bool = p._start_block()
	var state_after_rec: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	p._release_block()
	await process_frame
	var t17_pass: bool = can_block_after and state_after_rec
	_record_result("TEST 17: Player can block again after recovery", t17_pass,
		"_start_block returned=%s, state_in_block=%s" % [can_block_after, state_after_rec])

	# -----------------------------------------------------------------
	# TEST 18: If Player dies, Player respawns after approximately 1.5 seconds
	# -----------------------------------------------------------------
	p.health_component.take_damage(200.0)
	await process_frame
	var player_died_cleanly: bool = (p.combat_state == PlayerController.CombatState.DEAD)

	# Wait 1.8s (covering the 1.5s respawn delay) for respawn to trigger
	await create_timer(1.8).timeout
	await process_frame

	var player_respawned_cleanly: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	var t18_pass: bool = player_died_cleanly and player_respawned_cleanly
	_record_result("TEST 18: If Player dies, Player respawns after ~1.5s", t18_pass,
		"Died cleanly=%s, Respawned to IDLE=%s" % [player_died_cleanly, player_respawned_cleanly])

	# -----------------------------------------------------------------
	# TEST 19: Respawn restores HP
	# -----------------------------------------------------------------
	var t19_pass: bool = (p.health_component.current_health == 100.0)
	_record_result("TEST 19: Respawn restores HP to 100", t19_pass,
		"Player HP after respawn=%.1f (expected 100.0)" % p.health_component.current_health)

	# -----------------------------------------------------------------
	# TEST 20: Respawn restores shield to 100
	# -----------------------------------------------------------------
	var t20_pass: bool = (p.shield_durability == 100.0)
	_record_result("TEST 20: Respawn restores shield to 100", t20_pass,
		"Shield dur after respawn=%.1f (expected 100.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 21: Respawn restores READY state
	# -----------------------------------------------------------------
	var t21_pass: bool = (p.shield_state == PlayerController.ShieldState.READY) and (not p.is_shield_broken) and (not p.is_shield_stunned)
	_record_result("TEST 21: Respawn restores READY state", t21_pass,
		"shield_state=%s, is_broken=%s, is_stunned=%s" % [p.shield_state, p.is_shield_broken, p.is_shield_stunned])

	# -----------------------------------------------------------------
	# TEST 22: Respawn returns Player to original spawn position
	# -----------------------------------------------------------------
	var dist_to_spawn: float = p.global_position.distance_to(expected_spawn)
	var t22_pass: bool = (dist_to_spawn < 0.25)
	_record_result("TEST 22: Respawn returns Player to original spawn position", t22_pass,
		"Current pos=%s, dist to spawn=%.3fm" % [p.global_position, dist_to_spawn])

	# -----------------------------------------------------------------
	# TEST 23: No duplicate Player nodes after repeated deaths
	# -----------------------------------------------------------------
	for rep in range(2):
		p.health_component.take_damage(200.0)
		await process_frame
		_arena.call("respawn_player")
		await process_frame

	var player_nodes: Array[Node] = []
	for child in _arena.get_children():
		if child is PlayerController:
			player_nodes.append(child)

	var t23_pass: bool = (player_nodes.size() == 1) and (player_nodes[0] == p)
	_record_result("TEST 23: No duplicate Player nodes after repeated deaths", t23_pass,
		"Player node count=%d, Reused exact instance=%s" % [player_nodes.size(), player_nodes[0] == p if player_nodes.size() > 0 else false])

	# -----------------------------------------------------------------
	# TEST 24: AttackTrainingDummy continues working after Player respawn
	# -----------------------------------------------------------------
	p.health_component.reset_health()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame

	var hp_after_respawn_hit: float = p.health_component.current_health
	var t24_pass: bool = abs(hp_after_respawn_hit - 75.0) < 0.05
	_record_result("TEST 24: AttackTrainingDummy continues working after Player respawn", t24_pass,
		"Player HP after dummy hit=%.1f (expected 75.0)" % hp_after_respawn_hit)

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	quit(_failed_tests)
