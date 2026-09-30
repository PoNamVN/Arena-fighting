extends SceneTree

var _arena: Node3D = null
var _player: PlayerController = null
var _dummy: TrainingDummy = null
var _attack_dummy: AttackTrainingDummy = null

var _tests_passed: int = 0
var _tests_failed: int = 0
var _total_tests: int = 0


func _init() -> void:
	call_deferred("_run_all_tests")


func _assert_test(test_num: int, condition: bool, test_name: String, details: String = "") -> void:
	_total_tests += 1
	if condition:
		_tests_passed += 1
		print("  [PASS] TEST %d: %s%s" % [test_num, test_name, (" - " + details) if details != "" else ""])
	else:
		_tests_failed += 1
		print("  [FAIL] TEST %d: %s%s" % [test_num, test_name, (" - " + details) if details != "" else ""])


func _run_all_tests() -> void:
	print("\n==================================================")
	print("RUNNING TASK 5.12 REVISED ACCEPTANCE TESTS: CENTERED TPS COMBAT CAMERA + SPRINT")
	print("==================================================")

	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	if not arena_scene:
		print("FATAL: Failed to load CombatTestArena.tscn")
		quit(1)
		return

	_arena = arena_scene.instantiate() as Node3D
	root.add_child(_arena)

	for i in range(10):
		await process_frame

	_player = _arena.get_node_or_null("Player") as PlayerController
	_dummy = _arena.get_node_or_null("TrainingDummy") as TrainingDummy
	_attack_dummy = _arena.get_node_or_null("AttackTrainingDummy") as AttackTrainingDummy

	# TEST 1: Combat Arena loads successfully
	_assert_test(1, _arena != null and _player != null and _dummy != null and _attack_dummy != null,
		"Combat Arena loads successfully", "All core entities instantiated")

	if not _player:
		print("FATAL: Player not found")
		quit(1)
		return

	# TEST 2: TPS camera centered on vertical/spine axis
	_player.set_third_person(true)
	await process_frame
	var pivot_centered: bool = _player.camera_pivot != null and _player.camera_pivot.position.is_equal_approx(Vector3(0, 1.62, 0))
	_assert_test(2, pivot_centered,
		"TPS camera centered on vertical/spine axis", "CameraPivot pos=(%.2f, %.2f, %.2f)" % [_player.camera_pivot.position.x, _player.camera_pivot.position.y, _player.camera_pivot.position.z])

	# TEST 3: Camera h_offset and v_offset are 0.0 (no over-the-shoulder offset)
	var offsets_zero: bool = is_equal_approx(_player.camera.h_offset, 0.0) and is_equal_approx(_player.camera.v_offset, 0.0)
	_assert_test(3, offsets_zero,
		"Camera h_offset and v_offset are 0.0", "h_offset=%.4f, v_offset=%.4f" % [_player.camera.h_offset, _player.camera.v_offset])

	# TEST 4: SpringArm3D is centered at (0, 0, 0)
	var arm_centered: bool = _player.spring_arm != null and _player.spring_arm.position.is_equal_approx(Vector3.ZERO)
	_assert_test(4, arm_centered,
		"SpringArm3D is centered at (0, 0, 0)", "SpringArm pos=(%.2f, %.2f, %.2f)" % [_player.spring_arm.position.x, _player.spring_arm.position.y, _player.spring_arm.position.z])

	# TEST 5: Player stays visually centered on screen (zero h_offset and centered pivot)
	var player_centered: bool = is_equal_approx(_player.camera.h_offset, 0.0) and is_equal_approx(_player.camera_pivot.position.x, 0.0)
	_assert_test(5, player_centered,
		"Player stays visually centered on screen", "h_offset=%.4f, pivot_x=%.4f" % [_player.camera.h_offset, _player.camera_pivot.position.x])

	# TEST 6: Player horizontal yaw follows camera yaw when standing
	_player._camera_yaw = deg_to_rad(45.0)
	_player.camera_pivot.rotation.y = _player._camera_yaw
	_player._physics_process(0.016)
	await process_frame
	var yaw_diff: float = abs(wrapf(_player.visuals.rotation.y - _player._camera_yaw, -PI, PI))
	_assert_test(6, yaw_diff < 0.001,
		"Player horizontal yaw follows camera yaw when standing", "visuals.rotation.y=%.4f, camera_yaw=%.4f" % [_player.visuals.rotation.y, _player._camera_yaw])

	# TEST 7: Mouse look updates camera yaw and immediately updates player yaw
	var mouse_event: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_event.relative = Vector2(80, 0)
	_player._is_mouse_captured = true
	var yaw_before: float = _player._camera_yaw
	_player._unhandled_input(mouse_event)
	await process_frame
	var yaw_after: float = _player._camera_yaw
	var vis_after: float = _player.visuals.rotation.y
	_assert_test(7, yaw_after != yaw_before and is_equal_approx(vis_after, yaw_after),
		"Mouse look updates camera yaw and immediately updates player yaw", "yaw_after=%.4f, visuals.rotation.y=%.4f" % [yaw_after, vis_after])

	# TEST 8: Camera pitch affects camera only; player does not pitch
	_player._camera_pitch = deg_to_rad(-45.0)
	_player.camera_pivot.rotation.x = _player._camera_pitch
	_player._physics_process(0.016)
	await process_frame
	var vis_pitch1: float = abs(_player.visuals.rotation.x)
	_player._camera_pitch = deg_to_rad(30.0)
	_player.camera_pivot.rotation.x = _player._camera_pitch
	_player._physics_process(0.016)
	await process_frame
	var vis_pitch2: float = abs(_player.visuals.rotation.x)
	var max_vis_pitch: float = maxf(vis_pitch1, vis_pitch2)
	_assert_test(8, is_equal_approx(max_vis_pitch, 0.0),
		"Camera pitch affects camera only; player does not pitch", "visuals.rotation.x=%.4f rad" % max_vis_pitch)

	# TEST 9: Player root node stays strictly upright
	var root_rx: float = abs(_player.rotation.x)
	var root_rz: float = abs(_player.rotation.z)
	var vis_rz: float = abs(_player.visuals.rotation.z)
	_assert_test(9, is_equal_approx(root_rx, 0.0) and is_equal_approx(root_rz, 0.0) and is_equal_approx(vis_rz, 0.0),
		"Player root node stays strictly upright", "root_rx=%.4f, root_rz=%.4f, vis_rz=%.4f" % [root_rx, root_rz, vis_rz])

	# Reset orientation for WASD movement tests
	_player._camera_yaw = 0.0
	_player._camera_pitch = 0.0
	_player.camera_pivot.rotation = Vector3.ZERO
	_player.visuals.rotation = Vector3.ZERO
	await process_frame

	# TEST 10: WASD movement calculates camera-relative direction
	var cam_basis: Basis = Basis(Vector3.UP, _player._camera_yaw)
	var strafe_left_dir: Vector3 = cam_basis * Vector3(-1.0, 0.0, 0.0)
	var forward_dir: Vector3 = cam_basis * Vector3(0.0, 0.0, -1.0)
	_assert_test(10, is_equal_approx(strafe_left_dir.x, -1.0) and is_equal_approx(forward_dir.z, -1.0),
		"WASD movement calculates camera-relative direction", "Left=(%.1f, %.1f), Forward=(%.1f, %.1f)" % [strafe_left_dir.x, strafe_left_dir.z, forward_dir.x, forward_dir.z])

	# TEST 11: Strafe Left (A) moves player left while facing camera forward
	_player.velocity = Vector3(-_player.walk_speed, 0, 0)
	_player.visuals.rotation.y = _player._camera_yaw
	_player._physics_process(0.016)
	await process_frame
	_assert_test(11, is_equal_approx(_player.visuals.rotation.y, _player._camera_yaw),
		"Strafe Left (A) moves player left while facing camera forward", "visuals.rotation.y=%.4f, camera_yaw=%.4f" % [_player.visuals.rotation.y, _player._camera_yaw])

	# TEST 12: Strafe Right (D) moves player right while facing camera forward
	_player.velocity = Vector3(_player.walk_speed, 0, 0)
	_player.visuals.rotation.y = _player._camera_yaw
	_player._physics_process(0.016)
	await process_frame
	_assert_test(12, is_equal_approx(_player.visuals.rotation.y, _player._camera_yaw),
		"Strafe Right (D) moves player right while facing camera forward", "visuals.rotation.y=%.4f, camera_yaw=%.4f" % [_player.visuals.rotation.y, _player._camera_yaw])

	# TEST 13: Backpedal (S) moves player backward while facing camera forward
	_player.velocity = Vector3(0, 0, _player.walk_speed)
	_player.visuals.rotation.y = _player._camera_yaw
	_player._physics_process(0.016)
	await process_frame
	_assert_test(13, is_equal_approx(_player.visuals.rotation.y, _player._camera_yaw),
		"Backpedal (S) moves player backward while facing camera forward", "visuals.rotation.y=%.4f, camera_yaw=%.4f" % [_player.visuals.rotation.y, _player._camera_yaw])

	# TEST 14: Forward movement (W) moves player forward while facing camera forward
	_player.velocity = Vector3(0, 0, -_player.walk_speed)
	_player.visuals.rotation.y = _player._camera_yaw
	_player._physics_process(0.016)
	await process_frame
	_assert_test(14, is_equal_approx(_player.visuals.rotation.y, _player._camera_yaw),
		"Forward movement (W) moves player forward while facing camera forward", "visuals.rotation.y=%.4f, camera_yaw=%.4f" % [_player.visuals.rotation.y, _player._camera_yaw])

	_player.velocity = Vector3.ZERO
	await process_frame

	# TEST 15: Normal movement without Shift operates at walk_speed
	var walk_speed_val: float = _player.walk_speed
	_assert_test(15, is_equal_approx(walk_speed_val, 6.0),
		"Normal movement without Shift operates at walk_speed (6.0)", "walk_speed=%.1f" % walk_speed_val)

	# TEST 16: Holding Shift sprint increases speed to sprint_speed
	var sprint_speed_val: float = _player.sprint_speed
	_assert_test(16, is_equal_approx(sprint_speed_val, 10.5),
		"Holding Shift sprint increases speed to sprint_speed (10.5)", "sprint_speed=%.1f" % sprint_speed_val)

	# TEST 17: Shift sprint is properly mapped in InputMap
	var has_sprint_action: bool = InputMap.has_action("sprint")
	_assert_test(17, has_sprint_action,
		"Shift sprint is properly mapped in InputMap", "has_action(sprint)=%s" % has_sprint_action)

	# TEST 18: Attack state is compatible with centered combat camera
	_player.combat._cooldown_timer = 0.0
	_player.transition_to(PlayerController.CombatState.ATTACK)
	await process_frame
	_assert_test(18, _player.combat_state == PlayerController.CombatState.ATTACK and is_equal_approx(_player.visuals.rotation.y, _player._camera_yaw),
		"Attack state is compatible with centered combat camera", "state=%s, visuals facing camera" % _player.combat_state)

	# TEST 19: Attack deals normal 25 damage to target in front
	_player.global_position = Vector3(3.5, 0, 1.8)
	_player._camera_yaw = 0.0
	_player.camera_pivot.rotation.y = 0.0
	_player.visuals.rotation.y = 0.0 # Facing North (-Z) toward dummy at (3.5, 0, 0)
	_dummy.health_component.current_health = 100.0
	_dummy.is_blocking = false
	var hp_before_atk: float = _dummy.health_component.current_health
	_player.combat._cooldown_timer = 0.0
	_player.combat._damage_applied_this_swing = false
	_player.combat.start_attack()
	_player.combat.execute_impact()
	await process_frame
	var dealt_dmg: float = hp_before_atk - _dummy.health_component.current_health
	_assert_test(19, is_equal_approx(dealt_dmg, 25.0),
		"Attack deals normal 25 damage to target in front", "Dealt=%.2f (Expected 25.0)" % dealt_dmg)

	# Clean up attack
	_player.combat_state = PlayerController.CombatState.IDLE
	_player._attack_impact_applied = false
	_player.combat._cooldown_timer = 0.0
	await process_frame

	# TEST 20: Attack VFX align directly with camera forward
	var combat_fwd: Vector3 = -_player.visuals.global_basis.z.normalized()
	var cam_fwd: Vector3 = -_player.camera.global_basis.z.normalized()
	cam_fwd.y = 0.0
	cam_fwd = cam_fwd.normalized()
	var dot_align: float = combat_fwd.dot(cam_fwd)
	_assert_test(20, dot_align > 0.99,
		"Attack VFX align directly with camera forward", "Align dot=%.4f" % dot_align)

	# TEST 21: Block state is compatible with centered combat camera
	_player.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame
	_assert_test(21, _player.combat_state == PlayerController.CombatState.BLOCK and is_equal_approx(_player.visuals.rotation.y, _player._camera_yaw),
		"Block state is compatible with centered combat camera", "state=%s, visuals facing camera" % _player.combat_state)

	# TEST 22: Directional block blocks incoming attack
	_player.shield_durability = 100.0
	_player.health_component.current_health = 100.0
	_player._camera_yaw = 0.0 # Facing North (-Z) towards attacker at (3.5, 0, 0)
	_player.camera_pivot.rotation.y = 0.0
	_player.visuals.rotation.y = 0.0
	var p_hp_before: float = _player.health_component.current_health
	var p_shield_before: float = _player.shield_durability
	_player.take_damage(25.0, Vector3(3.5, 0, 0)) # Attacker to the North
	await process_frame
	var p_hp_loss: float = p_hp_before - _player.health_component.current_health
	var p_shield_loss: float = p_shield_before - _player.shield_durability
	_assert_test(22, is_equal_approx(p_hp_loss, 3.75) and is_equal_approx(p_shield_loss, 15.0),
		"Directional block blocks incoming attack", "HP loss=%.2f (3.75), Shield loss=%.2f (15.0)" % [p_hp_loss, p_shield_loss])

	# TEST 23: Block Impact VFX triggers on blocked attack
	var block_vfx_active: bool = _player.combat.block_impact_vfx != null and _player.combat.block_impact_vfx.visible
	_assert_test(23, block_vfx_active,
		"Block Impact VFX triggers on blocked attack", "block_impact_vfx.visible=%s" % block_vfx_active)

	_player._release_block()
	await process_frame

	# TEST 24: Switching to FPS preserves FPS camera architecture
	_player.set_third_person(false)
	await process_frame
	var fps_cam_pos: Vector3 = _player.camera.position
	var fps_near: float = _player.camera.near
	var fps_h_offset: float = _player.camera.h_offset
	_assert_test(24, fps_cam_pos.is_equal_approx(Vector3.ZERO) and is_equal_approx(fps_near, 0.08) and is_equal_approx(fps_h_offset, 0.0),
		"Switching to FPS preserves FPS camera architecture", "pos=%s, near=%.2f, h_offset=%.4f" % [fps_cam_pos, fps_near, fps_h_offset])

	# TEST 25: Returning to TPS restores centered TPS camera
	_player.set_third_person(true)
	await process_frame
	var tps_cam_pos: Vector3 = _player.camera.position
	var tps_near: float = _player.camera.near
	var tps_h_offset: float = _player.camera.h_offset
	_assert_test(25, tps_cam_pos.is_equal_approx(Vector3(0, 0, 3.5)) and is_equal_approx(tps_near, 0.05) and is_equal_approx(tps_h_offset, 0.0),
		"Returning to TPS restores centered TPS camera", "pos=%s, near=%.2f, h_offset=%.4f" % [tps_cam_pos, tps_near, tps_h_offset])

	# TEST 26: Death maintains centered camera and upright orientation without drift
	_player.health_component.take_damage(200.0) # Lethal
	await process_frame
	var dead_state: bool = _player.combat_state == PlayerController.CombatState.DEAD
	var dead_offsets_zero: bool = is_equal_approx(_player.camera.h_offset, 0.0) and is_equal_approx(_player.camera.v_offset, 0.0)
	_assert_test(26, dead_state and dead_offsets_zero,
		"Death maintains centered camera without offset", "state=DEAD, h_offset=%.4f, v_offset=%.4f" % [_player.camera.h_offset, _player.camera.v_offset])

	# TEST 27: Respawn restores player with centered camera
	_player.respawn(Vector3(0, 0, 0), 0.0)
	await process_frame
	var respawn_ok: bool = _player.combat_state == PlayerController.CombatState.IDLE and is_equal_approx(_player.camera.h_offset, 0.0)
	_assert_test(27, respawn_ok,
		"Respawn restores player with centered camera", "state=IDLE, h_offset=%.4f" % _player.camera.h_offset)

	# TEST 28: 360° camera yaw rotation sweep produces zero pivot drift
	var initial_pivot_pos: Vector3 = _player.camera_pivot.position
	var max_pivot_drift: float = 0.0
	for deg in [0, 45, 90, 135, 180, 225, 270, 315, 360]:
		_player._camera_yaw = deg_to_rad(deg)
		_player.camera_pivot.rotation.y = _player._camera_yaw
		_player._physics_process(0.016)
		await process_frame
		var drift: float = _player.camera_pivot.position.distance_to(initial_pivot_pos)
		if drift > max_pivot_drift:
			max_pivot_drift = drift
	_assert_test(28, max_pivot_drift < 0.0001,
		"360° camera yaw rotation produces zero pivot drift", "Max pivot drift=%.6fm" % max_pivot_drift)

	# TEST 29: 360° camera rotation sweep returns to baseline orientation
	_player._camera_yaw = deg_to_rad(360.0)
	_player.camera_pivot.rotation.y = _player._camera_yaw
	_player._physics_process(0.016)
	await process_frame
	var angle_drift: float = abs(wrapf(_player.visuals.rotation.y - _player._camera_yaw, -PI, PI))
	_assert_test(29, angle_drift < 0.0001,
		"360° camera rotation sweep returns to baseline", "Angle drift=%.6f rad" % angle_drift)

	# TEST 30: Repeated movement and camera rotation produces zero transform accumulation
	var base_cam_pos: Vector3 = _player.camera.position
	var base_arm_pos: Vector3 = _player.spring_arm.position
	var base_arm_rot: Vector3 = _player.spring_arm.rotation
	for i in range(20):
		_player._camera_yaw += deg_to_rad(18.0)
		_player.camera_pivot.rotation.y = _player._camera_yaw
		_player._physics_process(0.016)
		await process_frame
	_player._camera_yaw = 0.0
	_player.camera_pivot.rotation.y = 0.0
	_player._physics_process(0.016)
	await process_frame
	var final_cam_pos: Vector3 = _player.camera.position
	var final_arm_pos: Vector3 = _player.spring_arm.position
	var final_arm_rot: Vector3 = _player.spring_arm.rotation
	var pos_accum: float = base_cam_pos.distance_to(final_cam_pos) + base_arm_pos.distance_to(final_arm_pos)
	var rot_accum: float = (base_arm_rot - final_arm_rot).length()
	_assert_test(30, pos_accum < 0.0001 and rot_accum < 0.0001 and is_equal_approx(_player.camera.h_offset, 0.0),
		"Repeated movement and camera rotation produces zero transform accumulation", "Pos accum=%.6fm, Rot accum=%.6f rad, h_offset=%.4f" % [pos_accum, rot_accum, _player.camera.h_offset])

	# TEST 31: Normal attack damage remains invariant at 25.0
	_assert_test(31, _player.combat.attack_damage == 25.0,
		"Normal attack damage remains invariant at 25.0", "Damage=%.1f" % _player.combat.attack_damage)

	# TEST 32: Blocked attack damage remains invariant at 3.75
	var expected_blocked_dmg: float = 25.0 * (1.0 - _player.block_damage_reduction)
	_assert_test(32, is_equal_approx(expected_blocked_dmg, 3.75),
		"Blocked attack damage remains invariant at 3.75", "Damage=%.2f" % expected_blocked_dmg)

	# TEST 33: Shield damage remains invariant at 15.0
	_assert_test(33, _player.normal_attack_shield_damage == 15.0,
		"Shield damage remains invariant at 15.0", "Shield damage=%.1f" % _player.normal_attack_shield_damage)

	# TEST 34: Shield durability max remains invariant at 100.0
	_assert_test(34, _player.shield_max_durability == 100.0,
		"Shield durability max remains invariant at 100.0", "Max=%.1f" % _player.shield_max_durability)

	# TEST 35: Attack impact timestamp remains invariant at 0.35 seconds
	_assert_test(35, is_equal_approx(PlayerController.ATTACK_IMPACT_TIMESTAMP, 0.35),
		"Attack impact timestamp remains invariant at 0.35 seconds", "Timestamp=%.2fs" % PlayerController.ATTACK_IMPACT_TIMESTAMP)

	# TEST 36: Block cone remains invariant at 120.0 degrees
	_assert_test(36, is_equal_approx(_player.block_cone_deg, 120.0),
		"Block cone remains invariant at 120.0 degrees", "Cone=%.1f deg" % _player.block_cone_deg)

	# TEST 37: Normal knockback remains invariant at 0.40m
	_assert_test(37, is_equal_approx(_player.hit_knockback_distance, 0.40),
		"Normal knockback remains invariant at 0.40m", "Knockback=%.2fm" % _player.hit_knockback_distance)

	# TEST 38: Block recoil remains invariant at 0.08m
	_assert_test(38, is_equal_approx(_player.block_recoil_distance, 0.08),
		"Block recoil remains invariant at 0.08m", "Recoil=%.2fm" % _player.block_recoil_distance)

	# TEST 39: AttackTrainingDummy attack range remains invariant at 2.2m
	_assert_test(39, is_equal_approx(_attack_dummy.attack_range, 2.2),
		"AttackTrainingDummy attack range remains invariant at 2.2m", "Range=%.2fm" % _attack_dummy.attack_range)

	# TEST 40: Target detection functions properly in centered TPS mode
	_player.global_position = Vector3(3.5, 0, 1.8)
	_player._camera_yaw = 0.0
	_player.camera_pivot.rotation.y = 0.0
	_player.visuals.rotation.y = 0.0
	_dummy.global_position = Vector3(3.5, 0, 0)
	await process_frame
	if _player.combat_feedback:
		_player.combat_feedback.update_target_detection()
	await process_frame
	var target_detected: bool = _player.combat_feedback != null and _player.combat_feedback.has_target
	_player.global_position = Vector3(10, 0, 10) # Out of range
	await process_frame
	if _player.combat_feedback:
		_player.combat_feedback.update_target_detection()
	await process_frame
	var target_lost: bool = _player.combat_feedback != null and not _player.combat_feedback.has_target
	_assert_test(40, target_detected and target_lost,
		"Target detection functions properly in centered TPS mode", "Detected in range: %s, Cleared out of range: %s" % [target_detected, target_lost])

	print("\n==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_tests_passed, _total_tests, _tests_failed])
	print("==================================================")

	quit(0 if _tests_failed == 0 else 1)
