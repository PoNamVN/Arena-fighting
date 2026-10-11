extends "res://run_archer_volley_test.gd"

func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	for delay: int in [0, 60, 180]:
		var bow := await fresh_volley()
		check(bow.start_hawk(), "Z starts for aerial X fixture")
		for tick in range(180):
			await frames(1)
			if enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY: break
		await frames(delay)
		player._camera_yaw = PI
		player.camera_pivot.rotation.y = PI
		check(bow.start_seeking() and bow.seeking_target == enemy, "X locks Z's carried enemy outside the ordinary aim cone")
		await frames(100)
		check(bow.seeking_shots == 3, "Aerial X emits all three arrows")
		check(is_equal_approx(enemy.health_component.current_health, 496), "X does not damage the victim while the hawk holds it")
		check(enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY and bow._arrows.size() == 3, "All three arrows keep chasing until release")
		var hawk_speed := TAU * enemy.hawk_carry.orbit_radius * HawkCarryEffect.ORBIT_SPEED_MULTIPLIER / HawkCarryEffect.CIRCLE_SECONDS
		var slower := true
		for arrow: Dictionary in bow._arrows:
			slower = slower and is_equal_approx(arrow.speed, hawk_speed * .9)
		check(slower, "Chasing arrows fly ten percent slower than the hawk")
		var fall_arrow_hits := 0
		var previous_hp := enemy.health_component.current_health
		for tick in range(600):
			await frames(1)
			var hp := enemy.health_component.current_health
			if hp < previous_hp and enemy.hawk_carry.phase == HawkCarryEffect.Phase.FALL:
				fall_arrow_hits += roundi((previous_hp - hp) / 14.0)
			previous_hp = hp
		check(fall_arrow_hits == 3, "All three arrows hit during the fall before ground impact")
		check(is_equal_approx(enemy.health_component.current_health, 434) and bow.hawk_skill.landings == 1, "Z and X damage resolves once with normal landing")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
