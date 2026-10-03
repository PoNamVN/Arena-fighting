extends SceneTree
var passed: int = 0
var total: int = 0
func _init() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	total += 1
	if ok:
		passed += 1
	print("[%s] TEST %d: %s" % ["PASS" if ok else "FAIL", total, text])
func settle() -> void:
	for i: int in range(6):
		await process_frame
		await physics_frame
func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func click(button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	event = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	root.push_input(event)
	await process_frame
func run() -> void:
	root.size = Vector2i(1152, 720)
	change_scene_to_file("res://scenes/CombatTestArena.tscn")
	await settle()
	var test: CombatTestArena = current_scene as CombatTestArena
	await key(KEY_F1)
	await key(KEY_F2)
	await key(KEY_F3)
	check(test.player.stamina_component.training_infinite and test.no_cooldowns and test.player.health_component.training_invulnerable, "Real F1 F2 F3 input toggles tools")
	await key(KEY_F4)
	await settle()
	test = current_scene as CombatTestArena
	check(test != null and not test.player.stamina_component.training_infinite and not test.no_cooldowns and not test.player.health_component.training_invulnerable, "F4 reload clears all tool flags")
	check(is_equal_approx(test.player.health_component.current_health, 100) and test.player.stamina_component.is_full(), "F4 restores player HP and energy")
	test.difficulty_select.select(PracticeOpponent.Difficulty.HARD)
	await key(KEY_ESCAPE)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc releases cursor for practice button")
	await click(test.practice_button)
	await settle()
	var arena: PracticeArena = current_scene as PracticeArena
	check(arena != null and arena.round_state == PracticeArena.RoundState.COUNTDOWN and arena.brain.difficulty == PracticeOpponent.Difficulty.HARD, "Entry button opens countdown in new scene")
	await key(KEY_F1)
	await key(KEY_F2)
	await key(KEY_F3)
	await key(KEY_F4)
	check(current_scene == arena and not arena.player.stamina_component.training_infinite and not arena.player.health_component.training_invulnerable, "F1-F4 are inert inside AI match")
	arena._begin_fight()
	arena.player.health_component.take_damage(1000)
	await settle()
	check(arena.center_label.text.contains("AI THẮNG") and arena.result_buttons.visible, "Player defeat shows loss with replay")
	await click(arena.result_buttons.get_child(0) as Button)
	await settle()
	arena = current_scene as PracticeArena
	check(arena != null and arena.round_state == PracticeArena.RoundState.COUNTDOWN and arena.brain.difficulty == PracticeOpponent.Difficulty.HARD and arena.player.health_component.current_health == 200 and arena.opponent.health_component.current_health == 200, "Replay button starts a clean round")
	arena._begin_fight()
	arena.brain.enabled = false
	arena.player.stamina_component.add_stamina(100)
	check(arena.player._try_cast_ability("ultimate"), "V can enter targeting inside match")
	await settle()
	await click(arena.back_button)
	await settle()
	test = current_scene as CombatTestArena
	check(test != null and test.player._is_mouse_captured and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED) and root.get_camera_3d() == test.player.camera, "Return during V restores Arena Test camera and mouse")
	check(is_equal_approx(Engine.time_scale, 1.0) and not test.player.stamina_component.training_infinite, "Scene navigation restores time and default tools")
	PracticeArena.selected_difficulty = PracticeOpponent.Difficulty.NORMAL
	print("RESULTS: %d / %d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
