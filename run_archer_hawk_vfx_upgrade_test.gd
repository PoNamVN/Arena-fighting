extends "res://run_archer_volley_test.gd"

func snapshot(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/HP VICTUS/.codex/worktrees/71f7/Game_3D/scratch/hawk_vfx_" + label + ".png")

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await root.get_node("VFXManager").warmup()
	var bow := await fresh_volley()
	var skill := bow.hawk_skill
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.make_current()
	check(bow.start_hawk(), "Z starts")
	for tick in range(180):
		await frames(1)
		if enemy.hawk_carry.phase == HawkCarryEffect.Phase.MARKED: break
	check(is_instance_valid(skill._fish_ring), "Capture creates the blue orbit outline")
	var fish_before := skill.projectile.global_position
	var alpha_before := skill._fish_ring_material.albedo_color.a
	await frames(10)
	check(skill.projectile.global_position.distance_to(fish_before) > .4, "Fish swims around the marked victim")
	check(absf(skill._fish_ring_material.albedo_color.a - alpha_before) > .05, "Blue outline blinks")
	check(not skill.hawk.visible, "Fish orbits before hawk descends")
	camera.global_position = enemy.global_position + Vector3(3, 2.4, 4)
	camera.look_at(enemy.global_position + Vector3.UP * 1.2)
	await snapshot("fish_orbit")
	for tick in range(120):
		await frames(1)
		if enemy.hawk_carry.phase == HawkCarryEffect.Phase.LIFT: break
	check(skill._dive_gust_spawned, "Dive spawns a ground wind burst")
	check(not skill._fish_ring.visible and not skill.projectile.visible, "Fish mark disappears when talons lift the victim")
	var ground_bursts := 0
	for entry: Dictionary in skill._effects:
		if is_instance_valid(entry.node) and entry.node.active and entry.node._context.get("ground", false):
			ground_bursts += 1
			check(entry.node.waves.size() == 2 and entry.node.dust.visible and entry.node.feathers.visible, "Ground burst has concentric wind rings, dust and sand")
	check(ground_bursts == 2, "Dive and lift each emit a ground burst")
	await frames(8)
	camera.global_position = enemy.global_position + Vector3(5, 3, 6)
	camera.look_at(enemy.global_position + Vector3.UP * 1.6)
	await snapshot("lift")
	for tick in range(120):
		await frames(1)
		if enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY: break
	await frames(12)
	check(skill._wing_trails.size() == 2 and skill._wing_trails[0].multimesh.visible_instance_count > 0, "Both moving wingtips leave wind trails")
	check((skill._wing_trails[0].multimesh.mesh as CylinderMesh).top_radius > .05, "Wind ribbons have visible width")
	camera.global_position = enemy.global_position + Vector3(6, 4, 8)
	camera.look_at(enemy.global_position + Vector3.UP * 2)
	await snapshot("wing_wind")
	for tick in range(650):
		await frames(1)
		if skill.landings > 0: break
	var landing_seen := false
	var landing_point := enemy.global_position
	for entry: Dictionary in skill._effects:
		if is_instance_valid(entry.node) and entry.node.active and is_equal_approx(float(entry.node._context.get("strength", 0)), .55):
			landing_seen = true
			landing_point = entry.node.global_position
	check(landing_seen, "Ground impact emits a small sand and dust burst")
	await frames(8)
	camera.global_position = landing_point + Vector3(0, 6, .5)
	camera.look_at(landing_point)
	await snapshot("landing_dust")
	await frames(90)
	check(not skill.active() and skill._fish_ring == null and skill._wing_trails.is_empty(), "Skill cleans up fish outline and wing trails")
	check(skill.landings == 1 and is_equal_approx(enemy.health_component.current_health, 476), "VFX retains one landing and original damage")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
