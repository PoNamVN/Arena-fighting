extends "res://run_archer_forest_escape_test.gd"

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	showcase = Camera3D.new()
	arena.add_child(showcase)
	for direction: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3(1, 0, -1), Vector3(-1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		var bow := await fresh_volley()
		player.external_controlled = true
		player.external_move_direction = direction.normalized()
		var origin := player.global_position
		check(bow.start_escape(), "C accepts movement direction " + str(direction))
		await frames(15)
		check((-player.visuals.global_basis.z).dot(direction.normalized()) > .99, "Roll faces its actual movement, including diagonal and backward input")
		check((player.global_position - origin).normalized().dot(direction.normalized()) > .98, "Roll translation agrees with its facing")
		await frames(17)
		check(not bow.dash_active and player.anim_player.current_animation != "forest_roll", "One full turn completes without an extra roll")

	var bow := await fresh_volley()
	player.external_controlled = true
	player.external_move_direction = Vector3(1, 0, -1).normalized()
	bow.start_escape()
	await frames(32)
	var forest: Node3D = bow.forest_escape
	check(forest.grass.multimesh.mesh.get_aabb().size.y > 1.15, "Blender mesh has tall grass geometry")
	check(forest.grass.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 420, "Folded seven-leaf tuft stays within 140 triangles")
	check(forest.steps_spawned >= 8, "Grass fills the fast roll path without gaps")
	player.external_move_direction = Vector3.RIGHT
	await frames(55)
	var before: int = forest.steps_spawned
	check(before > 12 and forest.grass.multimesh.instance_count == 1536, "Continuous trail uses bounded pooled grass")
	check((forest._material.get_shader_parameter("hunter_position") as Vector3).distance_to(player.global_position) < .15, "Parting shader tracks the hunter within one physics tick")
	check((forest._material.get_shader_parameter("travel_direction") as Vector3).dot(Vector3.RIGHT) > .99, "Parting corridor follows forward travel")
	await snapshot("tall_forward")
	player.external_move_direction = Vector3.LEFT
	await frames(55)
	check((forest._material.get_shader_parameter("travel_direction") as Vector3).dot(Vector3.LEFT) > .99, "Returning through the trail reverses the parting direction")
	var nearby := false
	var stale := false
	for index in range(forest._tufts.size()):
		if forest._tuft_growth[index] <= .01: continue
		var point: Vector3 = forest._tufts[index].origin
		var distance := Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length()
		nearby = nearby or distance < forest.REGION_RADIUS
		stale = stale or distance > forest.REGION_RADIUS + 2.2
	check(nearby and stale, "Returning opens local grass while the older trail remains")
	await snapshot("tall_reverse")
	player.external_move_direction = Vector3.ZERO
	await frames(510)
	check(not bow.is_hidden() and not player.ability_system.is_on_cooldown("skill_3"), "Moving and revisiting never refresh the finite stealth cooldown")
	check(not player.anim_player.current_animation.begins_with("forest_"), "Expiry restores standard locomotion")
	check(forest.grass.visible, "Grass remains after stealth ends without refreshing stealth")
	await frames(360)
	check(not forest.grass.visible and not bow.is_hidden(), "All tall grass disappears after stealth expiry")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
