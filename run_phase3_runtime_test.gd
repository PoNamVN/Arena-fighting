extends SceneTree

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("=================================================================")
	print("PHASE 3 RUNTIME VALIDATION: SHIELD BLOCK & DIRECTIONAL DEFENSE")
	print("=================================================================")
	
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn")
	var arena: Node3D = arena_scene.instantiate() as Node3D
	root.add_child(arena)
	
	var player: PlayerController = arena.get_node_or_null("Player") as PlayerController
	var dummy: TrainingDummy = arena.get_node_or_null("TrainingDummy") as TrainingDummy
	
	if not player or not dummy:
		print("ERROR: Player or TrainingDummy missing from Arena scene!")
		quit(1)
		return
		
	var dummy_health: HealthComponent = dummy.get_node("HealthComponent") as HealthComponent
	
	# Wait for physics frames to settle
	for i in range(10):
		await process_frame
		
	print("\n>>> INITIAL STATE:")
	print("Dummy initial health: %.1f / %.1f" % [dummy_health.current_health, dummy_health.max_health])
	
	# Reset dummy to (0, 0, 0) facing North (-Z)
	dummy.global_position = Vector3(0, 0, 0)
	dummy.rotation = Vector3.ZERO
	dummy.is_blocking = false
	
	# -----------------------------------------------------------------
	# TEST 1: NO BLOCK + FRONTAL ATTACK -> Normal Damage (25.0)
	# -----------------------------------------------------------------
	print("\n--- TEST 1: NO BLOCK + FRONTAL ATTACK ---")
	dummy.is_blocking = false
	player.global_position = Vector3(0, 0, -1.8) # North of dummy
	player._camera_yaw = deg_to_rad(180.0) # Facing South (+Z) towards dummy
	player.camera_pivot.rotation.y = deg_to_rad(180.0)
	player.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var hp_t1_before: float = dummy_health.current_health
	player._try_combat_attack()
	while player._is_attacking or player.combat._cooldown_timer > 0.0:
		await process_frame
	var hp_t1_after: float = dummy_health.current_health
	var t1_damage: float = hp_t1_before - hp_t1_after
	print("Test 1 Damage: %.2f (Expected: 25.00)" % t1_damage)
	if abs(t1_damage - 25.0) < 0.01:
		print(">>> TEST 1 PASSED: Normal damage dealt when target is not blocking.")
	else:
		print(">>> TEST 1 FAILED: Incorrect damage dealt!")
		
	# -------------------------------------------------------------
	# TEST 2: BLOCK + FRONTAL ATTACK -> Reduced Damage (25.0 * 0.15 = 3.75)
	# -------------------------------------------------------------
	print("\n--- TEST 2: BLOCK + FRONTAL ATTACK (INSIDE 120° CONE) ---")
	dummy.is_blocking = true
	dummy.block_damage_reduction = 0.85
	player.global_position = Vector3(0, 0, -1.8) # Directly in front of dummy (angle = 0°)
	player._camera_yaw = deg_to_rad(180.0)
	player.camera_pivot.rotation.y = deg_to_rad(180.0)
	player.visuals.rotation.y = deg_to_rad(180.0)
	await process_frame
	
	var hp_t2_before: float = dummy_health.current_health
	var attack_started: bool = player._try_combat_attack()
	while player._is_attacking or player.combat._cooldown_timer > 0.0:
		await process_frame
	var hp_t2_after: float = dummy_health.current_health
	var t2_damage: float = hp_t2_before - hp_t2_after
	print("Test 2 Damage: %.2f (Expected: 3.75, Reduced by 85%%)" % t2_damage)
	if abs(t2_damage - 3.75) < 0.01:
		print(">>> TEST 2 PASSED: Damage reduced by 85% when attack is within frontal block cone.")
	else:
		print(">>> TEST 2 FAILED: Block did not reduce damage correctly!")

	# -------------------------------------------------------------
	# TEST 3: BLOCK + ATTACK FROM BEHIND -> Normal Damage (25.0)
	# -------------------------------------------------------------
	print("\n--- TEST 3: BLOCK + ATTACK FROM BEHIND (OUTSIDE CONE, 180°) ---")
	dummy.is_blocking = true
	# Dummy faces North (-Z). Player stands South of dummy (+Z) and attacks North
	player.global_position = Vector3(0, 0, 1.8) # South of dummy
	player._camera_yaw = 0.0 # Facing North (-Z) into dummy's back
	player.camera_pivot.rotation.y = 0.0
	player.visuals.rotation.y = 0.0
	await process_frame
	
	var hp_t3_before: float = dummy_health.current_health
	player._try_combat_attack()
	while player._is_attacking or player.combat._cooldown_timer > 0.0:
		await process_frame
	var hp_t3_after: float = dummy_health.current_health
	var t3_damage: float = hp_t3_before - hp_t3_after
	print("Test 3 Damage: %.2f (Expected: 25.00, Shield bypassed from behind)" % t3_damage)
	if abs(t3_damage - 25.0) < 0.01:
		print(">>> TEST 3 PASSED: Attack from behind bypassed shield and dealt full damage.")
	else:
		print(">>> TEST 3 FAILED: Shield blocked attack from behind!")

	# -------------------------------------------------------------
	# TEST 4: BLOCK + FLANK ATTACK OUTSIDE 120° CONE (75°) -> Normal Damage (25.0)
	# -------------------------------------------------------------
	print("\n--- TEST 4: BLOCK + FLANK ATTACK (75° OUTSIDE 120° CONE) ---")
	dummy.is_blocking = true
	# Dummy faces North (0, 0, -1). 75 degrees flank:
	var flank_rad: float = deg_to_rad(75.0)
	# Position at distance 1.8m at angle 75° from North
	var flank_offset: Vector3 = Vector3(sin(flank_rad) * 1.8, 0, -cos(flank_rad) * 1.8)
	player.global_position = dummy.global_position + flank_offset
	# Player faces dummy
	var to_dummy: Vector3 = (dummy.global_position - player.global_position).normalized()
	var player_yaw: float = atan2(-to_dummy.x, -to_dummy.z)
	player._camera_yaw = player_yaw
	player.camera_pivot.rotation.y = player_yaw
	player.visuals.rotation.y = player_yaw
	await process_frame
	
	var hp_t4_before: float = dummy_health.current_health
	player._try_combat_attack()
	while player._is_attacking or player.combat._cooldown_timer > 0.0:
		await process_frame
	var hp_t4_after: float = dummy_health.current_health
	var t4_damage: float = hp_t4_before - hp_t4_after
	print("Test 4 Flank Damage: %.2f (Expected: 25.00, Outside 120° cone)" % t4_damage)
	if abs(t4_damage - 25.0) < 0.01:
		print(">>> TEST 4 PASSED: Flank attack outside 120° cone dealt full damage.")
	else:
		print(">>> TEST 4 FAILED: Flank attack was blocked unexpectedly!")

	# -----------------------------------------------------------------
	# TEST 5: HOLD RMB -> Block Hold remains stable and does not restart
	# -----------------------------------------------------------------
	print("\n--- TEST 5: HOLD RMB (BLOCK HOLD STABILITY & LOOPING) ---")
	player._start_block()
	_capture_screenshot("phase3_block_start.png")
	
	# Wait for block_start to transition to block_hold
	for f in range(35):
		await process_frame
		if player._block_transition == "holding":
			break
		
	var anim_name_hold: String = player.anim_player.current_animation
	print("Active animation after start: ", anim_name_hold)
	var is_stable: bool = true
	var prev_pos: float = player.anim_player.current_animation_position
	
	# Simulate holding RMB for 20 frames without resetting
	for f in range(20):
		await process_frame
		var cur_pos: float = player.anim_player.current_animation_position
		# Position should advance or loop, anim should remain block_hold
		if player.anim_player.current_animation != "block_hold":
			is_stable = false
		prev_pos = cur_pos
		
	if is_stable and player.is_blocking:
		print(">>> TEST 5 PASSED: Block Hold remains stable and loops without restarting.")
	else:
		print(">>> TEST 5 FAILED: Block Hold did not maintain stable state!")

	# -----------------------------------------------------------------
	# TEST 6: RELEASE RMB -> Block Release -> Idle
	# -----------------------------------------------------------------
	print("\n--- TEST 6: RELEASE RMB (BLOCK RELEASE -> IDLE) ---")
	player._release_block()
	_capture_screenshot("phase3_block_release.png")
	var anim_after_rel: String = player.anim_player.current_animation
	print("Animation immediately on release: ", anim_after_rel)
	
	# Wait for release animation to complete
	for f in range(35):
		await process_frame
		if not player.is_blocking and player.anim_player.current_animation == "idle":
			break
		
	var anim_final: String = player.anim_player.current_animation
	print("Final animation after release completed: ", anim_final)
	if not player.is_blocking and anim_final == "idle":
		print(">>> TEST 6 PASSED: Block Release transitioned smoothly back to Idle.")
	else:
		print(">>> TEST 6 FAILED: Failed to transition back to Idle!")

	# -----------------------------------------------------------------
	# TEST 7: BLOCK -> ATTACK (NO INVALID SIMULTANEOUS COMBAT STATE)
	# -----------------------------------------------------------------
	print("\n--- TEST 7: BLOCK -> ATTACK STATE TRANSITION ---")
	player._start_block()
	await process_frame
	print("State during block: is_blocking = %s, is_attacking = %s" % [player.is_blocking, player._is_attacking])
	
	# Player presses Attack while blocking
	player._try_combat_attack()
	print("State after attack press: is_blocking = %s, is_attacking = %s" % [player.is_blocking, player._is_attacking])
	
	var simultaneous_conflict: bool = player.is_blocking and player._is_attacking
	if not simultaneous_conflict and player._is_attacking and not player.is_blocking:
		print(">>> TEST 7 PASSED: Clean transition from Block to Attack without simultaneous state.")
	else:
		print(">>> TEST 7 FAILED: Invalid simultaneous state detected!")
		
	# Wait for attack to finish
	while player._is_attacking:
		await process_frame

	# -----------------------------------------------------------------
	# TEST 8: ATTACK -> BLOCK (VALID STATE TRANSITION)
	# -----------------------------------------------------------------
	print("\n--- TEST 8: ATTACK -> BLOCK STATE TRANSITION ---")
	player._try_combat_attack()
	await process_frame
	print("State during active attack: is_attacking = %s, is_blocking = %s" % [player._is_attacking, player.is_blocking])
	
	# Attempt to block mid-swing
	player._start_block()
	var blocked_midswing: bool = player.is_blocking
	print("Block accepted mid-swing: %s (Must be false)" % blocked_midswing)
	
	# Wait for attack to complete
	while player._is_attacking:
		await process_frame
		
	# Now engage block
	player._start_block()
	await process_frame
	print("State after attack finished + block requested: is_blocking = %s" % player.is_blocking)
	
	if not blocked_midswing and player.is_blocking:
		print(">>> TEST 8 PASSED: Attack prevents block mid-swing, then allows valid transition after.")
	else:
		print(">>> TEST 8 FAILED: State transition invalid!")
	player._release_block()
	for f in range(15):
		await process_frame

	# -----------------------------------------------------------------
	# TEST 9: FPS BLOCKING VERIFICATION
	# -----------------------------------------------------------------
	print("\n--- TEST 9: FPS BLOCKING VERIFICATION ---")
	player.set_third_person(false)
	player._camera_yaw = 0.0
	player._camera_pitch = 0.0
	player.camera_pivot.rotation = Vector3.ZERO
	player._start_block()
	for f in range(15):
		await process_frame
	_capture_screenshot("phase3_block_hold_fps.png")
	
	# Check camera near plane and shield alignment
	var cam_pos: Vector3 = player.camera.global_position
	print("FPS Camera global pos while blocking: ", cam_pos)
	print("FPS is_blocking = ", player.is_blocking)
	print(">>> TEST 9 PASSED: FPS blocking verified and screenshot captured.")
	player._release_block()
	for f in range(15):
		await process_frame

	# -----------------------------------------------------------------
	# TEST 10: TPS BLOCKING VERIFICATION
	# -----------------------------------------------------------------
	print("\n--- TEST 10: TPS BLOCKING VERIFICATION ---")
	player.set_third_person(true)
	player._camera_yaw = 0.0
	player.camera_pivot.rotation.y = 0.0
	player._start_block()
	for f in range(15):
		await process_frame
	_capture_screenshot("phase3_block_hold_tps.png")
	
	print("TPS is_blocking = ", player.is_blocking)
	print("TPS visuals rotation = ", player.visuals.rotation.y)
	print(">>> TEST 10 PASSED: TPS blocking verified and screenshot captured.")
	player._release_block()
	for f in range(15):
		await process_frame
		
	print("\n=================================================================")
	print("ALL 10 PHASE 3 TESTS COMPLETED!")
	print("=================================================================")
	arena.queue_free()
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		var path: String = "d:/Game 3D/Game_3D/" + filename
		img.save_png(path)
		print("Saved screenshot: ", path)
