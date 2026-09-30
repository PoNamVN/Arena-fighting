extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _dummy: TrainingDummy = null
var _dummy_health: HealthComponent = null


func _init() -> void:
	print("=================================================================")
	print("RUNTIME TEST SUITE: TASK 5.3 - BLOCK IMPACT VFX")
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


func _reset_dummy_health() -> void:
	if _dummy_health:
		_dummy_health.current_health = _dummy_health.max_health
		_dummy_health.set("_is_dead", false)
	if _dummy and _dummy.has_method("reset_shield_durability"):
		_dummy.reset_shield_durability()


func _run_test_suite() -> void:
	var p: PlayerController = _setup()
	for i in range(10): await process_frame
	
	var combat: PlayerCombat = p.combat
	var block_vfx: Node3D = combat.block_impact_vfx
	var hit_vfx: Node3D = combat.hit_impact_vfx
	
	if not block_vfx:
		_record_result("SETUP: BlockImpactVFX existence", false, "combat.block_impact_vfx is null!")
		quit(1)
		return
		
	# -----------------------------------------------------------------
	# TEST 1 & 2 & 3: Frontal block produces Block Impact VFX at shield/contact position with reduced damage
	# -----------------------------------------------------------------
	p.set_third_person(true)
	_dummy.global_position = Vector3(0, 0, 0)
	_dummy.rotation = Vector3.ZERO # Dummy faces North (-Z)
	_dummy.is_blocking = true
	_dummy.block_damage_reduction = 0.85
	_reset_dummy_health()
	
	# Player directly in front of dummy (North of dummy, at Z = -1.8, facing South +Z)
	p.global_position = Vector3(0, 0, -1.8)
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	p.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var hp_before_t1: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var t1_block_shown: bool = false
	var t1_block_pos: Vector3 = Vector3.ZERO
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			t1_block_shown = true
			t1_block_pos = block_vfx.global_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var hp_after_t1: float = _dummy_health.current_health
	var damage_t1: float = hp_before_t1 - hp_after_t1
	
	# Test 1 check: Block Impact VFX produced
	var t1_pass: bool = t1_block_shown
	_record_result("TEST 1: Frontal block produces Block Impact VFX", t1_pass,
		"VFX triggered=%s" % [t1_block_shown])
		
	# Test 2 check: Block Impact appears at shield/contact position
	# Dummy chest is at (0, 0.9, 0). Attack from North (0, 0, -1.8) towards +Z. Contact point is ~(0, 0.9, -0.35)
	var expected_block_pos: Vector3 = Vector3(0, 0.9, -0.35)
	var dist_to_contact: float = t1_block_pos.distance_to(expected_block_pos)
	var t2_pass: bool = dist_to_contact < 0.20
	_record_result("TEST 2: Block Impact appears at shield/contact position", t2_pass,
		"Block pos=%s (Expected ~%s, dist=%.3fm)" % [t1_block_pos, expected_block_pos, dist_to_contact])
		
	# Test 3 check: Blocked attack applies reduced damage (3.75)
	var t3_pass: bool = abs(damage_t1 - 3.75) < 0.05
	_record_result("TEST 3: Blocked attack applies reduced damage", t3_pass,
		"Damage dealt=%.2f (Expected 3.75, 85%% reduced)" % damage_t1)

	# -----------------------------------------------------------------
	# TEST 4: Rear attack produces full damage and NO Block Impact VFX
	# -----------------------------------------------------------------
	_reset_dummy_health()
	_dummy.global_position = Vector3(0, 0, 0)
	_dummy.rotation = Vector3.ZERO # Faces North (-Z)
	_dummy.is_blocking = true
	
	# Player behind dummy (South, at Z = 1.8, facing North -Z)
	p.global_position = Vector3(0, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	
	var hp_before_t4: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var t4_block_shown: bool = false
	var t4_hit_shown: bool = false
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			t4_block_shown = true
		if hit_vfx.visible:
			t4_hit_shown = true
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var damage_t4: float = hp_before_t4 - _dummy_health.current_health
	var t4_pass: bool = (not t4_block_shown) and t4_hit_shown and (abs(damage_t4 - 25.0) < 0.05)
	_record_result("TEST 4: Rear attack produces full damage & NO Block VFX", t4_pass,
		"Block VFX shown=%s (Expected false), Hit VFX shown=%s, Damage=%.1f (Expected 25.0)" % [t4_block_shown, t4_hit_shown, damage_t4])

	# -----------------------------------------------------------------
	# TEST 5: Flank / outside-cone attack produces full damage and NO Block Impact VFX
	# -----------------------------------------------------------------
	_reset_dummy_health()
	_dummy.global_position = Vector3(0, 0, 0)
	_dummy.rotation = Vector3.ZERO # Faces North (-Z)
	_dummy.is_blocking = true
	
	# Position at 75° angle (outside 120° block cone whose half-angle is 60°)
	var angle_75_rad: float = deg_to_rad(75.0)
	var flank_pos: Vector3 = Vector3(1.8 * sin(angle_75_rad), 0, -1.8 * cos(angle_75_rad))
	p.global_position = flank_pos
	var to_dummy: Vector3 = (_dummy.global_position - flank_pos).normalized()
	var flank_yaw: float = atan2(-to_dummy.x, -to_dummy.z)
	p._camera_yaw = flank_yaw
	p.camera_pivot.rotation.y = flank_yaw
	p.visuals.rotation.y = flank_yaw
	await process_frame
	
	var hp_before_t5: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var t5_block_shown: bool = false
	var t5_hit_shown: bool = false
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			t5_block_shown = true
		if hit_vfx.visible:
			t5_hit_shown = true
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var damage_t5: float = hp_before_t5 - _dummy_health.current_health
	var t5_pass: bool = (not t5_block_shown) and t5_hit_shown and (abs(damage_t5 - 25.0) < 0.05)
	_record_result("TEST 5: Flank attack produces full damage & NO Block VFX", t5_pass,
		"Block VFX shown=%s (Expected false), Hit VFX shown=%s, Damage=%.1f (Expected 25.0)" % [t5_block_shown, t5_hit_shown, damage_t5])

	# -----------------------------------------------------------------
	# TEST 6: No-block attack produces normal Hit Impact VFX and NO Block Impact VFX
	# -----------------------------------------------------------------
	_reset_dummy_health()
	_dummy.global_position = Vector3(0, 0, 0)
	_dummy.rotation = Vector3.ZERO
	_dummy.is_blocking = false
	
	p.global_position = Vector3(0, 0, -1.8)
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	p.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var hp_before_t6: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var t6_block_shown: bool = false
	var t6_hit_shown: bool = false
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			t6_block_shown = true
		if hit_vfx.visible:
			t6_hit_shown = true
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var damage_t6: float = hp_before_t6 - _dummy_health.current_health
	var t6_pass: bool = (not t6_block_shown) and t6_hit_shown and (abs(damage_t6 - 25.0) < 0.05)
	_record_result("TEST 6: No-block attack produces normal Hit VFX & NO Block VFX", t6_pass,
		"Block VFX shown=%s (Expected false), Hit VFX shown=%s (Expected true), Damage=%.1f" % [t6_block_shown, t6_hit_shown, damage_t6])

	# -----------------------------------------------------------------
	# TEST 7: Repeated blocks work correctly & fade cleanly
	# -----------------------------------------------------------------
	_reset_dummy_health()
	_dummy.is_blocking = true
	
	# Blocked attack 1
	p._try_combat_attack()
	var att1_block_shown: bool = false
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			att1_block_shown = true
			break
			
	await create_timer(0.20).timeout
	var att1_block_faded: bool = not block_vfx.visible
	
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	# Blocked attack 2
	p._try_combat_attack()
	var att2_block_shown: bool = false
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			att2_block_shown = true
			break
			
	await create_timer(0.20).timeout
	var att2_block_faded: bool = not block_vfx.visible
	
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var t7_pass: bool = att1_block_shown and att1_block_faded and att2_block_shown and att2_block_faded
	_record_result("TEST 7: Repeated blocks work correctly & fade cleanly", t7_pass,
		"Att1 shown=%s faded=%s, Att2 shown=%s faded=%s" % [att1_block_shown, att1_block_faded, att2_block_shown, att2_block_faded])

	# -----------------------------------------------------------------
	# TEST 8: No persistent node accumulation
	# -----------------------------------------------------------------
	var initial_combat_children: int = combat.get_child_count()
	
	for i in range(3):
		p._try_combat_attack()
		for f in range(30):
			await process_frame
		while p._is_attacking or combat._cooldown_timer > 0.0:
			await process_frame
			
	var final_combat_children: int = combat.get_child_count()
	var t8_pass: bool = (initial_combat_children == final_combat_children)
	_record_result("TEST 8: No persistent node accumulation", t8_pass,
		"Child count unchanged: %s (%d -> %d)" % [t8_pass, initial_combat_children, final_combat_children])

	# -----------------------------------------------------------------
	# TEST 9: FPS block works
	# -----------------------------------------------------------------
	_reset_dummy_health()
	_dummy.is_blocking = true
	p.set_third_person(false) # Switch to FPS
	await process_frame
	
	p.global_position = Vector3(0, 0, -1.8)
	p._camera_yaw = deg_to_rad(180.0)
	p.camera_pivot.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var hp_before_t9: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var fps_block_shown: bool = false
	var fps_block_pos: Vector3 = Vector3.ZERO
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			fps_block_shown = true
			fps_block_pos = block_vfx.global_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var damage_t9: float = hp_before_t9 - _dummy_health.current_health
	var fps_dist: float = fps_block_pos.distance_to(expected_block_pos)
	var t9_pass: bool = fps_block_shown and (abs(damage_t9 - 3.75) < 0.05) and (fps_dist < 0.20)
	_record_result("TEST 9: FPS block works", t9_pass,
		"FPS block shown=%s, pos=%s (dist=%.3fm), Damage=%.2f" % [fps_block_shown, fps_block_pos, fps_dist, damage_t9])

	# -----------------------------------------------------------------
	# TEST 10: TPS block works
	# -----------------------------------------------------------------
	_reset_dummy_health()
	_dummy.is_blocking = true
	p.set_third_person(true) # Switch back to TPS
	await process_frame
	
	# Rotate dummy to face East (+X) at (0, 0, 0)
	_dummy.rotation.y = deg_to_rad(-90.0) # Faces East (+X)
	p.global_position = Vector3(1.8, 0, 0) # East of dummy, facing West (-X)
	p._camera_yaw = deg_to_rad(90.0)
	p.camera_pivot.rotation.y = deg_to_rad(90.0)
	p.visuals.rotation.y = deg_to_rad(90.0)
	await process_frame
	
	var hp_before_t10: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var tps_block_shown: bool = false
	var tps_block_pos: Vector3 = Vector3.ZERO
	for f in range(60):
		await process_frame
		if block_vfx.visible:
			tps_block_shown = true
			tps_block_pos = block_vfx.global_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var damage_t10: float = hp_before_t10 - _dummy_health.current_health
	# Contact point is at (0.35, 0.9, 0)
	var expected_tps_block: Vector3 = Vector3(0.35, 0.9, 0)
	var tps_dist: float = tps_block_pos.distance_to(expected_tps_block)
	var t10_pass: bool = tps_block_shown and (abs(damage_t10 - 3.75) < 0.05) and (tps_dist < 0.20)
	_record_result("TEST 10: TPS block works", t10_pass,
		"TPS block shown=%s, pos=%s (dist=%.3fm), Damage=%.2f" % [tps_block_shown, tps_block_pos, tps_dist, damage_t10])

	# -----------------------------------------------------------------
	# EVALUATION SUMMARY
	# -----------------------------------------------------------------
	print("\n=================================================================")
	var total: int = _test_results.size()
	var passed: int = 0
	for r in _test_results:
		if r["passed"]:
			passed += 1
	print("TASK 5.3 TEST SUMMARY: %d / %d TESTS PASSED" % [passed, total])
	print("=================================================================")
	
	if passed == total:
		quit(0)
	else:
		quit(1)
