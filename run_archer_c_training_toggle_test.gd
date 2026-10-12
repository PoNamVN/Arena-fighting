extends "res://run_archer_forest_escape_test.gd"

func training_key(room: CombatTestArena, key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	room._input(event)

func _run() -> void:
	PracticeArena.selected_hero = "archer"
	var room: CombatTestArena = load("res://scenes/CombatTestArena.tscn").instantiate() as CombatTestArena
	root.add_child(room)
	root.size = Vector2i(1152, 720)
	showcase = Camera3D.new()
	room.add_child(showcase)
	await frames(10)
	player = room.player
	player.external_controlled = true
	training_key(room, KEY_F1)
	training_key(room, KEY_F2)
	training_key(room, KEY_F3)
	check(room.no_cooldowns and player.stamina_component.training_infinite and player.health_component.training_invulnerable, "Actual F1/F2/F3 training toggles are enabled")
	var bow := player.archer_combat
	for cast in range(3):
		player.global_position = Vector3(-5 + cast * 5, .1, 5)
		await frames(5)
		check(bow.start_escape(), "C casts with F1/F2/F3 enabled")
		check(is_equal_approx(bow.stealth_remaining, 10) and not player.ability_system.is_on_cooldown("skill_3"), "F2 clears cooldown but keeps finite ten-second stealth")
		await frames(45)
		check(bow.is_hidden() and bow.forest_escape.grass.visible and bow.forest_escape._tuft_growth.max() > .9, "Training C grows full-height visible grass")
		if cast == 0: await snapshot("f123_fixed")
		check(not player.is_targetable(), "Training stealth still prevents AI target acquisition")
		await frames(600)
		check(not bow.is_hidden() and bow.forest_escape.grass.visible, "Training stealth expires while the grass finishes its own lifetime")
		await frames(320)
		check(not bow.forest_escape.grass.visible, "Training grass also expires without a cooldown timer")
	training_key(room, KEY_F2)
	check(bow.start_escape() and player.ability_system.is_on_cooldown("skill_3") and bow.stealth_remaining > 9.9, "Turning F2 off restores normal C cooldown and duration")
	room.queue_free()
	await frames(3)
	PracticeArena.selected_hero = "knight"
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
