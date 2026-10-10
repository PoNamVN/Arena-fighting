extends SceneTree

func _init() -> void:
	print("=== RUNNING FIRST PERSON CAMERA & SIDE DASH VERIFICATION ===")
	var arena: Node3D = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)

	var player: PlayerController = load("res://scenes/Player.tscn").instantiate() as PlayerController
	player.hero_profile = "archer"
	player.position = Vector3(0, 0.1, 0)
	arena.add_child(player)

	for i in range(15):
		await process_frame

	# -------------------------------------------------------------------
	# TEST 1: First Person Eye Tracking and Somersault Flip
	# -------------------------------------------------------------------
	print("\n--- TEST 1: First Person Camera ---")
	player.set_third_person(false)
	await process_frame

	# Verify camera pivot is at eye height (~1.52m), not 0 or ground
	var pivot_y: float = player.camera_pivot.global_position.y
	print("1st-Person Initial Camera Pivot Y: %.2f" % pivot_y)
	assert(pivot_y > 1.3 and pivot_y < 1.7, "Camera pivot must track head eye position!")
	print("[PASS] Camera pivot accurately positioned at character eye height")

	# Trigger Archer backflip (S+Q)
	player.external_controlled = true
	player.external_move_direction = Vector3(0, 0, 1) # back
	player.dodge_controller._cooldown_timer = 0.0
	player._try_dodge()
	assert(player.combat_state == PlayerController.CombatState.DODGE, "Should enter DODGE")
	assert(player.anim_player.current_animation == "dash_back", "Should play dash_back")

	var inverted_detected: bool = false
	var peak_y: float = 0.0
	var min_basis_y_y: float = 1.0

	# Process frames through backflip duration (0.60s ≈ 65 frames)
	for f in range(65):
		await process_frame
		var cur_basis_y: Vector3 = player.camera_pivot.global_transform.basis.y
		var cur_pos_y: float = player.camera_pivot.global_position.y
		peak_y = maxf(peak_y, cur_pos_y)
		min_basis_y_y = minf(min_basis_y_y, cur_basis_y.y)
		if cur_basis_y.y < -0.2:
			inverted_detected = true

	print("Backflip Apex Camera Pivot Y peak: %.2f" % peak_y)
	print("Backflip Minimum basis.y.y: %.2f" % min_basis_y_y)
	print("Inverted orientation detected during flip: %s" % inverted_detected)
	assert(inverted_detected, "Camera should somersault/invert with the character during backflip!")
	print("[PASS] Camera somersaults inverted with character during backflip")

	# Wait until dodge finishes
	while player.dodge_controller.is_dodging:
		await process_frame
	for f in range(15):
		await process_frame

	var final_basis_y: Vector3 = player.camera_pivot.global_transform.basis.y
	print("Final Camera Pivot Y vector: %s" % final_basis_y)
	assert(final_basis_y.y > 0.85, "Camera must return upright after backflip lands!")
	print("[PASS] Camera returns to upright forward aim after landing backflip")

	# -------------------------------------------------------------------
	# TEST 2: Archer Shoot -> Left/Right Side Dash
	# -------------------------------------------------------------------
	print("\n--- TEST 2: Shoot -> Side Dash Facing Direction ---")
	player.set_third_person(true)
	await process_frame

	# Simulate shooting bow
	Input.action_press("attack")
	for f in range(10): await process_frame
	Input.action_release("attack")
	for f in range(10): await process_frame
	print("Player shot bow, now initiating lateral dodge")

	var initial_yaw: float = player._camera_yaw

	# Dash Left (A+Q)
	player.external_controlled = true
	player.external_move_direction = Vector3(-1, 0, 0)
	player.dodge_controller._cooldown_timer = 0.0
	player._try_dodge()
	assert(player.combat_state == PlayerController.CombatState.DODGE, "Should enter DODGE")
	assert(player.anim_player.current_animation == "dash_left", "Should play dash_left clip")

	for f in range(10):
		await process_frame
		var vis_yaw: float = player.visuals.rotation.y
		assert(absf(angle_difference(vis_yaw, initial_yaw)) < 0.05, "Archer visuals must stay facing camera yaw, NOT rotate 90 deg sideways!")

	print("[PASS] Dash Left maintains forward combat facing (visuals.rotation.y == _camera_yaw)")

	# Wait for dodge to finish
	while player.dodge_controller.is_dodging:
		await process_frame
	for f in range(10):
		await process_frame

	# Shoot again before dash right
	Input.action_press("attack")
	for f in range(10): await process_frame
	Input.action_release("attack")
	for f in range(10): await process_frame

	# Dash Right (D+Q)
	player.external_controlled = true
	player.external_move_direction = Vector3(1, 0, 0)
	player.dodge_controller._cooldown_timer = 0.0
	player._try_dodge()
	assert(player.combat_state == PlayerController.CombatState.DODGE, "Should enter DODGE")
	assert(player.anim_player.current_animation == "dash_right", "Should play dash_right clip")

	for f in range(10):
		await process_frame
		var vis_yaw: float = player.visuals.rotation.y
		assert(absf(angle_difference(vis_yaw, initial_yaw)) < 0.05, "Archer visuals must stay facing camera yaw, NOT rotate 90 deg sideways!")

	print("[PASS] Dash Right maintains forward combat facing (visuals.rotation.y == _camera_yaw)")

	print("\n=== ALL FIRST PERSON CAMERA & SIDE DASH TESTS PASSED! ===")
	quit(0)
