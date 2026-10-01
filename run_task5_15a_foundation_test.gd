extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15A FOUNDATION TEST SUITE")
	print("==================================================")
	
	test_input_map_actions()
	test_perspective_toggle()
	test_stamina_component()
	test_ability_data_and_system()
	test_dodge_controller()
	
	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	
	quit(0 if _failures == 0 else 1)


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] %s" % msg)
	else:
		_failures += 1
		print("[FAIL] %s" % msg)


func test_input_map_actions() -> void:
	print("\n--- Test Suite 1: InputMap Actions & Key Mappings ---")
	
	var required_actions: Array[String] = [
		"dodge",
		"skill_1",
		"skill_2",
		"skill_3",
		"ultimate",
		"toggle_perspective"
	]
	
	for action: String in required_actions:
		assert_true(InputMap.has_action(action), "InputMap contains action '%s'" % action)
	
	# Verify bound physical keycodes
	var expected_keys: Dictionary = {
		"dodge": KEY_Q,
		"skill_1": KEY_Z,
		"skill_2": KEY_X,
		"skill_3": KEY_C,
		"ultimate": KEY_V,
		"toggle_perspective": KEY_B
	}
	
	for action: String in expected_keys.keys():
		var expected_key: Key = expected_keys[action]
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var found: bool = false
		for ev: InputEvent in events:
			if ev is InputEventKey:
				var key_ev: InputEventKey = ev as InputEventKey
				if key_ev.physical_keycode == expected_key or key_ev.keycode == expected_key:
					found = true
					break
		assert_true(found, "Action '%s' bound to expected key code %d" % [action, expected_key])


func test_perspective_toggle() -> void:
	print("\n--- Test Suite 2: Perspective Toggle Migration (V -> B) ---")
	
	var player_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: Node3D = player_scene.instantiate()
	root.add_child(arena)
	
	var player: PlayerController = arena.find_child("Player", true, false) as PlayerController
	assert_true(player != null, "Found Player in CombatTestArena")
	if not player:
		arena.queue_free()
		return
	
	var initial_mode: bool = player.is_third_person
	
	# 1. Simulate physical KEY_V press (should NOT toggle perspective anymore)
	var event_v: InputEventKey = InputEventKey.new()
	event_v.physical_keycode = KEY_V
	event_v.pressed = true
	event_v.echo = false
	player._unhandled_input(event_v)
	
	assert_true(player.is_third_person == initial_mode, "Pressing KEY_V does NOT toggle camera perspective (reassigned to ultimate)")
	
	# 2. Simulate toggle_perspective action (KEY_B)
	var event_b: InputEventKey = InputEventKey.new()
	event_b.physical_keycode = KEY_B
	event_b.pressed = true
	event_b.echo = false
	player._unhandled_input(event_b)
	
	assert_true(player.is_third_person != initial_mode, "Pressing KEY_B / toggle_perspective action toggles camera perspective")
	
	# 3. Simulate toggle_perspective action again to verify toggling back
	var event_b2: InputEventKey = InputEventKey.new()
	event_b2.physical_keycode = KEY_B
	event_b2.pressed = true
	event_b2.echo = false
	player._unhandled_input(event_b2)
	
	assert_true(player.is_third_person == initial_mode, "Pressing KEY_B again returns camera perspective to original state")
	
	arena.queue_free()


func test_stamina_component() -> void:
	print("\n--- Test Suite 3: StaminaComponent Modular Behavior ---")
	
	var stamina: StaminaComponent = StaminaComponent.new()
	stamina.max_stamina = 100.0
	stamina.starting_stamina = 0.0
	stamina._ready()
	
	assert_true(stamina.current_stamina == 0.0, "Initial stamina starts at 0.0 (no passive regen)")
	assert_true(not stamina.is_full(), "Stamina is not full at start")
	assert_true(not stamina.has_enough_stamina(10.0), "has_enough_stamina returns false when empty")
	
	stamina.add_stamina(stamina.attack_stamina_gain) # 15.0
	assert_true(stamina.current_stamina == 15.0, "add_stamina increases stamina on attack gain")
	assert_true(stamina.has_enough_stamina(15.0), "has_enough_stamina returns true for 15.0")
	
	var consumed: bool = stamina.consume_stamina(stamina.dodge_stamina_cost) # 20.0
	assert_true(not consumed, "consume_stamina fails when cost exceeds current stamina")
	assert_true(stamina.current_stamina == 15.0, "Stamina unchanged after failed consumption")
	
	stamina.add_stamina(85.0)
	assert_true(stamina.is_full(), "Stamina is full at 100.0")
	assert_true(stamina.get_stamina_ratio() == 1.0, "Stamina ratio is 1.0 when full")
	
	stamina.consume_stamina(20.0)
	assert_true(stamina.current_stamina == 80.0, "consume_stamina deducts stamina correctly")
	
	stamina.reset_stamina()
	assert_true(stamina.current_stamina == 0.0, "reset_stamina zeroes current stamina")
	
	stamina.free()


func test_ability_data_and_system() -> void:
	print("\n--- Test Suite 4: AbilityData & AbilitySystem ---")
	
	var ab_skill1: AbilityData = AbilityData.new()
	ab_skill1.id = "fire_slash"
	ab_skill1.display_name = "Fire Slash"
	ab_skill1.stamina_cost = 25.0
	ab_skill1.cooldown = 3.0
	ab_skill1.requires_full_stamina = false
	
	var ab_ult: AbilityData = AbilityData.new()
	ab_ult.id = "meteor_strike"
	ab_ult.display_name = "Meteor Strike"
	ab_ult.stamina_cost = 100.0
	ab_ult.cooldown = 0.0
	ab_ult.requires_full_stamina = true
	
	var stamina: StaminaComponent = StaminaComponent.new()
	stamina.max_stamina = 100.0
	stamina.starting_stamina = 0.0
	stamina._ready()
	
	var system: AbilitySystem = AbilitySystem.new()
	system.stamina_component = stamina
	system.equip_ability("skill_1", ab_skill1)
	system.equip_ability("ultimate", ab_ult)
	
	assert_true(system.has_ability("skill_1"), "AbilitySystem has skill_1 equipped")
	assert_true(system.has_ability("ultimate"), "AbilitySystem has ultimate equipped")
	
	# Casting with 0 stamina should fail
	assert_true(not system.can_cast("skill_1"), "Cannot cast skill_1 without stamina")
	assert_true(not system.can_cast("ultimate"), "Cannot cast ultimate without full stamina")
	
	# Add stamina for skill 1
	stamina.add_stamina(30.0)
	assert_true(system.can_cast("skill_1"), "Can cast skill_1 with 30.0 stamina")
	assert_true(not system.can_cast("ultimate"), "Still cannot cast ultimate without 100% stamina")
	
	# Cast skill 1
	var cast_success: bool = system.cast_ability("skill_1")
	assert_true(cast_success, "Successfully cast skill_1")
	assert_true(stamina.current_stamina == 5.0, "Stamina deducted by 25.0 to 5.0")
	assert_true(system.is_on_cooldown("skill_1"), "skill_1 is now on cooldown")
	assert_true(not system.can_cast("skill_1"), "Cannot cast skill_1 while on cooldown")
	
	# Fill stamina to 100% for ultimate
	stamina.add_stamina(95.0)
	assert_true(stamina.is_full(), "Stamina filled to 100%")
	assert_true(system.can_cast("ultimate"), "Can cast ultimate when stamina is 100%")
	
	var ult_success: bool = system.cast_ability("ultimate")
	assert_true(ult_success, "Successfully cast ultimate")
	assert_true(stamina.current_stamina == 0.0, "Ultimate consumed 100% stamina")
	
	system.free()
	stamina.free()


func test_dodge_controller() -> void:
	print("\n--- Test Suite 5: DodgeController Directional & i-frame Foundation ---")
	
	var stamina: StaminaComponent = StaminaComponent.new()
	stamina.max_stamina = 100.0
	stamina.starting_stamina = 50.0
	stamina._ready()
	
	var dodge_ctrl: DodgeController = DodgeController.new()
	dodge_ctrl.stamina_component = stamina
	dodge_ctrl.stamina_cost = 20.0
	dodge_ctrl.cooldown = 0.5
	dodge_ctrl.dodge_duration = 0.4
	dodge_ctrl.iframe_start = 0.05
	dodge_ctrl.iframe_end = 0.25
	
	# Test direction determination
	var dir_default: DodgeController.Direction = dodge_ctrl.determine_dodge_direction(Vector2.ZERO)
	assert_true(dir_default == DodgeController.Direction.FORWARD, "Zero input defaults to FORWARD dodge")
	
	var dir_forward: DodgeController.Direction = dodge_ctrl.determine_dodge_direction(Vector2(0, 1))
	assert_true(dir_forward == DodgeController.Direction.FORWARD, "Forward input maps to FORWARD dodge")
	
	var dir_backward: DodgeController.Direction = dodge_ctrl.determine_dodge_direction(Vector2(0, -1))
	assert_true(dir_backward == DodgeController.Direction.BACKWARD, "Backward input maps to BACKWARD dodge")
	
	var dir_left: DodgeController.Direction = dodge_ctrl.determine_dodge_direction(Vector2(-1, 0))
	assert_true(dir_left == DodgeController.Direction.LEFT, "Left input maps to LEFT dodge")
	
	var dir_right: DodgeController.Direction = dodge_ctrl.determine_dodge_direction(Vector2(1, 0))
	assert_true(dir_right == DodgeController.Direction.RIGHT, "Right input maps to RIGHT dodge")
	
	# Test dodge start & stamina consumption
	assert_true(dodge_ctrl.can_dodge(), "can_dodge is true initially")
	var started: bool = dodge_ctrl.start_dodge(DodgeController.Direction.BACKWARD)
	assert_true(started, "start_dodge succeeded")
	assert_true(dodge_ctrl.is_dodging, "is_dodging is true")
	assert_true(dodge_ctrl.current_direction == DodgeController.Direction.BACKWARD, "Direction is BACKWARD")
	assert_true(stamina.current_stamina == 30.0, "Stamina consumed from 50 to 30")
	assert_true(not dodge_ctrl.can_dodge(), "can_dodge is false while currently dodging")
	
	# Test i-frame window progression
	# At t = 0.02 (before iframe_start 0.05):
	dodge_ctrl._process(0.02)
	assert_true(not dodge_ctrl.is_in_iframe(), "Not in i-frame at t = 0.02s (windup)")
	
	# Advance to t = 0.10 (inside iframe window 0.05 - 0.25):
	dodge_ctrl._process(0.08)
	assert_true(dodge_ctrl.is_in_iframe(), "In i-frame at t = 0.10s")
	
	# Advance to t = 0.30 (past iframe_end 0.25):
	dodge_ctrl._process(0.20)
	assert_true(not dodge_ctrl.is_in_iframe(), "Not in i-frame at t = 0.30s (recovery)")
	
	# Complete dodge (duration 0.40s):
	dodge_ctrl._process(0.10)
	assert_true(not dodge_ctrl.is_dodging, "Dodge completed at duration expiration")
	
	# Verify cooldown is still active
	assert_true(not dodge_ctrl.can_dodge(), "Cannot dodge immediately during cooldown")
	
	# Expire cooldown
	dodge_ctrl._process(0.5)
	assert_true(dodge_ctrl.can_dodge(), "Can dodge again after cooldown expiration")
	
	dodge_ctrl.free()
	stamina.free()
