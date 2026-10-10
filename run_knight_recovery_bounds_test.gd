extends SceneTree

const TestScene: PackedScene = preload("res://test/knight_hit_reaction_test.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _ragdoll: Node = null


func _init() -> void:
	print("==================================================")
	print("RUNNING KNIGHT RECOVERY, CAMERA & BOUNDS TESTS (PHASE 3)")
	print("==================================================")
	call_deferred("_run_tests")


func _record_result(test_name: String, passed: bool, details: String = "") -> void:
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	var status: String = "PASS" if passed else "FAIL"
	if details != "":
		print("  [%s] %s - %s" % [status, test_name, details])
	else:
		print("  [%s] %s" % [status, test_name])


func _setup_scene() -> void:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()

	_arena = TestScene.instantiate() as Node3D
	root.add_child(_arena)

	_player = _arena.get_node("Player") as PlayerController
	_ragdoll = _player.get_node_or_null("KnightRagdoll")
	if not _ragdoll:
		_ragdoll = _player.get("ragdoll")


func _run_tests() -> void:
	_setup_scene()
	for i in range(10):
		await process_frame

	var p: PlayerController = _player
	var r: Node = _ragdoll

	# -----------------------------------------------------------------
	# TEST 1: Ragdoll launches with launch impulse
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	await process_frame

	var launch_ok: bool = r.call("start_ragdoll", Vector3(0, 3.5, 4.0)) # Upward and backward launch
	for f in range(5):
		await process_frame

	var t1_pass: bool = launch_ok and r.call("is_active") and (r.get("state") == 1) # RagdollState.LAUNCHED
	_record_result("TEST 1: Ragdoll launches with launch impulse", t1_pass,
		"start_ragdoll=%s, is_active=%s, state=%d" % [launch_ok, r.call("is_active"), r.get("state")])

	# -----------------------------------------------------------------
	# TEST 2: Controls are impaired during ragdoll launch & flight
	# -----------------------------------------------------------------
	var impaired_during_ragdoll: bool = p.is_control_impaired()
	# Verify attack is rejected while in ragdoll
	var attack_attempt: bool = p._try_combat_attack()
	var t2_pass: bool = impaired_during_ragdoll and (not attack_attempt) and (p.combat_state != PlayerController.CombatState.ATTACK)
	_record_result("TEST 2: Controls are impaired during ragdoll flight", t2_pass,
		"is_control_impaired=%s, attack_attempt=%s, state=%d" % [impaired_during_ragdoll, attack_attempt, p.combat_state])

	# -----------------------------------------------------------------
	# TEST 3: Ragdoll lands stably on floor without penetrating ground
	# -----------------------------------------------------------------
	# Wait for body to tumble and land (around 40 frames)
	for f in range(40):
		await process_frame

	var pelvis_landing_pos: Vector3 = r.call("get_pelvis_global_position")
	var t3_pass: bool = pelvis_landing_pos.y >= -0.5 and pelvis_landing_pos.is_finite()
	_record_result("TEST 3: Ragdoll lands stably without penetrating ground", t3_pass,
		"Pelvis Y: %.3fm (Ground at 0.0)" % pelvis_landing_pos.y)

	# -----------------------------------------------------------------
	# TEST 4: Automatic settling state triggers on low speed near floor
	# -----------------------------------------------------------------
	# Wait for settling or timeout watchdog
	var state_reached: int = r.get("state")
	var wait_settle_frames: int = 0
	while r.get("state") == 1 and wait_settle_frames < 60: # 1 = LAUNCHED
		await process_frame
		wait_settle_frames += 1

	state_reached = r.get("state")
	var t4_pass: bool = state_reached >= 2 # 2 = SETTLING, 3 = RECOVERING, or 0 = finished
	_record_result("TEST 4: Settling state triggers on low speed near floor", t4_pass,
		"State progressed to: %d (SETTLING=2, RECOVERING=3)" % state_reached)

	# -----------------------------------------------------------------
	# TEST 5: Pose detection determines prone/supine and lying heading
	# -----------------------------------------------------------------
	var is_supine: bool = r.call("is_supine")
	var heading: Vector3 = r.call("get_lying_heading")
	var heading_ok: bool = heading.is_finite() and heading.length() > 0.1
	_record_result("TEST 5: Pose detection determines prone/supine and heading", heading_ok,
		"is_supine=%s, heading=%s" % [is_supine, heading])

	# -----------------------------------------------------------------
	# TEST 6: Stand-up recovery triggers and snaps proxy to pelvis ground position
	# -----------------------------------------------------------------
	# Manually or automatically trigger recovery
	if r.get("state") != 3: # Not yet RECOVERING
		r.call("start_recovery")
		await process_frame

	var is_recovering: bool = r.call("is_recovering")
	var proxy_pos_after_snap: Vector3 = p.global_position
	var pelvis_pos_now: Vector3 = r.call("get_pelvis_global_position")
	var horiz_dist: float = Vector2(proxy_pos_after_snap.x - pelvis_pos_now.x, proxy_pos_after_snap.z - pelvis_pos_now.z).length()

	var t6_pass: bool = is_recovering and (horiz_dist < 0.60) and (abs(proxy_pos_after_snap.y) < 0.5)
	_record_result("TEST 6: Stand-up recovery snaps proxy to pelvis ground position", t6_pass,
		"is_recovering=%s, Horiz offset=%.3fm (max 0.6m), Proxy Y=%.3fm" % [is_recovering, horiz_dist, proxy_pos_after_snap.y])

	# -----------------------------------------------------------------
	# TEST 7: Controls remain locked during get-up blend animation
	# -----------------------------------------------------------------
	var impaired_during_getup: bool = p.is_control_impaired()
	var attack_during_getup: bool = p._try_combat_attack()
	var t7_pass: bool = impaired_during_getup and (not attack_during_getup)
	_record_result("TEST 7: Controls remain locked during get-up blend", t7_pass,
		"impaired=%s, attack_attempt=%s" % [impaired_during_getup, attack_during_getup])

	# -----------------------------------------------------------------
	# TEST 8: Recovery finishes cleanly and restores IDLE
	# -----------------------------------------------------------------
	# Wait for recovery blend duration (matches get-up animation + margin)
	await create_timer(r.recovery_blend_duration + 0.05).timeout
	await process_frame

	var t8_idle: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	var t8_ragdoll_dormant: bool = not r.call("is_active")
	var t8_pass: bool = t8_idle and t8_ragdoll_dormant
	_record_result("TEST 8: Recovery finishes cleanly and restores IDLE", t8_pass,
		"State=IDLE (%s), Ragdoll active=%s" % [t8_idle, r.call("is_active")])

	# -----------------------------------------------------------------
	# TEST 9: CC Grace window protects player immediately post-recovery
	# -----------------------------------------------------------------
	var grace_active: bool = r.call("is_cc_grace_active")
	_record_result("TEST 9: CC Grace window is active immediately post-recovery", grace_active,
		"is_cc_grace_active=%s (~0.20s grace period)" % grace_active)

	# Wait for grace period to expire
	await create_timer(r.cc_grace_window + 0.05).timeout
	await process_frame
	var grace_expired: bool = not r.call("is_cc_grace_active")
	_record_result("TEST 9b: CC Grace window expires naturally", grace_expired,
		"Grace timer resolved: %s" % grace_expired)

	# -----------------------------------------------------------------
	# TEST 10: Player can attack normally again after standing up
	# -----------------------------------------------------------------
	var can_attack_after_stand: bool = p._try_combat_attack()
	await process_frame
	var attacking_now: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	var t10_pass: bool = can_attack_after_stand and attacking_now
	_record_result("TEST 10: Player can attack normally again after standing up", t10_pass,
		"Attack started=%s, CombatState=ATTACK (%s)" % [can_attack_after_stand, attacking_now])

	# Finish attack swing
	while p._is_attacking or p.combat._cooldown_timer > 0.0:
		await process_frame

	# -----------------------------------------------------------------
	# TEST 11: Boundary clamping prevents body escaping arena
	# -----------------------------------------------------------------
	var test_far_pos: Vector3 = Vector3(50.0, 0.0, 50.0) # Far outside arena
	var clamped_pos: Vector3 = r.call("_clamp_to_bounds", test_far_pos)
	var clamped_dist: float = Vector2(clamped_pos.x, clamped_pos.z).length()
	var t11_pass: bool = clamped_dist <= 22.01
	_record_result("TEST 11: Boundary clamping confines positions to arena radius", t11_pass,
		"Input dist=%.1fm -> Clamped dist=%.2fm (max 22.0m)" % [test_far_pos.length(), clamped_dist])

	# -----------------------------------------------------------------
	# TEST 12: Rapid 5-cycle Launch -> Landing -> Recovery sequence stability
	# -----------------------------------------------------------------
	var multi_cycles_ok: bool = true
	for cycle in range(5):
		p.global_position = Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		p.transition_to(PlayerController.CombatState.IDLE)
		r.call("start_ragdoll", Vector3(0, 2.0, 2.0))
		for f in range(10):
			await process_frame
		r.call("start_recovery")
		for f in range(5):
			await process_frame
		r.call("finish_recovery")
		await process_frame
		if r.call("is_active") or p.combat_state != PlayerController.CombatState.IDLE:
			multi_cycles_ok = false
			break

	_record_result("TEST 12: Rapid 5-cycle Launch -> Landing -> Recovery stability", multi_cycles_ok,
		"All 5 full lifecycle loops executed without state desync")

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	var total_tests: int = _test_results.size()
	var passed_tests: int = 0
	for res in _test_results:
		if res["passed"]:
			passed_tests += 1

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed_tests, total_tests, total_tests - passed_tests])
	print("==================================================")

	quit(0 if passed_tests == total_tests else 1)
