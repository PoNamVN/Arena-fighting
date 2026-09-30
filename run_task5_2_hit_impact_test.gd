extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _dummy: TrainingDummy = null
var _dummy_health: HealthComponent = null


func _init() -> void:
	print("=================================================================")
	print("RUNTIME TEST SUITE: TASK 5.2 - HIT IMPACT VFX")
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


func _run_test_suite() -> void:
	var p: PlayerController = _setup()
	for i in range(10): await process_frame
	
	var combat: PlayerCombat = p.combat
	var hit_vfx: Node3D = combat.hit_impact_vfx
	var slash_vfx: Node3D = combat.slash_arc_vfx
	
	if not hit_vfx:
		_record_result("SETUP: HitImpactVFX existence", false, "combat.hit_impact_vfx is null!")
		quit(1)
		return
		
	# -----------------------------------------------------------------
	# TEST 1 & 2: Successful hit produces Hit Impact VFX at target impact position
	# -----------------------------------------------------------------
	# Place player in front of dummy (1.8m away)
	p.set_third_person(true)
	_dummy.global_position = Vector3(0, 0, 0)
	_dummy.is_blocking = false
	p.global_position = Vector3(0, 0, 1.8)
	p._camera_yaw = 0.0 # Facing North (-Z) towards dummy
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	
	var hp_before_t1: float = _dummy_health.current_health
	p._try_combat_attack()
	
	# Wait until impact frame (~0.35s / frame 22-25)
	var t1_shown: bool = false
	var t1_impact_pos: Vector3 = Vector3.ZERO
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			t1_shown = true
			t1_impact_pos = hit_vfx.global_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var hp_after_t1: float = _dummy_health.current_health
	var damage_t1: float = hp_before_t1 - hp_after_t1
	
	# Check Test 1 (VFX produced on hit)
	var t1_pass: bool = t1_shown and (damage_t1 > 0.0)
	_record_result("TEST 1: Successful hit produces Hit Impact VFX", t1_pass,
		"VFX triggered=%s, Damage dealt=%.1f" % [t1_shown, damage_t1])
		
	# Check Test 2 (VFX at target impact position)
	# Target chest is at (0, 0.9, 0). Impact on front surface facing player at (0, 0, 1.8) is ~(0, 0.9, 0.35)
	var expected_hit_pos: Vector3 = Vector3(0, 0.9, 0.35)
	var dist_to_target: float = t1_impact_pos.distance_to(expected_hit_pos)
	var t2_pass: bool = dist_to_target < 0.20
	_record_result("TEST 2: VFX appears at target impact position", t2_pass,
		"Impact pos=%s (Expected ~%s, dist=%.3fm)" % [t1_impact_pos, expected_hit_pos, dist_to_target])

	# -----------------------------------------------------------------
	# TEST 3: Miss produces NO VFX (Facing 180 deg away)
	# -----------------------------------------------------------------
	p.visuals.rotation.y = deg_to_rad(180.0) # Facing South (+Z), away from dummy
	p._camera_yaw = deg_to_rad(180.0)
	await process_frame
	
	p._try_combat_attack()
	var t3_accidentally_shown: bool = false
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			t3_accidentally_shown = true
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var t3_pass: bool = not t3_accidentally_shown
	_record_result("TEST 3: Miss produces NO VFX", t3_pass,
		"VFX remained hidden on miss: %s" % t3_pass)

	# -----------------------------------------------------------------
	# TEST 4: Out-of-range attack produces NO VFX
	# -----------------------------------------------------------------
	# Move player 4.2m away (beyond 2.2m melee reach) facing dummy
	p.global_position = Vector3(0, 0, 4.2)
	p.visuals.rotation.y = 0.0
	p._camera_yaw = 0.0
	await process_frame
	
	p._try_combat_attack()
	var t4_accidentally_shown: bool = false
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			t4_accidentally_shown = true
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var t4_pass: bool = not t4_accidentally_shown
	_record_result("TEST 4: Out-of-range attack produces NO VFX", t4_pass,
		"VFX remained hidden beyond range reach: %s" % t4_pass)

	# -----------------------------------------------------------------
	# TEST 5: Repeated successful attacks work correctly & fade cleanly
	# -----------------------------------------------------------------
	# Return to melee range (1.8m)
	p.global_position = Vector3(0, 0, 1.8)
	p.visuals.rotation.y = 0.0
	await process_frame
	
	p._try_combat_attack()
	var attack1_shown: bool = false
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			attack1_shown = true
			break
			
	# Wait for fade
	await create_timer(0.20).timeout
	var attack1_faded: bool = not hit_vfx.visible
	
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	# Attack 2
	p._try_combat_attack()
	var attack2_shown: bool = false
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			attack2_shown = true
			break
			
	await create_timer(0.20).timeout
	var attack2_faded: bool = not hit_vfx.visible
	
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var t5_pass: bool = attack1_shown and attack1_faded and attack2_shown and attack2_faded
	_record_result("TEST 5: Repeated successful attacks & fade lifecycle", t5_pass,
		"Att1 shown=%s faded=%s, Att2 shown=%s faded=%s" % [
			attack1_shown, attack1_faded, attack2_shown, attack2_faded
		])

	# -----------------------------------------------------------------
	# TEST 6: No persistent node accumulation
	# -----------------------------------------------------------------
	var initial_child_count: int = combat.get_child_count()
	for i in range(5):
		p._try_combat_attack()
		for f in range(25): await process_frame
		while p._is_attacking or combat._cooldown_timer > 0.0:
			await process_frame
			
	var post_rapid_child_count: int = combat.get_child_count()
	var t6_pass: bool = (initial_child_count == post_rapid_child_count)
	_record_result("TEST 6: No persistent node accumulation", t6_pass,
		"Child count unchanged: %s (%d -> %d)" % [t6_pass, initial_child_count, post_rapid_child_count])

	# -----------------------------------------------------------------
	# TEST 7: FPS mode hit impact
	# -----------------------------------------------------------------
	p.set_third_person(false) # FPS mode
	p.global_position = Vector3(0, 0, 1.8)
	p._camera_yaw = 0.0
	p._camera_pitch = 0.0
	p.camera_pivot.rotation = Vector3.ZERO
	await process_frame
	
	p._try_combat_attack()
	var fps_hit_shown: bool = false
	var fps_impact_pos: Vector3 = Vector3.ZERO
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			fps_hit_shown = true
			fps_impact_pos = hit_vfx.global_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var t7_pass: bool = fps_hit_shown and (fps_impact_pos.distance_to(expected_hit_pos) < 0.20)
	_record_result("TEST 7: FPS mode hit impact", t7_pass,
		"FPS hit shown=%s, pos=%s (dist=%.3fm)" % [fps_hit_shown, fps_impact_pos, fps_impact_pos.distance_to(expected_hit_pos)])

	# -----------------------------------------------------------------
	# TEST 8: TPS mode hit impact
	# -----------------------------------------------------------------
	p.set_third_person(true) # TPS mode
	p.global_position = Vector3(1.8, 0, 0) # East of dummy
	p.visuals.rotation.y = deg_to_rad(90.0) # Facing West (-X) towards dummy
	p._camera_yaw = deg_to_rad(90.0)
	await process_frame
	
	p._try_combat_attack()
	var tps_hit_shown: bool = false
	var tps_impact_pos: Vector3 = Vector3.ZERO
	for f in range(60):
		await process_frame
		if hit_vfx.visible:
			tps_hit_shown = true
			tps_impact_pos = hit_vfx.global_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var expected_tps_hit_pos: Vector3 = Vector3(0.35, 0.9, 0.0)
	var t8_pass: bool = tps_hit_shown and (tps_impact_pos.distance_to(expected_tps_hit_pos) < 0.20)
	_record_result("TEST 8: TPS mode hit impact", t8_pass,
		"TPS hit shown=%s, pos=%s (dist=%.3fm)" % [tps_hit_shown, tps_impact_pos, tps_impact_pos.distance_to(expected_tps_hit_pos)])

	# -----------------------------------------------------------------
	# TEST 9: Existing damage amount & timing remains unchanged
	# -----------------------------------------------------------------
	_dummy_health.current_health = 100.0
	_dummy_health._is_dead = false
	p.global_position = Vector3(0, 0, 1.8)
	p.visuals.rotation.y = 0.0
	p._camera_yaw = 0.0
	await process_frame
	
	var hp_before_t9: float = _dummy_health.current_health
	p._try_combat_attack()
	
	var damage_applied_time: float = -1.0
	for f in range(60):
		await process_frame
		var cur_hp: float = _dummy_health.current_health
		if cur_hp < hp_before_t9 and damage_applied_time < 0.0:
			damage_applied_time = p.anim_player.current_animation_position
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var hp_after_t9: float = _dummy_health.current_health
	var damage_amount_t9: float = hp_before_t9 - hp_after_t9
	var t9_pass: bool = abs(damage_amount_t9 - 25.0) < 0.01 and (damage_applied_time >= 0.34)
	_record_result("TEST 9: Damage amount and timing unchanged", t9_pass,
		"Damage=%.1f (Expected 25.0), Impact anim_pos=%.3fs (Expected ~0.35s)" % [
			damage_amount_t9, damage_applied_time
		])

	# -----------------------------------------------------------------
	# TEST 10: Existing Slash Arc VFX remains unchanged
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 1.8)
	p.visuals.rotation.y = 0.0
	await process_frame
	
	p._try_combat_attack()
	var slash_shown: bool = false
	var hit_also_shown: bool = false
	var slash_pos: Vector3 = Vector3.ZERO
	
	for f in range(60):
		await process_frame
		if slash_vfx.visible:
			slash_shown = true
			slash_pos = slash_vfx.global_position
		if hit_vfx.visible:
			hit_also_shown = true
		if slash_shown and hit_also_shown:
			break
			
	while p._is_attacking or combat._cooldown_timer > 0.0:
		await process_frame
		
	var exp_slash_pos: Vector3 = Vector3(0, 0.9, 1.8 - 1.1) # 1.1m in front of player
	var slash_dist: float = slash_pos.distance_to(exp_slash_pos)
	var t10_pass: bool = slash_shown and hit_also_shown and (slash_dist < 0.05)
	_record_result("TEST 10: Slash Arc VFX co-exists unchanged", t10_pass,
		"Slash shown=%s (dist=%.3fm), Hit shown=%s" % [slash_shown, slash_dist, hit_also_shown])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("\n=================================================================")
	var total_tests: int = _test_results.size()
	var passed_tests: int = 0
	for r in _test_results:
		if r["passed"]:
			passed_tests += 1
	print("TASK 5.2 TEST SUMMARY: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("=================================================================")
	
	if passed_tests == total_tests:
		quit(0)
	else:
		quit(1)
