extends "res://run_archer_volley_test.gd"

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	await root.get_node("VFXManager").warmup()
	var showcase := Camera3D.new()
	arena.add_child(showcase)
	showcase.make_current()
	for profile: String in ["knight", "archer", "wizard"]:
		var bow := await fresh_volley()
		enemy.queue_free()
		await frames(2)
		enemy = load("res://scenes/Player.tscn").instantiate() as PlayerController
		enemy.hero_profile = profile
		enemy.external_controlled = true
		enemy.position = Vector3(0, .1, -5)
		enemy.collision_layer = 4
		enemy.collision_mask = 3
		enemy.get_node("HealthComponent").max_health = 500
		arena.add_child(enemy)
		await frames(5)
		check(enemy.ensure_ragdoll(), profile + " has a physical ragdoll rig")
		var simulation_starts := [0]
		enemy.ragdoll.ragdoll_started.connect(func(): simulation_starts[0] += 1)
		check(bow.start_hawk(), profile + " starts the wider circle skill")
		var minimum_x := 0.0
		var landed := false
		var ragdoll_seen := false
		var recovery_seen := false
		var immunity_checked := false
		var protected_frames := 0
		var protected_whole_clip := true
		var air_phases: Dictionary = {}
		var simulated_whole_flight := true
		var feet_pinned := true
		var hangs_upside_down := true
		var limb_motion := 0.0
		for i in range(660):
			await frames(1)
			showcase.global_position = enemy.global_position + Vector3(5, 3, 6)
			showcase.look_at(enemy.global_position + Vector3.UP)
			minimum_x = minf(minimum_x, enemy.global_position.x)
			if enemy.hawk_carry.phase in [HawkCarryEffect.Phase.LIFT, HawkCarryEffect.Phase.CARRY, HawkCarryEffect.Phase.FALL]:
				air_phases[enemy.hawk_carry.phase] = true
				simulated_whole_flight = simulated_whole_flight and enemy.is_ragdoll_active() and enemy.ragdoll.simulator.is_simulating_physics() and not enemy.is_ragdoll_recovering()
				if enemy.hawk_carry.phase != HawkCarryEffect.Phase.FALL:
					for name: String in ["shin.L", "shin.R"]:
						var shin: PhysicalBone3D = enemy.ragdoll.physical_bones[name]
						var pin: Transform3D = enemy.global_transform * enemy.ragdoll._hawk_pins[name]
						feet_pinned = feet_pinned and shin.global_position.distance_to(pin.origin) < .15
				if enemy.hawk_carry.phase == HawkCarryEffect.Phase.CARRY:
					hangs_upside_down = hangs_upside_down and enemy.ragdoll.physical_bones["head"].global_position.y < enemy.hawk_carry.grip_position().y - .7
					limb_motion = maxf(limb_motion, enemy.ragdoll.physical_bones["forearm.L"].angular_velocity.length())
			if bow.hawk_skill.landings > 0 and not landed:
				landed = true
				check(enemy.global_position.z > -3, profile + " is thrown horizontally before landing")
				check(enemy.is_ragdoll_active() and not enemy.hawk_carry.active(), profile + " hands carry movement to a physical ragdoll on impact")
				check(not enemy._start_block(), profile + " cannot skip its forced knockdown/get-up")
			if enemy.is_ragdoll_active():
				ragdoll_seen = true
			if enemy.is_ragdoll_recovering():
				recovery_seen = true
				protected_frames += 1
				var poke := AttackPayload.new(1, player.global_position)
				enemy.take_damage(poke, player.global_position)
				protected_whole_clip = protected_whole_clip and poke.outcome == &"rejected"
				if not immunity_checked:
					immunity_checked = true
					check(enemy.anim_player.current_animation == "get_up", profile + " plays a real get-up animation")
					var hp := enemy.health_component.current_health
					var position := enemy.global_position
					var payload := AttackPayload.new(50, player.global_position)
					enemy.take_damage(payload, player.global_position)
					check(enemy.health_component.current_health == hp and payload.outcome == &"rejected", profile + " rejects damage throughout get-up")
					check(not enemy.frost.begin() and not enemy.polymorph.begin() and not enemy.apply_impact_stun(1), profile + " rejects freeze, polymorph and stun during get-up")
					var shield := enemy.shield_durability
					enemy.apply_shield_damage(100)
					check(enemy.shield_durability == shield and not enemy.is_shield_broken, profile + " rejects shield damage during get-up")
					enemy.apply_knockback(Vector3.RIGHT, 4, .2)
					check(not enemy.trigger_ragdoll(Vector3.UP * 10) and not enemy.ragdoll.start_ragdoll(Vector3.UP * 10), profile + " cannot restart ragdoll while getting up")
					enemy.ragdoll.apply_impulse(Vector3.RIGHT * 20)
					enemy.ragdoll.apply_bone_impulse("hips", Vector3.RIGHT * 100)
					check(enemy.global_position.is_equal_approx(position) and enemy._knockback_timer == 0 and not enemy._start_block(), profile + " get-up is not displaced or cancelled")
			if landed and recovery_seen and not enemy.is_ragdoll_active(): break
		check(minimum_x < -10, profile + " flies a circle wider than ten metres across")
		check(air_phases.size() == 3 and simulated_whole_flight, profile + " stays ragdoll during lift, circle and fall without standing up in midair")
		check(feet_pinned and enemy.ragdoll._hawk_pins.is_empty(), profile + " pins both ankles while held and releases both on throw")
		check(hangs_upside_down, profile + " hangs with its head below the grabbed ankles")
		check(limb_motion > .1, profile + " has physically moving limbs while carried")
		check(simulation_starts[0] == 1, profile + " keeps one continuous simulation from grab through ground impact")
		check(ragdoll_seen and recovery_seen and not enemy.is_ragdoll_active(), profile + " automatically finishes ragdoll and stands up")
		check(protected_frames >= 49 and protected_whole_clip, profile + " stays immune through the entire get-up clip")
		check(absf(enemy.health_component.current_health - 476) < .2, profile + " keeps Z damage at twenty-four")
		check(is_equal_approx(enemy.camera_pivot.position.y, 1.62), profile + " restores the standing camera")
		enemy.take_damage(5)
		check(absf(enemy.health_component.current_health - 471) < .2, profile + " takes damage again after standing up")
		await frames(60)
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
