extends SceneTree

# Acceptance Test Suite for Task 5.14C: Combo Finisher Recovery Pause

var _total: int = 0
var _passed: int = 0
var _failed: int = 0


func _record(name: String, condition: bool, details: String = "") -> void:
	_total += 1
	if condition:
		_passed += 1
		print("  [PASS] %s%s" % [name, " - " + details if details != "" else ""])
	else:
		_failed += 1
		print("  [FAIL] %s%s" % [name, " - " + details if details != "" else ""])


func _wait_for_attack_finish(player: PlayerController) -> void:
	var safety: int = 500
	while player.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _wait_for_combo_window(player: PlayerController) -> void:
	var safety: int = 180
	while not player.is_in_combo_window() and player.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1


func _wait_for_finisher_recovery(player: PlayerController) -> void:
	var safety: int = 300
	while player.combo_finisher_recovery_remaining > 0.0 and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _start_combo(player: PlayerController, hits: int) -> void:
	player._try_combat_attack()
	for step in range(1, hits):
		await _wait_for_combo_window(player)
		player._try_combat_attack()
	await _wait_for_attack_finish(player)


func _reset(player: PlayerController, dummy: TrainingDummy) -> void:
	await _wait_for_attack_finish(player)
	player.reset_combo()
	dummy.reset_dummy()
	dummy.is_blocking = false
	await process_frame


func _init() -> void:
	print("\n==================================================")
	print("RUNNING TASK 5.14C: COMBO FINISHER RECOVERY")
	print("==================================================")
	call_deferred("_run_tests")


func _run_tests() -> void:
	var scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = scene.instantiate() as CombatTestArena
	root.add_child(arena)
	for i in range(12):
		await process_frame
	var player: PlayerController = arena.player
	var dummy: TrainingDummy = arena.training_dummy
	var attack_dummy: AttackTrainingDummy = arena.attack_dummy
	attack_dummy.auto_attack = false
	if attack_dummy._cycle_tween and attack_dummy._cycle_tween.is_valid():
		attack_dummy._cycle_tween.kill()
	dummy.global_position = Vector3(3.5, 0, 0)
	player.global_position = Vector3(3.5, 0, 1.8)
	player._camera_yaw = 0.0
	player.camera_pivot.rotation.y = 0.0
	player.visuals.rotation.y = 0.0

	_record("TEST 1: Finisher recovery constant is 0.8 seconds", is_equal_approx(PlayerController.COMBO_FINISHER_RECOVERY, 0.8), "Constant: %.2f" % PlayerController.COMBO_FINISHER_RECOVERY)

	await _reset(player, dummy)
	await _start_combo(player, 3)
	var pause_started: bool = player.combo_finisher_recovery_remaining > 0.0
	var pause_matches_constant: bool = player.combo_finisher_recovery_remaining <= PlayerController.COMBO_FINISHER_RECOVERY and player.combo_finisher_recovery_remaining > PlayerController.COMBO_FINISHER_RECOVERY - 0.12
	var lmb_rejected: bool = not player._try_combat_attack()
	var block_rejected: bool = not player._start_block()
	_record("TEST 2: Third hit starts pause; LMB and block are rejected", pause_started and pause_matches_constant and lmb_rejected and block_rejected, "Remaining: %.3f" % player.combo_finisher_recovery_remaining)
	var pause_before_hit: float = player.combo_finisher_recovery_remaining
	player.apply_hit_reaction(Vector3.FORWARD)
	var survives_hit_reaction: bool = player.combo_finisher_recovery_remaining > 0.0 and player.combo_finisher_recovery_remaining <= pause_before_hit
	player.break_shield()
	var survives_shield_break: bool = player.combo_finisher_recovery_remaining > 0.0
	player.reset_shield_for_new_round()
	_record("TEST 3: Hit reaction and shield break cannot clear pause", survives_hit_reaction and survives_shield_break)
	await _wait_for_finisher_recovery(player)
	var attack_after_pause: bool = player._try_combat_attack()
	_record("TEST 4: Attack works immediately after pause", attack_after_pause, "Timer: %.3f" % player.combo_finisher_recovery_remaining)
	await _wait_for_attack_finish(player)

	await _reset(player, dummy)
	await _start_combo(player, 1)
	_record("TEST 5: One-hit combo has no finisher pause", player.combo_finisher_recovery_remaining <= 0.0)
	await _wait_for_finisher_recovery(player)
	await _reset(player, dummy)
	await _start_combo(player, 2)
	_record("TEST 6: Two-hit combo has no finisher pause", player.combo_finisher_recovery_remaining <= 0.0)

	await _reset(player, dummy)
	await _start_combo(player, 3)
	var damage_after_spam: float = 100.0 - dummy.health_component.current_health
	var chained_during_pause: bool = player._try_combat_attack()
	await _wait_for_finisher_recovery(player)
	var fresh_combo_after_pause: bool = player._try_combat_attack()
	_record("TEST 7: Spam caps at three; fresh combo waits for pause", damage_after_spam == 75.0 and not chained_during_pause and fresh_combo_after_pause, "Damage: %.1f" % damage_after_spam)
	await _wait_for_attack_finish(player)

	await _reset(player, dummy)
	await _start_combo(player, 3)
	player.transition_to(PlayerController.CombatState.DEAD)
	var cleared_on_death: bool = player.combo_finisher_recovery_remaining <= 0.0
	player.respawn(Vector3(3.5, 0, 1.8), 0.0)
	await process_frame
	var cleared_on_respawn: bool = player.combo_finisher_recovery_remaining <= 0.0
	_record("TEST 8: Death and respawn clear finisher pause", cleared_on_death and cleared_on_respawn)

	await _reset(player, dummy)
	player.set_third_person(false)
	await _start_combo(player, 3)
	var fps_pause: bool = player.combo_finisher_recovery_remaining > 0.0 and not player._try_combat_attack()
	await _wait_for_finisher_recovery(player)
	player.set_third_person(true)
	_record("TEST 9: FPS and TPS preserve finisher recovery", fps_pause and player.is_third_person)

	arena.queue_free()
	print("\n==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed, _total, _failed])
	print("==================================================")
	quit(0 if _failed == 0 else 1)
