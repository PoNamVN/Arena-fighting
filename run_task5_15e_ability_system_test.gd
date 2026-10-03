extends SceneTree

var _failures: int = 0
var _passes: int = 0
var _budget: int = 1600
var arena: Node3D
var p: PlayerController
var dummy: TrainingDummy


func _initialize() -> void:
	call_deferred("_run_all_tests")
	physics_frame.connect(func() -> void:
		_budget -= 1
		if _budget <= 0:
			push_error("Ability integration timed out")
			quit(1)
	)


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] " + msg)
	else:
		_failures += 1
		push_error("[FAIL] " + msg)


func _step(count: int = 1) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame


func _input(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _reset_scenario() -> void:
	for action: StringName in [&"attack", &"skill_1", &"skill_2", &"skill_3", &"ultimate"]:
		_input(action, false)
	p.respawn(Vector3(0, 0.1, 0))
	p._camera_yaw = 0
	p._camera_pitch = 0
	dummy.global_position = Vector3(0, 0, -2)
	dummy.health_component.current_health = 100
	await _step(4)
	p.stamina_component.current_stamina = 100


func _wait_finished() -> bool:
	for frame: int in range(300):
		if p.active_ability_action == null:
			return true
		await _step()
	assert_true(false, "Ability must naturally finish within its bounded lifecycle")
	return false


func _run_all_tests() -> void:
	# Isolated floor avoids unrelated arena attacker AI changing HP/stamina.
	arena = Node3D.new()
	root.add_child(arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(60, 1, 60)
	floor_shape.shape = floor_box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	p = load("res://scenes/Player.tscn").instantiate() as PlayerController
	arena.add_child(p)
	dummy = load("res://scenes/TrainingDummy.tscn").instantiate() as TrainingDummy
	arena.add_child(dummy)
	await _reset_scenario()
	assert_true(p.ability_system != null, "Knight AbilitySystem initialized")
	var asys: AbilitySystem = p.ability_system
	var sc: StaminaComponent = p.stamina_component
	var z: AbilityData = asys.get_ability("skill_1")
	var x: AbilityData = asys.get_ability("skill_2")
	var c: AbilityData = asys.get_ability("skill_3")
	var v: AbilityData = asys.get_ability("ultimate")
	assert_true(z.id == "shield_charge" and z.damage == 25 and z.stamina_cost == 20 and z.cooldown == 4, "Z is Shield Charge: 25 damage / 20 stamina / 4s cooldown")
	assert_true(x.id == "sky_dive" and x.damage == 35 and x.stamina_cost == 25 and x.cooldown == 6, "X is Sky Dive: 35 damage / 25 stamina / 6s cooldown")
	assert_true(c.id == "whirling_blade" and c.damage == 30 and c.stamina_cost == 30 and c.cooldown == 5, "C is Whirling Blade: 30 damage / 30 stamina / 5s cooldown")
	assert_true(v.id == "giant_sword_ultimate" and v.damage == 90 and v.requires_full_stamina and v.stamina_cost == 100 and v.cooldown == 0, "V is targeted Giant Sword: 90 damage / full stamina / no cooldown")
	_input("skill_1", true)
	await _step()
	assert_true(p.active_ability_action != null and sc.current_stamina == 80, "Z input starts action and spends 20 once")
	assert_true(asys.get_cooldown_remaining("skill_1") > 3.9, "Z starts its 4s cooldown")
	assert_true(dummy.current_hp == 100, "Z does not damage during startup")
	assert_true(asys.get_cooldown_remaining("skill_2") == 0 and asys.get_cooldown_remaining("skill_3") == 0 and asys.get_cooldown_remaining("ultimate") == 0, "Z cooldown does not affect other slots")
	assert_true(not p._try_cast_ability("skill_2") and sc.current_stamina == 80, "Active Z rejects another skill without spending")
	if not await _wait_finished():
		quit(1)
		return
	assert_true(dummy.current_hp == 75 and sc.current_stamina == 80, "Z impact deals 25 once without stamina refund")
	assert_true(not p._try_cast_ability("skill_1") and sc.current_stamina == 80, "Z cooldown still rejects cast after recovery")
	await _reset_scenario()
	p.shield_durability = 50
	p._camera_pitch = deg_to_rad(-80)
	_input("skill_2", true)
	await _step()
	assert_true(p.active_ability_action != null and sc.current_stamina == 75 and asys.get_cooldown_remaining("skill_2") > 5.9, "X input spends 25 and starts 6s cooldown")
	for frame: int in range(120):
		if p._sky_dive_sub_phase == 2:
			break
		await _step()
	assert_true(p._sky_dive_sub_phase == 2 and dummy.current_hp == 100, "X reaches aerial aim without early damage")
	await _step(5)
	assert_true(p._sky_dive_sub_phase == 2, "X waits for a fresh LMB confirmation")
	_input("attack", true)
	await _step()
	_input("attack", false)
	if not await _wait_finished():
		quit(1)
		return
	assert_true(dummy.current_hp == 65 and p.is_on_floor(), "X deals 35 on physical landing and finishes recovery")
	assert_true(p.shield_durability == 50, "Sky Dive does not inherit prototype Shield Bash repair")
	await _reset_scenario()
	_input("skill_3", true)
	await _step()
	assert_true(p.active_ability_action != null and sc.current_stamina == 70 and asys.get_cooldown_remaining("skill_3") > 4.9, "C input spends 30 and starts 5s cooldown")
	assert_true(dummy.current_hp == 100, "C startup causes no early damage")
	if not await _wait_finished():
		quit(1)
		return
	assert_true(dummy.current_hp == 70 and sc.current_stamina == 70, "C deals 30 once through ACTIVE and recovery")
	await _reset_scenario()
	sc.current_stamina = 99
	assert_true(not p._try_cast_ability("ultimate") and sc.current_stamina == 99, "V rejects partial stamina without spending")
	sc.current_stamina = 100
	_input("ultimate", true)
	await _step(35)
	assert_true(p.giant_sword_ultimate.aiming and sc.current_stamina == 0 and dummy.current_hp == 100, "V reserves 100 and waits for ground selection without damage")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = p.giant_sword_ultimate.cinematic_camera.unproject_position(Vector3(0, 0, -2))
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await _step()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	assert_true(not p.giant_sword_ultimate.aiming and p.active_ability_action.custom_data["impact_origin"].distance_to(Vector3(0, 0, -2)) < 0.05, "LMB ray commits the selected ground point")
	await _step(40)
	assert_true(dummy.current_hp == 100, "V has no damage before sword reaches the ground")
	if not await _wait_finished():
		quit(1)
		return
	assert_true(dummy.current_hp == 10 and sc.current_stamina == 0, "Selected V impact deals 90 once without stamina reward")
	assert_true(p.camera.current and not p.combat.giant_sword_vfx.visible and p._is_mouse_captured, "V completion restores camera/cursor and removes effects")
	await _reset_scenario()
	p._combo_finisher_recovery_timer = 0.5
	assert_true(not p._try_cast_ability("skill_1") and not p._try_cast_ability("ultimate") and sc.current_stamina == 100, "Finisher recovery rejects abilities without spending")
	p._combo_finisher_recovery_timer = 0
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(not p._try_cast_ability("skill_1") and not p._try_cast_ability("ultimate"), "DEAD rejects skills and ultimate")
	arena.queue_free()
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	quit(0 if _failures == 0 else 1)
