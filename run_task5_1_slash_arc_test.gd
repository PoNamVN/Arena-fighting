extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null


func _init() -> void:
	print("=================================================================")
	print("RUNTIME TEST SUITE: TASK 5.1 - STYLIZED SWORD SLASH ARC VFX")
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
	return _player


func _run_test_suite() -> void:
	var p: PlayerController = _setup()
	for i in range(10): await process_frame
	
	var combat: PlayerCombat = p.combat
	var vfx: SlashArcVFX = combat.slash_arc_vfx
	
	if not vfx:
		_record_result("SETUP: SlashArcVFX existence", false, "combat.slash_arc_vfx is null!")
		quit(1)
		return
		
	# -----------------------------------------------------------------
	# TEST 1: Attack at origin facing +X
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.visuals.rotation.y = deg_to_rad(-90.0) # facing +X
	p.set_third_person(true)
	await process_frame
	
	combat._perform_attack()
	await process_frame
	
	var pos1: Vector3 = vfx.global_position
	var exp1: Vector3 = Vector3(1.1, 0.9, 0.0)
	var d1: float = pos1.distance_to(exp1)
	var t1_pass: bool = d1 < 0.05 and vfx.visible
	_record_result("TEST 1: Attack at origin facing +X", t1_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm, visible=%s)" % [pos1, exp1, d1, vfx.visible])

	# -----------------------------------------------------------------
	# TEST 2: Attack facing -Z
	# -----------------------------------------------------------------
	p.visuals.rotation.y = 0.0 # facing -Z
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var pos2: Vector3 = vfx.global_position
	var exp2: Vector3 = Vector3(0.0, 0.9, -1.1)
	var d2: float = pos2.distance_to(exp2)
	var t2_pass: bool = d2 < 0.05 and vfx.visible
	_record_result("TEST 2: Attack facing -Z", t2_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm)" % [pos2, exp2, d2])

	# -----------------------------------------------------------------
	# TEST 3: Attack facing +Z
	# -----------------------------------------------------------------
	p.visuals.rotation.y = deg_to_rad(180.0) # facing +Z
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var pos3: Vector3 = vfx.global_position
	var exp3: Vector3 = Vector3(0.0, 0.9, 1.1)
	var d3: float = pos3.distance_to(exp3)
	var t3_pass: bool = d3 < 0.05 and vfx.visible
	_record_result("TEST 3: Attack facing +Z", t3_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm)" % [pos3, exp3, d3])

	# -----------------------------------------------------------------
	# TEST 4: Move Player to another world position and attack
	# -----------------------------------------------------------------
	p.global_position = Vector3(7.5, 0.0, -12.3)
	p.visuals.rotation.y = deg_to_rad(90.0) # facing -X
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var pos4: Vector3 = vfx.global_position
	var exp4: Vector3 = Vector3(7.5 - 1.1, 0.9, -12.3)
	var d4: float = pos4.distance_to(exp4)
	var t4_pass: bool = d4 < 0.05 and vfx.visible
	_record_result("TEST 4: Move Player to (7.5, 0, -12.3) facing -X", t4_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm, moved with player)" % [pos4, exp4, d4])

	# -----------------------------------------------------------------
	# TEST 5: Rotate 45 degrees and attack
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	var angle_45: float = deg_to_rad(-45.0) # 45 deg between -Z and +X
	p.visuals.rotation.y = angle_45
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var fwd_45: Vector3 = -p.visuals.global_basis.z.normalized()
	var exp5: Vector3 = Vector3(0, 0.9, 0) + fwd_45 * 1.1
	var pos5: Vector3 = vfx.global_position
	var d5: float = pos5.distance_to(exp5)
	var t5_pass: bool = d5 < 0.05 and vfx.visible
	_record_result("TEST 5: Rotate 45 degrees and attack", t5_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm)" % [pos5, exp5, d5])

	# -----------------------------------------------------------------
	# TEST 6: FPS camera yaw left/right
	# -----------------------------------------------------------------
	p.set_third_person(false)
	p.global_position = Vector3(-3.0, 0.0, 4.0)
	p._camera_yaw = deg_to_rad(90.0) # looking -X
	p._camera_pitch = 0.0
	p.camera_pivot.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var exp6: Vector3 = Vector3(-3.0 - 1.1, 0.9, 4.0)
	var pos6: Vector3 = vfx.global_position
	var d6: float = pos6.distance_to(exp6)
	var t6_pass: bool = d6 < 0.05 and vfx.visible
	_record_result("TEST 6: FPS camera yaw looking -X", t6_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm)" % [pos6, exp6, d6])

	# -----------------------------------------------------------------
	# TEST 7: FPS camera diagonal direction
	# -----------------------------------------------------------------
	p._camera_yaw = deg_to_rad(-45.0)
	p._camera_pitch = deg_to_rad(-15.0)
	p.camera_pivot.rotation = Vector3(deg_to_rad(-15.0), deg_to_rad(-45.0), 0.0)
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var fps_fwd: Vector3 = -p.camera.global_basis.z
	fps_fwd.y = 0.0
	fps_fwd = fps_fwd.normalized()
	var exp7: Vector3 = p.global_position + fps_fwd * 1.1
	exp7.y = p.global_position.y + 0.9
	var pos7: Vector3 = vfx.global_position
	var d7: float = pos7.distance_to(exp7)
	var t7_pass: bool = d7 < 0.05 and vfx.visible
	_record_result("TEST 7: FPS camera diagonal direction", t7_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm)" % [pos7, exp7, d7])

	# -----------------------------------------------------------------
	# TEST 8: TPS rotation
	# -----------------------------------------------------------------
	p.set_third_person(true)
	p.global_position = Vector3(2.0, 0.0, 2.0)
	p.visuals.rotation.y = deg_to_rad(135.0)
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var tps_fwd: Vector3 = -p.visuals.global_basis.z.normalized()
	tps_fwd.y = 0.0
	tps_fwd = tps_fwd.normalized()
	var exp8: Vector3 = p.global_position + tps_fwd * 1.1
	exp8.y = p.global_position.y + 0.9
	var pos8: Vector3 = vfx.global_position
	var d8: float = pos8.distance_to(exp8)
	var t8_pass: bool = d8 < 0.05 and vfx.visible
	_record_result("TEST 8: TPS character rotation 135 deg", t8_pass,
		"VFX pos=%s (Expected %s, dist=%.3fm)" % [pos8, exp8, d8])

	# -----------------------------------------------------------------
	# TEST 9: Multiple consecutive attacks & disappear check
	# -----------------------------------------------------------------
	# Attack at current spot
	combat._perform_attack()
	await process_frame
	var t9_initial_visible: bool = vfx.visible
	
	# Wait for tween to finish (~0.18s)
	await create_timer(0.20).timeout
	var t9_fade_pass: bool = not vfx.visible
	
	# Move and attack again
	p.global_position = Vector3(-8.0, 0.0, 6.0)
	p.visuals.rotation.y = 0.0
	await process_frame
	combat._perform_attack()
	await process_frame
	
	var pos9_2: Vector3 = vfx.global_position
	var exp9_2: Vector3 = Vector3(-8.0, 0.9, 6.0 - 1.1)
	var d9_2: float = pos9_2.distance_to(exp9_2)
	var t9_pass: bool = t9_initial_visible and t9_fade_pass and (d9_2 < 0.05) and vfx.visible
	_record_result("TEST 9: Multiple consecutive attacks & disappear check", t9_pass,
		"Initial visible=%s, intermediate_fade_hidden=%s, 2nd attack pos=%s (dist=%.3fm, visible=%s)" % [
			t9_initial_visible, t9_fade_pass, pos9_2, d9_2, vfx.visible
		])

	# -----------------------------------------------------------------
	# TEST 10: Rapid attacks without node accumulation or stale VFX
	# -----------------------------------------------------------------
	var initial_child_count: int = combat.get_child_count()
	# Trigger 5 rapid attacks within 0.05s intervals
	for i in range(5):
		combat._perform_attack()
		await process_frame
		
	var post_rapid_child_count: int = combat.get_child_count()
	var no_accumulation: bool = (initial_child_count == post_rapid_child_count)
	
	# Wait for final tween to finish
	await create_timer(0.22).timeout
	var final_hidden: bool = not vfx.visible
	var t10_pass: bool = no_accumulation and final_hidden
	_record_result("TEST 10: Rapid attacks - no node accumulation, clean fade", t10_pass,
		"Child count unchanged: %s (%d -> %d), Final visible=%s" % [
			no_accumulation, initial_child_count, post_rapid_child_count, vfx.visible
		])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("\n=================================================================")
	var total_tests: int = _test_results.size()
	var passed_tests: int = 0
	for r in _test_results:
		if r["passed"]:
			passed_tests += 1
	print("TASK 5.1 TEST SUMMARY: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("=================================================================")
	
	if passed_tests == total_tests:
		quit(0)
	else:
		quit(1)
