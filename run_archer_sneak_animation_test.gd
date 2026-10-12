extends "res://run_archer_forest_escape_test.gd"

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var bow := await fresh_volley()
	enemy.global_position = Vector3(-12, .1, -12)
	player.set_third_person(true)
	player.external_controlled = true
	bow.start_escape()
	await frames(45)
	var skeleton := player._skeleton
	var forest: Node3D = bow.forest_escape
	for side: String in ["L", "R"]:
		var leg := player.visuals.find_child("Leg_" + side, true, false) as MeshInstance3D
		var arrays := leg.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var valid_winding := true
		for triangle in range(0, indices.size(), 3):
			var a := indices[triangle]
			var b := indices[triangle + 1]
			var c := indices[triangle + 2]
			valid_winding = valid_winding and (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).dot(normals[a]) < 0
		check(leg.has_meta("forest_leg_skin_fixed") and vertices.size() == 48 and valid_winding, "Leg " + side + " has knee subdivisions and outward clockwise faces")
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		check(weights.has(0.0) and weights.has(1.0), "Leg " + side + " uses anatomical thigh/shin weights instead of a rigid uniform blend")
		var original := leg.mesh.surface_get_material(0) as StandardMaterial3D
		check(original.albedo_color.r < .31 and original.albedo_color.b < .13, "Leg " + side + " retains the original brown pants material")
	var lowest := 100.0
	var planted_error := 0.0
	var lift := 0.0
	var neck_error := 0.0
	var bow_behind := -1.0
	var scout_ahead := 1.0
	var lean := 0.0
	var walk := player.anim_player.get_animation("forest_sneak_walk")
	var idle := player.anim_player.get_animation("forest_sneak_idle")
	var roll := player.anim_player.get_animation("forest_roll")
	var joints_match := true
	var loop_continuous := true
	for track in range(idle.get_track_count()):
		var type := idle.track_get_type(track)
		var path := idle.track_get_path(track)
		var roll_track := roll.find_track(path, type)
		if type == Animation.TYPE_ROTATION_3D:
			joints_match = joints_match and roll.rotation_track_interpolate(roll_track, roll.length).angle_to(idle.rotation_track_interpolate(track, 0)) < .001
			var walk_track := walk.find_track(path, type)
			loop_continuous = loop_continuous and walk.rotation_track_interpolate(walk_track, 0).angle_to(walk.rotation_track_interpolate(walk_track, walk.length)) < .001
		elif type == Animation.TYPE_POSITION_3D:
			joints_match = joints_match and roll.position_track_interpolate(roll_track, roll.length).distance_to(idle.position_track_interpolate(track, 0)) < .001
	check(joints_match, "Roll ends in the exact hunter ready pose without a hip or joint snap")
	check(loop_continuous, "Entire stalking gait closes without a joint discontinuity at the loop")
	var knee_bend := 0.0
	var max_joint_step := 0.0
	player.anim_player.play("forest_sneak_walk")
	for frame in range(65):
		var t := float(frame) / 64
		player.anim_player.seek(t * walk.length, true)
		player.anim_player.advance(0)
		skeleton.force_update_all_bone_transforms()
		for side: String in ["L", "R"]:
			var foot := skeleton.get_bone_global_pose(skeleton.find_bone("foot." + side))
			lowest = minf(lowest, foot.origin.y)
			lift = maxf(lift, foot.origin.y)
			var phase := fposmod(t + (0.0 if side == "L" else .5), 1.0)
			if phase < forest.SneakAnimations.STANCE: planted_error = maxf(planted_error, absf(foot.origin.y - .12))
			var thigh := skeleton.get_bone_global_pose(skeleton.find_bone("thigh." + side))
			var shin := skeleton.get_bone_global_pose(skeleton.find_bone("shin." + side))
			knee_bend = maxf(knee_bend, (shin.origin - thigh.origin).normalized().angle_to((foot.origin - shin.origin).normalized()))
		for track in range(walk.get_track_count()):
			if frame > 0 and walk.track_get_type(track) == Animation.TYPE_ROTATION_3D:
				max_joint_step = maxf(max_joint_step, walk.rotation_track_interpolate(track, walk.length * (frame - 1) / 64.0).angle_to(walk.rotation_track_interpolate(track, walk.length * t)))
		var head := skeleton.get_bone_global_pose(skeleton.find_bone("head"))
		neck_error = maxf(neck_error, absf(head.basis.z.normalized().y))
		var left_hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.L"))
		var right_hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand.R"))
		var hips := skeleton.get_bone_global_pose(skeleton.find_bone("hips")).origin
		bow_behind = maxf(bow_behind, left_hand.origin.z - hips.z)
		scout_ahead = minf(scout_ahead, right_hand.origin.z - hips.z)
		lean = maxf(lean, absf(skeleton.get_bone_global_pose(skeleton.find_bone("chest")).basis.z.normalized().y))
	check(lowest > .11, "Neither ankle sinks into the ground across the complete gait")
	check(planted_error < .005, "Support foot stays at the rest ankle height during every contact phase")
	check(lift > .165 and lift < .175, "Stalking step clears the ground with a quiet five-centimeter lift")
	check(neck_error < .12, "Head looks forward instead of inheriting the entire crouched torso tilt")
	check(knee_bend < deg_to_rad(95), "Stalking uses a half-crouch without folding knees into a deep squat")
	check(max_joint_step < .15, "All gait joints progress smoothly without abrupt rotation spikes")
	check(bow_behind < -.18, "Bow hand remains behind the hip throughout the stalking cycle")
	check(scout_ahead > .50, "Free hand reaches ahead independently like a predator scouting its path")
	check(lean > .5, "Hunter visibly leans into the approach while the head stays level")
	player.anim_player.play("forest_sneak_idle", .16)
	await frames(20)
	player.external_move_direction = Vector3.FORWARD * .25
	await frames(60)
	var slow := player.anim_player.speed_scale
	check(player.anim_player.current_animation == "forest_sneak_walk", "Slow movement uses the new crouched gait")
	player.external_move_direction = Vector3.FORWARD
	await frames(60)
	check(player.anim_player.speed_scale > slow + .3 and absf(player.anim_player.speed_scale - minf(forest.SneakAnimations.MAX_RATE, player.velocity.length() / forest.SneakAnimations.NOMINAL_SPEED)) < .15, "Stalking cadence follows speed with a ceiling that prevents frantic cycling")
	player.external_move_direction = Vector3.RIGHT
	await frames(30)
	forest._process(0) # Inspect the final pose stage, after camera-facing physics updates.
	check((-player.visuals.global_basis.z).dot(Vector3.RIGHT) > .98, "Smoothed turn reaches the movement direction despite camera-facing locomotion updates")
	player.external_move_direction = Vector3.ZERO
	await frames(60)
	check(player.anim_player.current_animation == "forest_sneak_idle", "Stopping blends into a stable low idle")
	check(bow.start_charge(), "Crouched hunter can enter the existing bow aim")
	await frames(25)
	check(not player.anim_player.current_animation.begins_with("forest_") and skeleton.get_bone_pose_position(skeleton.find_bone("hips")).y > .9, "Aim restores standing lower body instead of keeping a residual crouch")
	bow.cancel_charge()
	await frames(25)
	check(player.anim_player.current_animation == "forest_sneak_idle", "Leaving aim resumes the sneak posture while still hidden")
	player.apply_hit_reaction(Vector3.FORWARD)
	await frames(2)
	check(not player.anim_player.current_animation.begins_with("forest_"), "Hit reaction owns the skeleton during stun")
	await frames(70)
	check(bow.is_hidden() and player.anim_player.current_animation == "forest_sneak_idle", "Sneak resumes smoothly after hit stun")
	bow.end_stealth()
	await frames(30)
	check(player.anim_player.current_animation == "idle" and skeleton.get_bone_pose_position(skeleton.find_bone("hips")).y > .9, "Stealth expiry restores ordinary idle and hip height")
	var rest_head: Quaternion = forest._rest_rotations.head
	check(skeleton.get_bone_pose_rotation(skeleton.find_bone("head")).angle_to(rest_head) < .04, "Extra head and ankle tracks do not leak into normal locomotion")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
