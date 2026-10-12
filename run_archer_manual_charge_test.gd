extends "res://run_archer_volley_test.gd"

func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	for fps: bool in [false, true]:
		var previous_damage := 0.0
		for hold: int in [1, 36, 75]:
			var bow := await fresh_volley()
			player.set_third_person(not fps)
			var original_pitch := player._camera_pitch
			var original_yaw := player._camera_yaw
			action("attack", true)
			await frames(hold)
			check(bow.charging and bow.sky_aiming and bow.locked_target == null, "LMB holds manual aim without auto targeting")
			check(bow.reticle_hud.visible and bow.shots_fired == 0, "Shared Z reticle appears; holding never auto fires")
			check(is_equal_approx(player._camera_yaw, original_yaw) and is_equal_approx(player._camera_pitch, original_pitch), "Charging never steers the camera to an enemy")
			if not fps:
				check(is_equal_approx(player.spring_arm.spring_length, 1.8) and player.camera_pivot.position.x > .8, "Uses Z's same shoulder camera")
			player.camera.look_at(enemy.global_position + Vector3.UP * .9)
			var manual_direction := bow._manual_aim_direction()
			action("attack", false)
			await frames(1)
			check(bow.shots_fired == 1 and bow._arrows.size() == 1, "Releasing emits exactly one physical arrow")
			if not bow._arrows.is_empty():
				check(bow._arrows[0].direction.is_equal_approx(manual_direction) and bow._arrows[0].homing == null, "Arrow follows the reticle direction without homing")
			await frames(40)
			var damage := 500.0 - enemy.health_component.current_health
			check(damage > previous_damage, "Longer charge increases actual hit damage")
			previous_damage = damage
			check(not bow.sky_aiming and is_equal_approx(player._camera_pitch, original_pitch), "Release restores the normal camera")
		var bow := await fresh_volley()
		player.set_third_person(not fps)
		action("attack", true)
		await frames(90)
		player.camera.look_at(player.camera.global_position + Vector3.RIGHT * 20)
		action("attack", false)
		await frames(100)
		check(enemy.health_component.current_health == 500 and bow.hits_landed == 0, "Aiming away misses instead of snapping to a nearby enemy")
		check(bow._arrows.is_empty(), "Missed arrows expire")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
