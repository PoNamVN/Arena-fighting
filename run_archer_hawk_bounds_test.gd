extends "res://run_archer_volley_test.gd"

func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await frames(3)
	var bounds: Node3D = arena.get_node("ArenaPlayBounds")
	var profile := "knight" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
	assert(profile in ["knight", "archer", "wizard"])
	for side in range(bounds._normals.size()):
		var bow := await fresh_volley()
		if profile != "knight":
			enemy.queue_free()
			await frames(2)
			enemy = load("res://scenes/Player.tscn").instantiate() as PlayerController
			enemy.hero_profile = profile
			enemy.external_controlled = true
			enemy.collision_layer = 4
			enemy.collision_mask = 3
			enemy.get_node("HealthComponent").max_health = 500
			arena.add_child(enemy)
			await frames(5)
		var normal: Vector3 = bounds._normals[side]
		enemy.position = normal * (bounds._limits[side] - 1.0) + Vector3.UP * .1
		player.position = enemy.position - normal * 6.0
		var offset := enemy.position - player.position
		player._camera_yaw = atan2(-offset.x, -offset.z)
		player.camera_pivot.rotation.y = player._camera_yaw
		await frames(3)
		# Isolate capture movement from pillars obstructing the projectile near some walls.
		bow.hawk_skill.target = enemy
		bow.hawk_skill.projectile = Node3D.new()
		player.add_child(bow.hawk_skill.projectile)
		bow.hawk_skill._trail = bow.hawk_skill._new_trail(bow.hawk_skill.projectile)
		bow.hawk_skill._impact(enemy, player.global_position + Vector3.UP, enemy.global_position)
		check(bow.hawk_skill.grabs == 1, "Z captures beside arena wall %d" % side)
		var proxy_outside := 0.0
		var bones_outside := 0.0
		var escaped_phases: Dictionary = {}
		for tick in range(660):
			await frames(1)
			var positions: Array[Vector3] = [enemy.global_position]
			if enemy.is_ragdoll_active() and enemy.ragdoll.simulator.is_simulating_physics():
				for bone: PhysicalBone3D in enemy.ragdoll.physical_bones.values():
					positions.append(bone.global_position)
			for point in range(positions.size()):
				var local := arena.to_local(positions[point])
				for plane in range(bounds._normals.size()):
					var excess: float = local.dot(bounds._normals[plane]) - bounds._limits[plane]
					if point == 0: proxy_outside = maxf(proxy_outside, excess)
					else: bones_outside = maxf(bones_outside, excess)
					if excess > .02: escaped_phases[enemy.hawk_carry.phase] = true
		print(profile + " wall %d: proxy excess=%.3f, bone excess=%.3f, phases=%s" % [side, proxy_outside, bones_outside, escaped_phases])
		check(proxy_outside < .02, "Player collider stays inside wall %d" % side)
		check(bones_outside < .02, "Physical victim stays inside wall %d through carry, fall and recovery" % side)
		check(bow.hawk_skill.grabs == 1 and bow.hawk_skill.landings == 1 and not enemy.hawk_carry.active() and not enemy.is_ragdoll_active(), "Wall %d capture lands and finishes get-up" % side)
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
