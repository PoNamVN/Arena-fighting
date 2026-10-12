extends "res://run_archer_forest_escape_test.gd"

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	showcase = Camera3D.new()
	arena.add_child(showcase)
	var bow := await fresh_volley()
	player.external_controlled = true
	for cast in range(3 if "--visual" in OS.get_cmdline_user_args() else 8):
		player.global_position = Vector3(-8 + (cast % 4) * 4, .1, 3)
		player.external_move_direction = Vector3.ZERO
		player.stamina_component.current_stamina = 100
		await frames(5)
		check(bow.start_escape(), "Repeated C cast " + str(cast + 1))
		await frames(45)
		var live := 0
		for age: float in bow.forest_escape._ages:
			if age >= 0: live += 1
		check(bow.forest_escape.grass.visible and live > 0, "Repeated cast creates visible live grass")
		var start: Vector3 = player.global_position
		player.external_move_direction = Vector3.RIGHT
		await frames(60)
		player.external_move_direction = Vector3.ZERO
		await frames(30)
		var old_visible := false
		for index in range(bow.forest_escape._tufts.size()):
			var point: Vector3 = bow.forest_escape._tufts[index].origin
			if point.distance_to(start) < 1.2 and bow.forest_escape._tuft_growth[index] > .9: old_visible = true
		check(old_visible, "Grass around the old position remains after leaving the region")
		for press in range(8): check(not bow.start_escape(), "Spamming C on cooldown cannot reset the active grass")
		check(bow.is_hidden() and bow.forest_escape.grass.visible, "Rejected casts preserve active grass and stealth")
		if "--visual" in OS.get_cmdline_user_args() and cast < 3:
			await snapshot("recast_" + str(cast))
			var picture := root.get_texture().get_image()
			var green := 0
			for y in range(0, picture.get_height(), 4):
				for x in range(0, picture.get_width(), 4):
					var pixel := picture.get_pixel(x, y)
					if pixel.g > .15 and pixel.g > pixel.r * 1.5 and pixel.g > pixel.b * 1.5: green += 1
			check(green > 200, "Repeated cast draws actual green grass pixels")
		await frames(830)
		check(not bow.is_hidden() and not bow.forest_escape.grass.visible, "Cooldown expiry cleans up before the next cast")
	# Also cover interrupted and round-reset lifecycle on the same actor.
	bow.reset()
	player.ability_system.reset_cooldowns()
	player.stamina_component.current_stamina = 100
	check(bow.start_escape(), "C restarts after explicit combat reset")
	await frames(45)
	check(bow.forest_escape.grass.visible and bow.forest_escape._tuft_growth.max() > .9, "Reset recast grows full-height grass")
	bow.end_stealth()
	await frames(30)
	check(bow.forest_escape.grass.visible and not bow.is_hidden(), "Early reveal preserves grass without extending stealth")
	var original: Vector3 = bow.forest_escape._tufts[0].origin
	player.ability_system.reset_cooldowns()
	player.stamina_component.current_stamina = 100
	check(bow.start_escape(), "Training-style recast works while earlier grass is still alive")
	await frames(30)
	check(bow.forest_escape._tufts[0].origin == original and bow.forest_escape._tuft_growth[0] > .9, "Recasting preserves the earlier living trail")
	bow.end_stealth()
	await frames(360)
	check(not bow.forest_escape.grass.visible, "Lingering grass eventually fades after an early reveal")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
