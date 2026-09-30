extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null


func _init() -> void:
	print("====================================================")
	print("RUNTIME TEST SUITE: VISUAL SLASH CUE POSITIONING")
	print("====================================================")
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
	var slash: Node3D = combat.slash_effect
	
	# -------------------------------------------------------------
	# TEST 1: Player at origin, facing +X (angle = -90 deg from -Z)
	# -------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.visuals.rotation.y = deg_to_rad(-90.0) # Visuals facing +X
	p.set_third_person(true)
	await process_frame
	
	combat._perform_attack()
	await process_frame
	
	var cue_pos_t1: Vector3 = slash.global_position
	var expected_t1: Vector3 = Vector3(1.1, 0.9, 0.0)
	var dist_t1: float = cue_pos_t1.distance_to(expected_t1)
	var t1_pass: bool = dist_t1 < 0.15 and slash.visible
	_record_result("TEST 1: Player at origin facing +X", t1_pass, 
		"VisualSlashCue pos=%s (Expected ~%s, dist=%.3fm, visible=%s)" % [cue_pos_t1, expected_t1, dist_t1, slash.visible])

	# -------------------------------------------------------------
	# TEST 2: Rotate Player 90 degrees to face -Z (North)
	# -------------------------------------------------------------
	p.visuals.rotation.y = 0.0 # Visuals facing -Z
	await process_frame
	
	combat._perform_attack()
	await process_frame
	
	var cue_pos_t2: Vector3 = slash.global_position
	var expected_t2: Vector3 = Vector3(0.0, 0.9, -1.1)
	var dist_t2: float = cue_pos_t2.distance_to(expected_t2)
	var t2_pass: bool = dist_t2 < 0.15 and slash.visible
	_record_result("TEST 2: Rotate Player to face -Z", t2_pass, 
		"VisualSlashCue pos=%s (Expected ~%s, dist=%.3fm)" % [cue_pos_t2, expected_t2, dist_t2])

	# -------------------------------------------------------------
	# TEST 3: Rotate Player 180 degrees to face +Z (South)
	# -------------------------------------------------------------
	p.visuals.rotation.y = deg_to_rad(180.0) # Visuals facing +Z
	await process_frame
	
	combat._perform_attack()
	await process_frame
	
	var cue_pos_t3: Vector3 = slash.global_position
	var expected_t3: Vector3 = Vector3(0.0, 0.9, 1.1)
	var dist_t3: float = cue_pos_t3.distance_to(expected_t3)
	var t3_pass: bool = dist_t3 < 0.15 and slash.visible
	_record_result("TEST 3: Rotate Player 180 deg to face +Z", t3_pass, 
		"VisualSlashCue pos=%s (Expected ~%s, dist=%.3fm)" % [cue_pos_t3, expected_t3, dist_t3])

	# -------------------------------------------------------------
	# TEST 4: Move Player to another location (5, 0, -8) facing -X
	# -------------------------------------------------------------
	p.global_position = Vector3(5.0, 0.0, -8.0)
	p.visuals.rotation.y = deg_to_rad(90.0) # Visuals facing -X
	await process_frame
	
	combat._perform_attack()
	await process_frame
	
	var cue_pos_t4: Vector3 = slash.global_position
	var expected_t4: Vector3 = Vector3(5.0 - 1.1, 0.9, -8.0)
	var dist_t4: float = cue_pos_t4.distance_to(expected_t4)
	var t4_pass: bool = dist_t4 < 0.15 and slash.visible
	_record_result("TEST 4: Move Player to (5, 0, -8) facing -X", t4_pass, 
		"VisualSlashCue pos=%s (Expected ~%s, dist=%.3fm, followed player position)" % [cue_pos_t4, expected_t4, dist_t4])

	# -------------------------------------------------------------
	# TEST 5: FPS Mode - Camera yaw looking +X
	# -------------------------------------------------------------
	p.set_third_person(false)
	p.global_position = Vector3(-3.0, 0.0, 4.0)
	p.camera_pivot.rotation.y = deg_to_rad(-90.0) # Looking +X
	p._camera_yaw = deg_to_rad(-90.0)
	await process_frame
	
	combat._perform_attack()
	await process_frame
	
	var cue_pos_t5: Vector3 = slash.global_position
	var expected_t5: Vector3 = Vector3(-3.0 + 1.1, 0.9, 4.0)
	var dist_t5: float = cue_pos_t5.distance_to(expected_t5)
	var t5_pass: bool = dist_t5 < 0.15 and slash.visible
	_record_result("TEST 5: FPS camera looking +X", t5_pass, 
		"VisualSlashCue pos=%s (Expected ~%s, dist=%.3fm, follows FPS camera)" % [cue_pos_t5, expected_t5, dist_t5])

	# -------------------------------------------------------------
	# TEST 6: TPS Mode - Character rotated at 45 degrees
	# -------------------------------------------------------------
	p.set_third_person(true)
	p.global_position = Vector3(2.0, 0.0, 2.0)
	var angle_45: float = deg_to_rad(45.0)
	p.visuals.rotation.y = angle_45
	await process_frame
	
	var dir_45: Vector3 = -p.visuals.global_basis.z.normalized()
	dir_45.y = 0.0
	dir_45 = dir_45.normalized()
	
	combat._perform_attack()
	await process_frame
	
	var cue_pos_t6: Vector3 = slash.global_position
	var expected_t6: Vector3 = p.global_position + dir_45 * 1.1
	expected_t6.y = p.global_position.y + 0.9
	var dist_t6: float = cue_pos_t6.distance_to(expected_t6)
	var t6_pass: bool = dist_t6 < 0.15 and slash.visible
	_record_result("TEST 6: TPS character rotated 45 deg", t6_pass, 
		"VisualSlashCue pos=%s (Expected ~%s, dist=%.3fm)" % [cue_pos_t6, expected_t6, dist_t6])

	# -------------------------------------------------------------
	# TEST 7: Repeated attacks from 5 random positions
	# -------------------------------------------------------------
	var repeat_all_pass: bool = true
	var test_positions: Array[Vector3] = [
		Vector3(10.0, 0.0, 0.0),
		Vector3(-10.0, 0.0, 5.0),
		Vector3(0.0, 0.0, 12.0),
		Vector3(-4.0, 0.0, -7.0),
		Vector3(8.0, 0.0, -8.0)
	]
	
	for idx in range(test_positions.size()):
		var test_pos: Vector3 = test_positions[idx]
		p.global_position = test_pos
		var rot: float = deg_to_rad(float(idx) * 72.0)
		p.visuals.rotation.y = rot
		await process_frame
		
		var dir_t7: Vector3 = -p.visuals.global_basis.z.normalized()
		dir_t7.y = 0.0
		dir_t7 = dir_t7.normalized()
		
		combat._perform_attack()
		await process_frame
		
		var expected_pos: Vector3 = test_pos + dir_t7 * 1.1
		expected_pos.y = test_pos.y + 0.9
		var err_dist: float = slash.global_position.distance_to(expected_pos)
		if err_dist > 0.15:
			repeat_all_pass = false
			print("Repeated attack #%d failed: pos=%s, expected=%s, err=%.3fm" % [idx, slash.global_position, expected_pos, err_dist])
			
	_record_result("TEST 7: Repeated attacks across 5 distinct world positions", repeat_all_pass, 
		"All 5 attacks placed VisualSlashCue dynamically at current player position and facing direction")

	# -------------------------------------------------------------
	# FINAL REPORT
	# -------------------------------------------------------------
	print("====================================================")
	var pass_count: int = 0
	for r in _test_results:
		if r.passed:
			pass_count += 1
	print("VISUAL SLASH CUE TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, _test_results.size()])
	print("====================================================")
	
	quit(0 if pass_count == _test_results.size() else 1)
