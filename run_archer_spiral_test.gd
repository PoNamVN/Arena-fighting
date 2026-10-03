extends "res://run_archer_volley_test.gd"
func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var bow: ArcherCombat = await fresh_volley()
	enemy.position.z = -17
	await frames(2)
	bow.start_seeking()
	await frames(35)
	check(bow._arrows.size() == 3, "Three spiral arrows launched together")
	if bow._arrows.size() == 3:
		var a: Dictionary = bow._arrows[0]
		var b: Dictionary = bow._arrows[1]
		var c: Dictionary = bow._arrows[2]
		check(a.guide.distance_to(b.guide) < 0.001 and a.guide.distance_to(c.guide) < 0.001, "Arrows share one tracking axis")
		var ra: Vector3 = a.node.global_position - a.guide
		var rb: Vector3 = b.node.global_position - b.guide
		check(absf(ra.length() - 0.95) < 0.02 and absf(rb.length() - 0.95) < 0.02, "Orbit expands to readable 0.95 meter radius")
		check(absf(rad_to_deg(ra.angle_to(rb)) - 120.0) < 0.1, "Arrows spaced 120 degrees apart")
		check(a.node.global_position.distance_to(b.node.global_position) > 1.5, "Orbiting arrows stay visibly separated")
		var old: Vector3 = ra
		await frames(5)
		var rotated: Vector3 = a.node.global_position - a.guide
		check(old.angle_to(rotated) > 0.5, "Physical arrow rotates around axis rather than flying straight")
		check(a.trail_segments.size() == 28, "Curved trail history bounded per arrow")
		await frames(32)
		if bow._arrows.size() == 3:
			check((a.node.global_position - a.guide).length() < 0.6, "Orbit tapers before converging on target")
		else:
			check(false, "Orbit still observable before contact")
	await frames(60)
	check(is_equal_approx(enemy.health_component.current_health, 458), "Converging spiral deals same 42 total damage")
	check(bow._arrows.is_empty(), "Impact removes arrows and their trail nodes")
	bow = await fresh_volley()
	bow.start_seeking()
	await frames(22)
	player.controls_enabled = false
	await frames(3)
	check(bow._arrows.is_empty(), "Round reset clears spiral and trails")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
