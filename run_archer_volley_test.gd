extends "res://run_archer_basic_test.gd"

# Shared fixture retained for defense, X/C and ultimate suites.
func fresh_volley() -> ArcherCombat:
	await fresh()
	enemy.hit_knockback_distance = 0.0
	enemy.block_recoil_distance = 0.0
	player.stamina_component.current_stamina = 100.0
	return player.archer_combat

func _run() -> void:
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var bow := await fresh_volley()
	var skill := bow.hawk_skill
	player.stamina_component.current_stamina = 24
	check(not bow.start_hawk() and not skill.active(), "Insufficient energy rejects fish Z")
	check(not player.ability_system.is_on_cooldown("skill_1"), "Rejected cast starts no cooldown")
	player.stamina_component.current_stamina = 100
	enemy.position.x = 30
	await frames(2)
	check(not bow.start_hawk() and player.stamina_component.current_stamina == 100, "No target spends nothing")
	enemy.position.x = 0
	await frames(2)
	action("skill_1", true)
	action("skill_1", false)
	await frames(1)
	check(skill.casting and player.stamina_component.current_stamina == 75, "Real Z input consumes energy once")
	check(player.ability_system.get_max_cooldown("skill_1") == 24, "Z starts twenty-four-second cooldown")
	check(not bow.start_charge() and not bow.start_hawk(), "Startup prevents overlapping attacks")
	await frames(8)
	check(skill.shots == 0 and enemy.health_component.current_health == 500, "Startup has no instant hit")
	await frames(50)
	check(skill.shots == 1 and skill.grabs == 1, "One physical fish arrow captures one target")
	check(enemy.hawk_carry.active() and enemy.is_control_impaired(), "Victim controls are locked")
	check(not enemy._try_dodge() and not enemy._start_block() and not enemy._try_cast_ability("skill_1"), "Victim cannot dodge, block or cast after capture")
	await frames(360)
	check(not skill.active() and not enemy.hawk_carry.active(), "Hawk exits and victim control restores")
	check(absf(enemy.health_component.current_health - 476) < .1, "Arrow four plus landing twenty damage once")
	check(skill.landings == 1 and enemy.hawk_carry.fall_hits == 1, "Landing damage applies exactly once")
	check(absf(enemy.hawk_carry.orbit_angle - TAU) < .01, "Unobstructed carry completes a full circle")
	check(enemy.global_position.y < .15 and player.stamina_component.current_stamina == 75, "Victim lands; skill generates no basic energy")
	check(player.ability_system.get_cooldown_remaining("skill_1") > 17, "Long cooldown still prevents spam after the entire high carry finishes")
	check(bow.start_charge() and not bow.start_hawk(), "Basic resumes while Z remains on cooldown")
	bow.cancel_charge()
	bow = await fresh_volley()
	skill = bow.hawk_skill
	enemy.visuals.rotation.y = PI
	enemy._camera_yaw = PI
	enemy._start_block()
	bow.start_hawk()
	await frames(200)
	check(enemy.health_component.current_health == 500 and enemy.shield_durability == 90, "Frontal block prevents HP damage and costs ten durability")
	check(skill.grabs == 0 and not enemy.hawk_carry.active(), "Block never summons a hawk")
	bow = await fresh_volley()
	enemy.visuals.rotation.y = PI
	enemy._camera_yaw = PI
	enemy._start_block()
	enemy.shield_durability = 5
	bow.start_hawk()
	await frames(50)
	check(enemy.is_shield_broken and bow.hawk_skill.grabs == 0, "Shield-break hit is still blocked, never captures")
	bow = await fresh_volley()
	bow.start_hawk()
	await frames(5)
	player.apply_hit_reaction(Vector3.BACK)
	await frames(100)
	check(bow.hawk_skill.shots == 0 and not bow.hawk_skill.active(), "Startup interruption fires no arrow")
	check(player.stamina_component.current_stamina == 75, "Interrupted cast does not refund energy")
	bow = await fresh_volley()
	bow.start_hawk()
	await frames(50)
	check(enemy.hawk_carry.active(), "Cleanup fixture captured")
	bow.reset()
	await frames(3)
	check(not enemy.hawk_carry.active() and enemy.global_position.y < .2 and not bow.hawk_skill.active(), "Reset returns victim safely and clears owned nodes")
	check(enemy.health_component.current_health == 496, "Cancelled carry has no fall damage")
	for profile: String in ["archer", "wizard"]:
		bow = await fresh_volley()
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
		bow.start_hawk()
		await frames(360)
		check(bow.hawk_skill.grabs == 1 and not enemy.hawk_carry.active() and absf(enemy.health_component.current_health - 476) < .1, profile + " supports complete capture/landing")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
