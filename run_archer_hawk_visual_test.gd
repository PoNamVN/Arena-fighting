extends "res://run_archer_volley_test.gd"

func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/hawk_" + name + ".png")

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var bow := await fresh_volley()
	var skill := bow.hawk_skill
	for warm_frame in range(600):
		if root.get_node("VFXManager").warmup_complete: break
		await frames(1)
	check(root.get_node("VFXManager").warmup_complete, "VFX pools warm up through the actual renderer")
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(8, 15, 6)
	camera.fov = 55
	camera.look_at(Vector3(0, 14, -5))
	camera.make_current()
	bow.start_hawk()
	var seen: Dictionary = {}
	for i in range(600):
		await frames(1)
		if skill.phase == ArcherHawkSkill.Phase.FLIGHT and not seen.has("fish"):
			seen.fish = true
			check(skill.projectile.find_child("FishBody*", true, false) != null, "Authored fish and clamp are imported")
			await snapshot("fish")
		if enemy.hawk_carry.active():
			var phase: int = enemy.hawk_carry.phase
			if not seen.has(phase):
				seen[phase] = true
				check(is_instance_valid(skill._animation), "Imported hawk has AnimationPlayer in phase %d" % phase)
				if phase == HawkCarryEffect.Phase.CARRY:
					var skeleton := skill._skeleton
					check(skeleton and skeleton.get_bone_count() == 25 and skeleton.find_bone("GrabSocket.L") >= 0 and skeleton.find_bone("GrabSocket.R") >= 0, "Hawk preserves twenty-three deform bones and two grab sockets")
					for clip: String in ["dive", "grab", "lift", "carry_flap", "release", "exit"]:
						check(skill._animation.has_animation(clip), "Imported animation " + clip)
					check(skill._animation.current_animation == "carry_flap", "Carry plays the looping wing animation")
					check(not skill._effects.is_empty(), "Capture emits pooled mark/wind effects")
					var wing_pose := skeleton.get_bone_pose_rotation(skeleton.find_bone("wing_upper.L"))
					await frames(12)
					check(wing_pose.angle_to(skeleton.get_bone_pose_rotation(skeleton.find_bone("wing_upper.L"))) > .1, "Wing rig visibly changes pose during its flap loop")
					await RenderingServer.frame_post_draw
					var left := skeleton.get_bone_global_pose(skeleton.find_bone("foot.L")).origin
					var right := skeleton.get_bone_global_pose(skeleton.find_bone("foot.R")).origin
					check(skeleton.to_global((left + right) * .5).distance_to(enemy.hawk_carry.grip_position()) < .12, "Animated talons stay aligned with victim ankles")
				await snapshot("phase_%d" % phase)
	check(skill.grabs == 1 and skill.landings == 1 and not skill.active(), "Visuals keep one capture and one landing")
	check(absf(enemy.health_component.current_health - 476) < .1, "Rendered sequence retains twenty-four damage")
	check(seen.has(HawkCarryEffect.Phase.CARRY) and seen.has(HawkCarryEffect.Phase.FALL), "Render sampled carry and release")
	root.get_node("VFXManager").enabled = false
	enemy.position = Vector3(0, .1, -5)
	player._camera_yaw = 0
	player.camera_pivot.rotation.y = 0
	await frames(2)
	player.ability_system.reset_cooldowns()
	player.stamina_component.current_stamina = 100
	bow.start_hawk()
	await frames(600)
	check(skill.grabs == 2 and skill.landings == 2, "Disabling decorative VFX preserves gameplay")
	check(not skill._effects.is_empty() or not skill.active(), "Essential warnings do not control capture timing")
	root.get_node("VFXManager").enabled = true
	root.get_node("VFXManager").set_quality(0)
	enemy.position = Vector3(0, .1, -5)
	player._camera_yaw = 0
	player.camera_pivot.rotation.y = 0
	await frames(2)
	player.ability_system.reset_cooldowns()
	player.stamina_component.current_stamina = 100
	player.set_third_person(true)
	player._camera_pitch = .4
	player.camera_pivot.rotation.x = .4
	player.camera.make_current()
	bow.start_hawk()
	await frames(150)
	check(player.camera.current and enemy.hawk_carry.active(), "Archer keeps its gameplay camera while the hawk carries")
	await snapshot("gameplay_tps")
	enemy.set_third_person(false)
	enemy.camera.make_current()
	await frames(5)
	check(enemy.camera.current and enemy.hawk_carry.active(), "Victim FPS camera follows its real carried collider")
	check(enemy.hawk_carry._body_masked and enemy.camera.cull_mask & HawkCarryEffect.CARRIED_BODY_LAYER == 0, "Victim FPS excludes its own carried body without hiding it from other cameras")
	check(skill.hawk.find_children("*", "GeometryInstance3D", true, false).all(func(mesh): return mesh.layers == HawkCarryEffect.CARRIED_BODY_LAYER), "Nearby hawk geometry uses the victim camera exclusion layer")
	check(enemy.hawk_carry.inversion > .99 and enemy.camera.global_basis.y.y < -.8, "Victim and FPS camera are upside down while held by the ankles")
	check(enemy.global_position.y > 13.5, "Hawk lifts the actual target fourteen metres")
	await snapshot("victim_fps")
	await frames(420)
	check(not enemy.hawk_carry.active() and enemy.camera_pivot.position.y == enemy.hawk_carry._camera_rest.y, "Victim camera offset restores after landing")
	check(not enemy.hawk_carry._body_masked and enemy.camera.cull_mask == enemy.hawk_carry._camera_cull_rest and enemy.camera.rotation.is_equal_approx(enemy.hawk_carry._camera_rotation_rest), "Victim render layers and cull mask restore after landing")
	check(skill.grabs == 3 and skill.landings == 3, "Low VFX quality preserves the complete third cast")
	check(skill.hawk == null and skill.projectile == null and skill._effects.is_empty(), "Repeated casts release owned geometry and effect leases")
	check(root.get_node("VFXManager").stats().active == 0, "Repeated casts return all decorative effects to their pools")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed == total else 1)
