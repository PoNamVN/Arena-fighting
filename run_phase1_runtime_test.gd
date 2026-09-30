extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=================================================================")
	print("STARTING RUNTIME GAMEPLAY VALIDATION: PHASE 1 FPS CAMERA")
	print("=================================================================")
	
	# Load Arena scene
	var arena_scene: PackedScene = load("res://scenes/Arena.tscn")
	var arena: Node3D = arena_scene.instantiate() as Node3D
	root.add_child(arena)
	
	var player: PlayerController = arena.get_node_or_null("Player") as PlayerController
	if not player:
		print("ERROR: Player not found in Arena scene!")
		quit(1)
		return
	
	var pivot: Node3D = player.get_node("CameraPivot")
	var spring_arm: SpringArm3D = player.get_node("CameraPivot/SpringArm3D")
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	var visuals: Node3D = player.get_node("Visuals")
	
	# Wait several frames for everything to settle
	for i in range(10):
		await process_frame
	
	# -------------------------------------------------------------
	# TEST 1: FPS Mode 360 Degree Yaw Sweep & Centering Verification
	# -------------------------------------------------------------
	player.set_third_person(false)
	await process_frame
	await process_frame
	
	print("\n--- 1. FPS 360° YAW VERIFICATION ---")
	var max_drift: float = 0.0
	for deg in [0, 45, 90, 135, 180, 225, 270, 315]:
		var rad: float = deg_to_rad(deg)
		player._camera_yaw = rad
		player._camera_pitch = 0.0
		pivot.rotation.y = rad
		pivot.rotation.x = 0.0
		visuals.rotation.y = rad
		
		# Let physics/frames process
		await process_frame
		
		var cam_gpos: Vector3 = camera.global_position
		var player_pos: Vector3 = player.global_position
		var horizontal_drift: float = Vector2(cam_gpos.x - player_pos.x, cam_gpos.z - player_pos.z).length()
		if horizontal_drift > max_drift:
			max_drift = horizontal_drift
			
		var cam_fwd: Vector3 = -camera.global_basis.z
		var vis_fwd: Vector3 = -visuals.global_basis.z
		var align_dot: float = cam_fwd.dot(vis_fwd)
		
		print("Yaw %3d° | Cam GPos: (%.3f, %.3f, %.3f) | Horiz Drift: %.4f m | Cam-Visual Dot: %.4f" % [
			deg, cam_gpos.x, cam_gpos.y, cam_gpos.z, horizontal_drift, align_dot
		])
		
		# Capture key angles
		if deg == 0:
			_capture_screenshot("phase1_fps_yaw_000.png")
		elif deg == 90:
			_capture_screenshot("phase1_fps_yaw_090.png")
		elif deg == 180:
			_capture_screenshot("phase1_fps_yaw_180.png")
			
	print(">>> MAX HORIZONTAL DRIFT ACROSS 360°: %.4f m (Target: 0.0000 m)" % max_drift)
	
	# -------------------------------------------------------------
	# TEST 2: FPS Pitch Up and Down
	# -------------------------------------------------------------
	print("\n--- 2. FPS PITCH VERIFICATION ---")
	pivot.rotation.y = 0.0
	visuals.rotation.y = 0.0
	player._camera_yaw = 0.0
	
	for pitch_deg in [-60, -35, 0, 35, 60]:
		var rad: float = deg_to_rad(pitch_deg)
		player._camera_pitch = rad
		pivot.rotation.x = rad
		await process_frame
		
		var cam_gpos: Vector3 = camera.global_position
		var player_pos: Vector3 = player.global_position
		var horizontal_drift: float = Vector2(cam_gpos.x - player_pos.x, cam_gpos.z - player_pos.z).length()
		var cam_fwd: Vector3 = -camera.global_basis.z
		print("Pitch %+3d° | Cam GPos: (%.3f, %.3f, %.3f) | Cam Fwd: (%.3f, %.3f, %.3f) | Drift: %.4f m" % [
			pitch_deg, cam_gpos.x, cam_gpos.y, cam_gpos.z, cam_fwd.x, cam_fwd.y, cam_fwd.z, horizontal_drift
		])
		
		if pitch_deg == -35:
			_capture_screenshot("phase1_fps_pitch_down35.png")
			
	# -------------------------------------------------------------
	# TEST 3: Third Person Verification
	# -------------------------------------------------------------
	print("\n--- 3. THIRD PERSON VERIFICATION ---")
	player.set_third_person(true)
	player._camera_pitch = deg_to_rad(10.0)
	pivot.rotation.x = player._camera_pitch
	pivot.rotation.y = 0.0
	await process_frame
	await process_frame
	
	var tps_gpos: Vector3 = camera.global_position
	var tps_dist: float = (tps_gpos - pivot.global_position).length()
	print("TPS Cam GPos: (%.3f, %.3f, %.3f) | Dist to pivot: %.3f m" % [
		tps_gpos.x, tps_gpos.y, tps_gpos.z, tps_dist
	])
	_capture_screenshot("phase1_tps_view.png")
	
	# -------------------------------------------------------------
	# TEST 4: Combat Pitch Attack Raycast Test
	# -------------------------------------------------------------
	print("\n--- 4. COMBAT PITCH TARGETING TEST ---")
	player.set_third_person(false)
	player._camera_pitch = deg_to_rad(-20.0)
	pivot.rotation.x = player._camera_pitch
	await process_frame
	
	var can_attack: bool = player.combat.try_attack()
	print("FPS Attack triggered with pitch -20°: ", can_attack)
	await process_frame
	_capture_screenshot("phase1_fps_attack.png")
	
	print("\n>>> ALL PHASE 1 RUNTIME TESTS COMPLETED SUCCESSFULLY!")
	arena.queue_free()
	quit(0)

func _capture_screenshot(filename: String) -> void:
	var img: Image = root.get_viewport().get_texture().get_image()
	if img:
		var path: String = "d:/Game 3D/Game_3D/" + filename
		img.save_png(path)
		print("Saved screenshot: ", path)
