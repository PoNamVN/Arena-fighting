extends "res://run_archer_volley_test.gd"

func obstacle(position: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	arena.add_child(wall)
	wall.position = position
	return wall

func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	var bow := await fresh_volley()
	bow.start_hawk()
	await frames(22)
	enemy.position.x = 1.1
	await frames(750)
	check(bow.hawk_skill.grabs == 1 and bow.hawk_skill.landings == 1, "Fish follows a moving target after release")
	bow = await fresh_volley()
	bow.start_hawk()
	await frames(20)
	var wall := obstacle(Vector3(0, 2, 0), Vector3(6, 4, .2))
	await frames(150)
	check(bow.hawk_skill.grabs == 0 and enemy.health_component.current_health == 500, "Wall inserted after launch blocks the actual projectile")
	wall.queue_free()
	bow = await fresh_volley()
	wall = obstacle(Vector3(0, 3.2, -5), Vector3(6, .2, 6))
	await frames(2)
	bow.start_hawk()
	await frames(220)
	check(bow.hawk_skill.grabs == 1 and bow.hawk_skill.landings == 1 and not enemy.hawk_carry.active(), "Ceiling aborts lift into a safe shortened fall")
	check(enemy.health_component.current_health > 476 and enemy.health_component.current_health < 496, "Shorter physical fall reduces landing damage")
	check(enemy.global_position.y < .2, "Ceiling collision cannot strand a victim")
	wall.queue_free()
	bow = await fresh_volley()
	bow.start_hawk()
	await frames(135)
	player.health_component.take_damage(1000)
	await frames(4)
	check(not enemy.hawk_carry.active() and enemy.global_position.y < .2, "Caster death safely releases captured victim")
	check(enemy.health_component.current_health == 496 and not bow.hawk_skill.active(), "Caster death cancels pending fall damage")
	bow = await fresh_volley()
	bow.start_hawk()
	await frames(50)
	check(not enemy.frost.begin() and not enemy.polymorph.begin(), "Other CC cannot steal carry movement ownership")
	enemy.health_component.take_damage(1000)
	await frames(5)
	check(not enemy.hawk_carry.active(), "Victim death clears carry without reviving controls")
	bow = await fresh_volley()
	bow.start_hawk()
	await frames(50)
	enemy.queue_free()
	await frames(80)
	check(not bow.hawk_skill.active(), "Deleted victim cannot leave a summon active")
	bow = await fresh_volley()
	enemy.stamina_component.current_stamina = 0
	check(enemy._try_dodge(), "Dodge fixture starts")
	await frames(5)
	check(enemy.is_in_dodge_iframe(), "Dodge fixture reaches invulnerability window")
	bow.hawk_skill.target = enemy
	bow.hawk_skill._impact(enemy, player.global_position + Vector3.UP, enemy.global_position)
	check(enemy.health_component.current_health == 500 and bow.hawk_skill.grabs == 0, "I-frame hit never marks or grabs")
	check(enemy.stamina_component.current_stamina == 25, "Perfect Dodge reward is awarded once by the shared resolver")
	bow = await fresh_volley()
	enemy.position = Vector3(14.5, .1, -5)
	var offset := enemy.position - player.position
	player._camera_yaw = atan2(-offset.x, -offset.z)
	player.camera_pivot.rotation.y = player._camera_yaw
	await frames(3)
	bow.start_hawk()
	var bounded := true
	var bounds: Node = arena.get_node("ArenaPlayBounds")
	for i in range(750):
		await frames(1)
		var local: Vector3 = arena.to_local(enemy.global_position)
		for j in range(bounds._normals.size()):
			if local.dot(bounds._normals[j]) > bounds._limits[j] + .001: bounded = false
	check(bounded and not enemy.hawk_carry.active(), "Carry stays inside all arena planes at every altitude")
	bow = await fresh_volley()
	var dummy: TrainingDummy = load("res://scenes/TrainingDummy.tscn").instantiate()
	dummy.position = Vector3(0, .1, -3)
	dummy.auto_reset_on_death = false
	arena.add_child(dummy)
	await frames(4)
	bow.start_hawk()
	await frames(750)
	var expected_fall_damage := 20.0 * clampf((dummy.hawk_carry.fall_start - dummy.global_position.y) / HawkCarryEffect.HEIGHT, 0, 1)
	check(bow.hawk_skill.grabs == 1 and not dummy.hawk_carry.active() and absf(dummy.current_hp - (96 - expected_fall_damage)) < .2, "Static practice dummy captures and takes damage for the actual fall height, including raised arena geometry")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed,total])
	quit(0 if passed == total else 1)
