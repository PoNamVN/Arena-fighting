extends SceneTree

func _init() -> void:
	print("=== GODOT TEST SCENE: ATTACH NEW BOW ===")
	var char_path := "res://assets/models/m_archer_preview/forest_archer_v2.glb"
	var bow_path := "res://assets/models/m_archer_preview/hunter_bow_v2.glb"

	var gltf_char := GLTFDocument.new()
	var state_char := GLTFState.new()
	var err1 := gltf_char.append_from_file(ProjectSettings.globalize_path(char_path), state_char)
	if err1 != OK:
		print("Failed to load char: ", err1)
		quit(1)
		return
	var char_node := gltf_char.generate_scene(state_char)

	var gltf_bow := GLTFDocument.new()
	var state_bow := GLTFState.new()
	var err2 := gltf_bow.append_from_file(ProjectSettings.globalize_path(bow_path), state_bow)
	if err2 != OK:
		print("Failed to load bow: ", err2)
		quit(1)
		return
	var bow_node := gltf_bow.generate_scene(state_bow)

	var root := get_root()
	var world := Node3D.new()
	root.add_child(world)

	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.18, 0.20, 0.24)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.7, 0.72, 0.75)
	env.environment = env_res
	world.add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_energy = 1.0
	world.add_child(light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -135, 0)
	fill.light_energy = 0.5
	world.add_child(fill)

	# Container for character visuals
	var visuals := Node3D.new()
	world.add_child(visuals)
	visuals.add_child(char_node)
	visuals.add_child(bow_node)

	# Find Skeleton & AnimationPlayer
	var skeleton: Skeleton3D = null
	var anim_player: AnimationPlayer = null
	var stack: Array[Node] = [char_node]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is Skeleton3D and skeleton == null: skeleton = n
		if n is AnimationPlayer and anim_player == null: anim_player = n
		for c in n.get_children(): stack.push_back(c)

	print("Skeleton: ", skeleton.name if skeleton else "NONE")
	print("AnimPlayer: ", anim_player.name if anim_player else "NONE")

	var cam := Camera3D.new()
	cam.position = Vector3(1.2, 1.2, 2.4)
	cam.look_at_from_position(cam.position, Vector3(0.1, 0.95, 0.0), Vector3.UP)
	cam.current = true
	world.add_child(cam)

	# --- 1. IDLE POSE ---
	if anim_player:
		anim_player.play("idle")
		anim_player.advance(0.5)

	# Standard ArcherCombat bow position when not aiming
	bow_node.position = Vector3(0.3, 0.9, 0)
	bow_node.rotation = Vector3.ZERO

	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw

	var img_idle = root.get_texture().get_image()
	if img_idle:
		img_idle.save_png("d:/Game 3D/Game_3D/scratch/archer_bow_godot_idle.png")
		print("Saved idle screenshot")

	# --- 2. RUN POSE ---
	if anim_player:
		anim_player.play("run")
		anim_player.advance(0.3)

	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw

	var img_run = root.get_texture().get_image()
	if img_run:
		img_run.save_png("d:/Game 3D/Game_3D/scratch/archer_bow_godot_run.png")
		print("Saved run screenshot")

	# --- 3. SHOT / AIMING POSE ---
	# ArcherCombat aiming pose:
	# _bow.position = Vector3(0.05, 1.35, -0.40)
	bow_node.position = Vector3(0.05, 1.35, -0.40)
	bow_node.rotation = Vector3.ZERO

	# Pose arms if skeleton is available
	if skeleton:
		var l_idx = skeleton.find_bone("hand.L")
		var r_idx = skeleton.find_bone("hand.R")
		var u_l = skeleton.find_bone("upper_arm.L")
		var f_l = skeleton.find_bone("forearm.L")
		var u_r = skeleton.find_bone("upper_arm.R")
		var f_r = skeleton.find_bone("forearm.R")
		print("Hand bones: hand.L=", l_idx, ", hand.R=", r_idx)
		# Set global pose override for aiming arm
		if l_idx >= 0:
			skeleton.set_bone_global_pose_override(l_idx, Transform3D(Basis(), Vector3(0.05, 1.35, -0.40)), 1.0, true)
		if r_idx >= 0:
			skeleton.set_bone_global_pose_override(r_idx, Transform3D(Basis(), Vector3(0.05, 1.35, -0.05)), 1.0, true)

	# Change camera to view shot pose clearly (front-quarter view of aiming)
	cam.position = Vector3(1.5, 1.4, -0.2)
	cam.look_at_from_position(cam.position, Vector3(0.05, 1.35, -0.3), Vector3.UP)

	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw

	var img_shot = root.get_texture().get_image()
	if img_shot:
		img_shot.save_png("d:/Game 3D/Game_3D/scratch/archer_bow_godot_shot.png")
		print("Saved shot screenshot")

	print("ALL GODOT BOW TESTS COMPLETED SUCCESSFULLY!")
	quit(0)
