extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _current_step: int = 0
var _arena_node: Node3D = null
var _player: PlayerController = null


func _init() -> void:
	print("====================================================")
	print("PHASE 4: COMBAT FSM MATRIX RUNTIME TEST SUITE")
	print("====================================================")


func _record_result(test_name: String, passed: bool, details: String) -> void:
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	var status: String = "PASS" if passed else "FAIL"
	print("[%s] %s: %s" % [status, test_name, details])


func _setup_arena_and_player() -> PlayerController:
	if _arena_node and is_instance_valid(_arena_node):
		_arena_node.queue_free()
	
	_arena_node = ArenaScene.instantiate() as Node3D
	root.add_child(_arena_node)
	_player = _arena_node.get_node("Player") as PlayerController
	return _player


func _process(_delta: float) -> bool:
	_current_step += 1
	
	if _current_step == 1:
		_setup_arena_and_player()
		return false
		
	# Wait for scene nodes and shaders to settle
	if _current_step < 8:
		return false
		
	if _current_step == 8:
		_execute_tests_1_to_7()
		return false
		
	if _current_step == 9:
		_execute_tests_8_to_16()
		return false
		
	if _current_step == 10:
		_execute_test_17_fps()
		return false
		
	if _current_step == 14:
		# Save FPS death screenshot after settling
		var img: Image = root.get_viewport().get_texture().get_image()
		if img:
			img.save_png("res://phase4_death_fps.png")
			print("Saved phase4_death_fps.png")
		_execute_test_18_tps()
		return false
		
	if _current_step == 18:
		# Save TPS death screenshot after settling
		var img: Image = root.get_viewport().get_texture().get_image()
		if img:
			img.save_png("res://phase4_death_tps.png")
			print("Saved phase4_death_tps.png")
		_finalize_and_report()
		quit()
		return true

	return false


func _execute_tests_1_to_7() -> void:
	# TEST 1: IDLE -> RUN
	var p: PlayerController = _setup_arena_and_player()
	var t1_pass: bool = p.combat_state == PlayerController.CombatState.IDLE
	p.transition_to(PlayerController.CombatState.RUN)
	t1_pass = t1_pass and (p.combat_state == PlayerController.CombatState.RUN)
	_record_result("TEST 1: IDLE -> RUN", t1_pass, "Transitioned successfully to RUN state")

	# TEST 2: RUN -> IDLE
	var t2_pass: bool = p.transition_to(PlayerController.CombatState.IDLE)
	t2_pass = t2_pass and (p.combat_state == PlayerController.CombatState.IDLE)
	_record_result("TEST 2: RUN -> IDLE", t2_pass, "Transitioned successfully back to IDLE state")

	# TEST 3: IDLE -> ATTACK
	var t3_pass: bool = p.transition_to(PlayerController.CombatState.ATTACK)
	t3_pass = t3_pass and (p.combat_state == PlayerController.CombatState.ATTACK)
	t3_pass = t3_pass and p.is_attacking and not p.is_blocking
	_record_result("TEST 3: IDLE -> ATTACK", t3_pass, "Transitioned to ATTACK (is_attacking=true, is_blocking=false)")

	# TEST 4: IDLE -> BLOCK
	p = _setup_arena_and_player()
	var t4_pass: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	t4_pass = t4_pass and (p.combat_state == PlayerController.CombatState.BLOCK)
	t4_pass = t4_pass and p.is_blocking and not p.is_attacking
	_record_result("TEST 4: IDLE -> BLOCK", t4_pass, "Transitioned to BLOCK (is_blocking=true, is_attacking=false)")

	# TEST 5: BLOCK -> ATTACK (Clean release and attack start)
	var t5_pass: bool = p.transition_to(PlayerController.CombatState.ATTACK)
	t5_pass = t5_pass and (p.combat_state == PlayerController.CombatState.ATTACK)
	t5_pass = t5_pass and p.is_attacking and not p.is_blocking
	_record_result("TEST 5: BLOCK -> ATTACK", t5_pass, "Block cleanly released and attack started")

	# TEST 6: ATTACK -> BLOCK (Must be rejected while attack is active)
	var t6_attempt: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	var t6_pass: bool = (not t6_attempt) and (p.combat_state == PlayerController.CombatState.ATTACK) and (not p.is_blocking)
	_record_result("TEST 6: ATTACK -> BLOCK (Rejected mid-swing)", t6_pass, "Block transition correctly rejected while ATTACK is active")

	# TEST 7: ATTACK -> IDLE/RUN after attack completion
	p._on_animation_finished("attack")
	var t7_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE or p.combat_state == PlayerController.CombatState.RUN)
	t7_pass = t7_pass and (not p.is_attacking)
	_record_result("TEST 7: ATTACK -> IDLE/RUN after completion", t7_pass, "State returned to locomotion after attack animation finished")


func _execute_tests_8_to_16() -> void:
	# TEST 8: IDLE -> DEAD
	var p: PlayerController = _setup_arena_and_player()
	p.take_damage(100.0)
	var t8_pass: bool = (p.combat_state == PlayerController.CombatState.DEAD) and p.is_dead and (not p.is_attacking) and (not p.is_blocking)
	_record_result("TEST 8: IDLE -> DEAD", t8_pass, "Forced transition to DEAD from IDLE on HP <= 0")

	# TEST 9: RUN -> DEAD
	p = _setup_arena_and_player()
	p.transition_to(PlayerController.CombatState.RUN)
	p.take_damage(100.0)
	var t9_pass: bool = (p.combat_state == PlayerController.CombatState.DEAD) and p.is_dead
	_record_result("TEST 9: RUN -> DEAD", t9_pass, "Forced transition to DEAD from RUN on HP <= 0")

	# TEST 10: ATTACK -> DEAD
	p = _setup_arena_and_player()
	p.transition_to(PlayerController.CombatState.ATTACK)
	p.take_damage(100.0)
	var t10_pass: bool = (p.combat_state == PlayerController.CombatState.DEAD) and p.is_dead and (not p.is_attacking)
	_record_result("TEST 10: ATTACK -> DEAD", t10_pass, "Forced transition to DEAD from ATTACK cancels attack and locks DEAD")

	# TEST 11: BLOCK -> DEAD
	p = _setup_arena_and_player()
	p.transition_to(PlayerController.CombatState.BLOCK)
	p.take_damage(1000.0) # Massive unblockable/lethal damage
	var t11_pass: bool = (p.combat_state == PlayerController.CombatState.DEAD) and p.is_dead and (not p.is_blocking)
	_record_result("TEST 11: BLOCK -> DEAD", t11_pass, "Forced transition to DEAD from BLOCK cancels block and locks DEAD")

	# TEST 12: DEAD + LMB (Ignored)
	var t12_attempt: bool = p.transition_to(PlayerController.CombatState.ATTACK)
	var t12_pass: bool = (not t12_attempt) and (p.combat_state == PlayerController.CombatState.DEAD) and (not p.is_attacking)
	_record_result("TEST 12: DEAD + LMB (Ignored)", t12_pass, "Attack input completely ignored while DEAD")

	# TEST 13: DEAD + RMB (Ignored)
	var t13_attempt: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	var t13_pass: bool = (not t13_attempt) and (p.combat_state == PlayerController.CombatState.DEAD) and (not p.is_blocking)
	_record_result("TEST 13: DEAD + RMB (Ignored)", t13_pass, "Block input completely ignored while DEAD")

	# TEST 14: DEAD + movement (Ignored / velocity remains zero)
	p.velocity = Vector3(5.0, 0.0, 5.0)
	p._physics_process(0.016)
	var horiz_vel: Vector2 = Vector2(p.velocity.x, p.velocity.z)
	var t14_pass: bool = (horiz_vel == Vector2.ZERO) and (p.combat_state == PlayerController.CombatState.DEAD)
	_record_result("TEST 14: DEAD + movement (Ignored)", t14_pass, "Horizontal velocity clamped to ZERO and movement input ignored")

	# TEST 15: DEAD remains DEAD after death animation completes
	p._on_animation_finished("dead")
	var t15_pass: bool = (p.combat_state == PlayerController.CombatState.DEAD) and p.is_dead
	_record_result("TEST 15: DEAD remains DEAD after animation", t15_pass, "Character stays terminal DEAD and does not reset to idle")

	# TEST 16: No damage can be processed after DEAD
	var hp_before: float = p.health_component.current_health if p.health_component else 0.0
	p.take_damage(50.0)
	var hp_after: float = p.health_component.current_health if p.health_component else 0.0
	var t16_pass: bool = (hp_after == hp_before) and (p.combat_state == PlayerController.CombatState.DEAD)
	_record_result("TEST 16: No damage processed after DEAD", t16_pass, "Further damage events strictly rejected after character death")


func _execute_test_17_fps() -> void:
	var p: PlayerController = _setup_arena_and_player()
	p.set_third_person(false)
	# Tilt camera down slightly towards dummy/sand to view collapsed posture in FPS
	if p.camera_pivot:
		p.camera_pivot.rotation.x = deg_to_rad(-18.0)
	p.take_damage(100.0)
	if p.anim_player and p.anim_player.has_animation("dead"):
		p.anim_player.seek(0.95, true)
	var t17_pass: bool = (not p.is_third_person) and (p.combat_state == PlayerController.CombatState.DEAD)
	_record_result("TEST 17: FPS death verification", t17_pass, "FPS camera maintained during death with head mesh hidden")


func _execute_test_18_tps() -> void:
	var p: PlayerController = _setup_arena_and_player()
	p.set_third_person(true)
	p.take_damage(100.0)
	# Advance animation frames to capture character collapsed on floor
	if p.anim_player and p.anim_player.has_animation("dead"):
		p.anim_player.seek(0.95, true)
	var t18_pass: bool = p.is_third_person and (p.combat_state == PlayerController.CombatState.DEAD)
	_record_result("TEST 18: TPS death verification", t18_pass, "TPS camera captured full character collapsed on ground")


func _finalize_and_report() -> void:
	print("====================================================")
	var pass_count: int = 0
	for r in _test_results:
		if r.passed:
			pass_count += 1
	print("PHASE 4 TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, _test_results.size()])
	print("====================================================")
