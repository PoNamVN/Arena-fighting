extends SceneTree

var passed := 0
var total := 0

func _init() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func check(value: bool, description: String) -> void:
	total += 1
	if value: passed += 1
	print("[%s] TEST %d: %s" % ["PASS" if value else "FAIL", total, description])

func _run() -> void:
	PracticeArena.selected_hero = "archer"
	var scene_path: String = ProjectSettings.get_setting("application/run/main_scene")
	var arena: CombatTestArena = load(scene_path).instantiate()
	root.add_child(arena)
	await frames(10)
	var player := arena.player
	var dummy := arena.training_dummy
	arena.attack_dummy.auto_attack = false
	arena.attack_dummy.cancel_attack()
	arena.attack_dummy.queue_free()
	player.position = Vector3(0, .1, 3)
	dummy.position = Vector3(0, .1, -5)
	dummy.auto_reset_on_death = false
	player._camera_yaw = 0
	player.camera_pivot.rotation.y = 0
	player.stamina_component.current_stamina = 100
	await frames(5)
	check(player.ability_system.get_ability("skill_1").id == "archer_hawk_fish", "Actual project main scene equips the new Archer Z")
	check(player.ability_system.get_ability("skill_1").cooldown == 24, "Actual main scene uses twenty-four-second cooldown")
	var key := InputEventKey.new()
	key.keycode = KEY_Z
	key.physical_keycode = KEY_Z
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await frames(1)
	key = InputEventKey.new()
	key.keycode = KEY_Z
	key.physical_keycode = KEY_Z
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	var skill := player.archer_combat.hawk_skill
	check(skill.casting, "Physical Z key dispatches fish skill in the actual game scene")
	var maximum_height := 0.0
	var inverted := false
	for i in range(750):
		await frames(1)
		maximum_height = maxf(maximum_height, dummy.global_position.y)
		inverted = inverted or dummy.hawk_carry.inversion > .99
	check(skill.shots == 1 and skill.grabs == 1 and skill.landings == 1, "Real main scene fires one fish and completes one hawk capture/drop")
	check(maximum_height > 13.5 and inverted, "Real main scene carries its dummy upside down fourteen metres")
	check(not dummy.hawk_carry.active() and not skill.active(), "Real main scene restores controls and releases the hawk")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
