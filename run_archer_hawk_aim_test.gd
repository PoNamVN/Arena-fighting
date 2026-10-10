extends "res://run_archer_volley_test.gd"

func snapshot(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("res://scratch/hawk_sky_aim_" + label + ".png")

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var bow := await fresh_volley()
	check(not bow.reticle_hud.visible, "Normal TPS hides the reticle")
	bow.start_charge()
	await frames(2)
	check(not bow.reticle_hud.visible, "Ordinary TPS charge also hides the reticle")
	bow.cancel_charge()
	check(bow.start_hawk(), "Z starts normally")
	for i in range(180):
		await frames(1)
		if enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY: break
	check(enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY, "Victim reaches the aerial shooting window")
	var initial_shots := bow.shots_fired
	var original_pitch := player._camera_pitch
	action("attack", true)
	await frames(75)
	check(player.camera_pivot.position.x > .8 and player.spring_arm.spring_length < 2, "TPS sky aim moves the camera to the right and closer")
	check(player.camera.global_position.y < player.global_position.y + 1.35 and -player.camera.global_basis.z.y > .65, "Right-side camera looks upward from below the bow")
	check(bow.reticle_hud != null and bow.reticle_hud.visible and bow.reticle_hud.size == Vector2(root.size), "Live sky reticle covers the viewport")
	await snapshot("tps")
	check(bow.charging and bow.sky_aiming and bow.locked_target == null, "Holding LMB charges without locking onto the carried victim")
	check(bow.shots_fired == initial_shots, "Holding never fires automatically")
	check(is_zero_approx(player._camera_yaw), "Carry never steers the player's camera")
	check(enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY, "Extended carry leaves time for a full charge")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, -2000)
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await frames(2)
	check(player._camera_pitch > deg_to_rad(80), "Manual sky aim allows nearly vertical mouse look")
	check(bow._bow.global_basis.z.y < -.8, "Bow and hands point upward with the aim")
	action("attack", false)
	await frames(70)
	check(player.camera_pivot.position.is_equal_approx(Vector3(0, 1.62, 0)) and is_equal_approx(player._camera_pitch, original_pitch), "Release restores the ordinary camera and pitch")
	check(not bow.reticle_hud.visible, "TPS hides the reticle after leaving sky aim")
	check(bow.shots_fired == initial_shots + 1 and bow.hits_landed == 0, "Releasing away from the victim misses without auto aim")
	check(is_equal_approx(enemy.health_component.current_health, 496), "Miss adds no damage to Z")
	await frames(540)
	check(not enemy.hawk_carry.active() and bow.hawk_skill.landings == 1, "Longer carry still lands exactly once")
	check(is_equal_approx(enemy.health_component.current_health, 476), "Unassisted Z retains its original damage")
	bow = await fresh_volley()
	player.set_third_person(false)
	await frames(2)
	check(bow.reticle_hud.visible, "First-person view has a reticle even outside sky aim")
	player.controls_enabled = false
	await frames(2)
	check(not bow.reticle_hud.visible, "Inactive controls hide the FPS reticle")
	player.controls_enabled = true
	await frames(2)
	await snapshot("fps_idle")
	bow.start_hawk()
	for i in range(180):
		await frames(1)
		if enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY: break
	action("attack", true)
	await frames(75)
	check(bow.reticle_hud.visible and is_zero_approx(player.spring_arm.spring_length) and -player.camera.global_basis.z.y > .65, "FPS sky aim keeps the eye camera and displays its reticle")
	await snapshot("fps")
	# Lead the circular flight manually; the projectile must hit through real physics.
	var origin := player.global_position + Vector3(0, 1.35, 0)
	var point := enemy.global_position + Vector3.UP * .9
	for i in range(6):
		var flight := origin.distance_to(point) / 34.0
		var angle := TAU * (enemy.hawk_carry.elapsed + flight) / HawkCarryEffect.CIRCLE_SECONDS
		point = enemy.hawk_carry.center + Vector3(cos(angle) * HawkCarryEffect.RADIUS, HawkCarryEffect.HEIGHT + .9, sin(angle) * HawkCarryEffect.RADIUS)
	player.camera.look_at(point)
	var direction := bow._manual_aim_direction()
	check(bow.release_arrow() and bow._arrows[0].direction.is_equal_approx(direction) and bow._arrows[0].homing == null, "FPS release uses the manual sightline with no homing")
	action("attack", false)
	await frames(65)
	check(bow.hits_landed == 1 and enemy.health_component.current_health < 496, "A manually led arrow adds damage while the victim stays carried")
	check(enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY, "Arrow damage preserves the bird's carry")
	await frames(600)
	check(not bow.sky_aiming and not enemy.hawk_carry.active(), "Aerial aim and carry clean up")
	bow = await fresh_volley()
	check(bow.start_charge() and bow.locked_target == enemy and not bow.sky_aiming, "Ordinary basic shots keep their existing targeting")
	bow.cancel_charge()
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
