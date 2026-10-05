extends SceneTree

# Real engine frames and InputMap events; no production confirmation flags.
var player: PlayerController
var arena: Node3D
var passed: int = 0
var failed: int = 0
var frame_budget: int = 2400
var entry_press_pending: bool = false
var entry_press_sent: bool = false
var monitor_movement: bool = false
var previous_position: Vector3
var max_step: float = 0.0
var recovery_airborne: bool = false
var finite_motion: bool = true
var entry_press_frame: int = -1
var landing_seen: bool = false


func _initialize() -> void:
	call_deferred("_run")
	physics_frame.connect(_before_physics)


func _before_physics() -> void:
	frame_budget -= 1
	if frame_budget <= 0:
		push_error("X-C test timed out")
		quit(1)
	if entry_press_pending and is_instance_valid(player) and player._sky_dive_sub_phase == 1:
		var dt: float = 1.0 / float(Engine.physics_ticks_per_second)
		var next_height: float = player.global_position.y - player._sky_dive_start_y + (player.velocity.y - player.SKY_DIVE_HOVER_GRAVITY * dt) * dt
		if next_height >= player.SKY_DIVE_JUMP_HEIGHT:
			entry_press_pending = false
			entry_press_sent = true
			entry_press_frame = Engine.get_physics_frames()
			_input("attack", true)


func _input(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _step(count: int = 1) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame
		if monitor_movement and is_instance_valid(player):
			max_step = maxf(max_step, player.global_position.distance_to(previous_position))
			previous_position = player.global_position
			finite_motion = finite_motion and player.global_position.is_finite() and player.velocity.is_finite()
			if player._sky_dive_sub_phase == 4:
				landing_seen = landing_seen or player.is_on_floor()
				if not player.is_on_floor():
					recovery_airborne = true


func _assert(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[PASS] " + label)
	else:
		failed += 1
		push_error("[FAIL] " + label)


func _new_player() -> void:
	monitor_movement = false
	entry_press_pending = false
	for action: StringName in [&"attack", &"block", &"dodge", &"skill_1", &"skill_2", &"move_forward", &"move_right"]:
		_input(action, false)
	if is_instance_valid(player):
		player.queue_free()
		await _step(2)
	var scene: PackedScene = load("res://scenes/Player.tscn") as PackedScene
	if not scene:
		push_error("Cannot load Player.tscn")
		quit(1)
		return
	player = scene.instantiate() as PlayerController
	arena.add_child(player)
	await _step(4)
	player.stamina_component.current_stamina = 100.0
	previous_position = player.global_position
	max_step = 0.0
	recovery_airborne = false
	landing_seen = false
	monitor_movement = true


func _cast() -> void:
	_input("skill_2", true)
	await _step()
	_input("skill_2", false)
	_assert(player.active_ability_action != null and player.active_ability_action.data.id == "sky_dive", "X input activates Sky Dive")


func _wait_phase(phase: int, limit: int = 150) -> bool:
	for frame: int in range(limit):
		if player._sky_dive_sub_phase == phase:
			return true
		await _step()
	_assert(false, "Required X phase %d never reached" % phase)
	return false


func _clean_x_state() -> bool:
	return player._sky_dive_sub_phase == 0 and player._sky_dive_aim_entry_frame == -1 and not player._sky_dive_attack_armed and player._sky_dive_start_y == 0.0 and player._sky_dive_direction == Vector3.FORWARD


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	floor_shape.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	await _new_player()
	_assert(player.is_on_floor(), "Test starts on a physical floor")
	_assert(player.anim_player != null and player.anim_player.has_animation("Knight_X_SkyDive"), "Knight_X_SkyDive genuinely imported")
	if not player.anim_player or not player.anim_player.has_animation("Knight_X_SkyDive"):
		quit(1)
		return
	await _cast()
	_assert(player.anim_player.current_animation == "Knight_X_SkyDive" and player.anim_player.is_playing(), "Authored X animation selected and playing")
	_assert(is_equal_approx(player.stamina_component.current_stamina, 75.0), "Stamina spent exactly once")
	var cooldown_start: float = player.ability_system.get_cooldown_remaining("skill_2")
	_assert(cooldown_start > 5.8 and cooldown_start <= 6.0, "Existing cooldown starts once")
	_input("attack", true) # Hold throughout takeoff and AIM entry.
	if not await _wait_phase(1):
		quit(1)
		return
	_assert(player.velocity.y > 0.0 and not player.is_on_floor(), "Launch preserves upward velocity and leaves floor")
	_assert(player.global_position.y > 0.0, "Takeoff produces actual displacement")
	if not await _wait_phase(2):
		quit(1)
		return
	_assert(player.global_position.y >= 3.4, "Aerial AIM reached at elevated position")
	var aim_position: Vector3 = player.global_position
	await _step(75) # 1.25 seconds, including held LMB.
	_assert(player._sky_dive_sub_phase == 2, "Held-before-AIM LMB never confirms, including beyond 0.8 seconds")
	_assert(not player.is_on_floor() and player.global_position.distance_to(aim_position) < 0.01, "AIM remains physically airborne without drift")
	_assert(player.combat_state != PlayerController.CombatState.ATTACK, "Held LMB does not start combo")
	_assert(player.ability_system.get_cooldown_remaining("skill_2") < cooldown_start and is_equal_approx(player.stamina_component.current_stamina, 75.0), "AIM does not repeat spending or restart cooldown")
	_assert(not player._start_block() and not player._try_dodge() and not player._try_cast_ability("skill_2"), "RMB, Q and X retrigger rejected during AIM")
	_input("attack", false)
	await _step(60)
	_assert(player._sky_dive_sub_phase == 2, "Released AIM remains active without automatic dive")
	# Counter window fixture: production X must own LMB before Counter dispatch.
	player.dodge_controller.counter_window_active = true
	player.dodge_controller.set("_counter_timer", 10.0)
	player._camera_yaw = 0.7
	player._camera_pitch = -0.1
	player._update_camera_rotation()
	var dive_start: Vector3 = player.global_position
	_input("attack", true)
	await _step()
	_assert(player._sky_dive_sub_phase == 3, "Fresh post-entry Input.is_action_just_pressed confirms dive")
	_assert(player.combat_state != PlayerController.CombatState.ATTACK and player.combo_step == 0, "Confirmation starts no Attack 1/2/3")
	_assert(player.combat_state != PlayerController.CombatState.COUNTER and player.dodge_controller.counter_window_active, "Confirmation neither starts Counter nor consumes its window")
	var first_direction: Vector3 = player._sky_dive_direction
	var expected_direction: Vector3 = -Basis.from_euler(Vector3(-0.1, 0.7, 0.0)).z
	expected_direction.y = minf(expected_direction.y, -0.35)
	expected_direction = expected_direction.normalized()
	_assert(first_direction.dot(expected_direction) > 0.999, "Dive derives direction from camera yaw and pitch")
	_input("move_forward", true)
	_input("move_right", true)
	await _step(3)
	var travel: Vector3 = player.global_position - dive_start
	_assert(travel.length() > 0.5 and travel.normalized().dot(first_direction) > 0.98, "Actual dive displacement follows aim despite WASD")
	_assert(not player._start_block() and not player._try_dodge() and not player._try_cast_ability("skill_2"), "RMB, Q and X rejected during committed dive")
	await _step(19)
	_assert(player._sky_dive_sub_phase == 3 and not player.is_on_floor(), "Dive remains active beyond former 0.35s timeout while airborne")
	if not await _wait_phase(4):
		quit(1)
		return
	_assert(player.is_on_floor() and landing_seen and not recovery_airborne, "Recovery begins only after genuine floor contact")
	_input("move_forward", false)
	_input("move_right", false)
	player.dodge_controller.consume_counter_window()
	for frame: int in range(90):
		if player.active_ability_action == null:
			break
		await _step()
	_assert(player.active_ability_action == null and _clean_x_state(), "Normal completion clears all X state")
	_assert(player.is_on_floor() and not recovery_airborne, "Recovery completes on physical floor")
	_assert(max_step < 0.6, "Takeoff/dive contain no teleport-sized frame displacement")
	_assert(player.combat_state == PlayerController.CombatState.IDLE or player.combat_state == PlayerController.CombatState.RUN, "Normal combat state restored")
	var stamina_after_x: float = player.stamina_component.current_stamina
	_assert(player.ability_system.is_on_cooldown("skill_2") and not player._try_cast_ability("skill_2") and player.stamina_component.current_stamina == stamina_after_x, "X cooldown remains authoritative after recovery")
	await _step(2)
	_assert(player.combat_state != PlayerController.CombatState.ATTACK, "Held confirmation does not become a stale normal attack")
	_input("attack", false)
	await _step()
	_input("attack", true)
	await _step()
	_assert(player.combat_state == PlayerController.CombatState.ATTACK and player.combo_step == 1, "Fresh LMB after recovery starts normal Attack 1")
	_input("attack", false)
	await _step(55)
	_assert(player._start_block(), "RMB works after X")
	player._release_block()
	await _step(15)
	_assert(player._try_dodge(), "Q works after X")
	# Wait for the selected dash core, rather than assuming the old 20 ticks.
	for frame: int in range(60):
		if not player.dodge_controller.is_dodging:
			break
		await _step()
	_assert(player._try_cast_ability("skill_1"), "Z remains usable after X")
	if player.active_ability_action:
		player.active_ability_action.cancel()

	# Entry-frame edge: inject before the physics frame that enters AIM.
	await _new_player()
	await _cast()
	player.set_third_person(false)
	entry_press_sent = false
	entry_press_pending = true
	if not await _wait_phase(2):
		quit(1)
		return
	_assert(entry_press_sent and entry_press_frame == player._sky_dive_aim_entry_frame and Input.is_action_pressed("attack"), "LMB injected on actual AIM entry frame")
	await _step(3)
	_assert(player._sky_dive_sub_phase == 2, "AIM-entry-frame press and its held state are rejected")
	_input("attack", false)
	await _step()
	player._camera_yaw = -0.8
	player._camera_pitch = -1.0
	player._update_camera_rotation()
	_input("attack", true)
	await _step()
	_assert(player._sky_dive_sub_phase == 3 and player._sky_dive_direction.dot(first_direction) < 0.85, "Changed camera orientation materially changes confirmed dive")
	# Attempt to end while airborne must not enter recovery.
	var active_action: AbilityAction = player.active_ability_action
	player._sky_dive_end_dive(active_action)
	_assert(player._sky_dive_sub_phase == 3 and active_action.current_phase == AbilityAction.Phase.ACTIVE, "Airborne end request cannot fake landing")
	active_action.cancel()
	_assert(player.active_ability_action == null and _clean_x_state(), "Cancellation clears X state")
	_assert(player.velocity == Vector3.ZERO and player.anim_player.current_animation != "Knight_X_SkyDive", "Cancellation releases movement and animation ownership")

	# Death and actual respawn, rather than resetting internal test fields.
	await _new_player()
	await _cast()
	if not await _wait_phase(2):
		quit(1)
		return
	# A press delivered after entry but within that same physics frame is stale too.
	_assert(Engine.get_physics_frames() == player._sky_dive_aim_entry_frame, "Post-transition entry-frame input fixture is exact")
	_input("attack", true)
	await _step(2)
	_assert(player._sky_dive_sub_phase == 2, "Press after transition on AIM entry frame remains rejected")
	_input("attack", false)
	await _step()
	player.take_damage(9999.0)
	_assert(player.is_dead and player.active_ability_action == null and _clean_x_state(), "Death cancels and clears X")
	player.respawn(Vector3(0.0, 0.1, 0.0))
	await _step(4)
	_assert(not player.is_dead and player.health_component.current_health == player.health_component.max_health and _clean_x_state(), "Actual respawn restores health/combat and clears X")
	_assert(player.anim_player.current_animation != "Knight_X_SkyDive", "Respawn releases X animation ownership")
	_input("attack", true)
	await _step()
	_assert(player.combat_state == PlayerController.CombatState.ATTACK, "Respawn has no stale confirmation intercept")
	_assert(finite_motion and player.global_position.is_finite() and player.velocity.is_finite(), "Position and velocity remain finite")
	_input("attack", false)
	await _step(24)
	player.stamina_component.current_stamina = 100.0
	await _cast()
	_assert(player.combat_state == PlayerController.CombatState.IDLE and player.combo_step == 0, "X from attack follow-through does not leave a stale ATTACK state")
	if player.active_ability_action:
		player.active_ability_action.cancel()
	_assert(_clean_x_state() and player.anim_player.current_animation != "Knight_X_SkyDive", "Startup cancellation clears X and returns animation ownership")
	await _new_player()
	_assert(player._start_block(), "Block setup for X transition")
	await _cast()
	_assert(not player.is_blocking and player.anim_player.current_animation == "Knight_X_SkyDive", "X from block owns its animation without stale block release")
	if player.active_ability_action:
		player.active_ability_action.cancel()
	# Landing impact must use actual collision/query results, not just movement.
	await _new_player()
	var dummy_scene: PackedScene = load("res://scenes/TrainingDummy.tscn") as PackedScene
	var impact_targets: Array[TrainingDummy] = []
	for offset: Vector3 in [Vector3(-2.0, 0.0, -1.0), Vector3(2.0, 0.0, -1.0), Vector3(8.0, 0.0, -1.0)]:
		var target: TrainingDummy = dummy_scene.instantiate() as TrainingDummy
		arena.add_child(target)
		target.global_position = offset
		impact_targets.append(target)
	await _step(3)
	var initial_hp: float = impact_targets[0].health_component.current_health
	await _cast()
	if not await _wait_phase(2):
		quit(1)
		return
	await _step(10)
	_assert(impact_targets[0].health_component.current_health == initial_hp and impact_targets[1].health_component.current_health == initial_hp, "X deals no early damage during takeoff/AIM")
	player._camera_pitch = -1.3
	player._camera_yaw = 0.0
	_input("attack", true)
	await _step()
	_input("attack", false)
	await _step(2)
	_assert(impact_targets[0].health_component.current_health == initial_hp, "Airborne dive deals no early landing damage")
	if not await _wait_phase(4):
		quit(1)
		return
	_assert(impact_targets[0].health_component.current_health == initial_hp - 35.0, "Physical X landing deals configured 35 damage")
	_assert(impact_targets[1].health_component.current_health == initial_hp - 35.0, "Landing AOE also hits a second target on the opposite side")
	_assert(impact_targets[2].health_component.current_health == initial_hp, "Landing AOE leaves out-of-range targets unharmed")
	var landing_action: AbilityAction = player.active_ability_action
	player._sky_dive_end_dive(landing_action)
	await _step(40)
	_assert(impact_targets[0].health_component.current_health == initial_hp - 35.0 and impact_targets[1].health_component.current_health == initial_hp - 35.0, "Repeated landing request/recovery never duplicates damage")
	_assert(player.stamina_component.current_stamina == 75.0, "Landing does not refund X stamina as a basic attack")
	_assert(player.active_ability_action == null and _clean_x_state(), "Damaging landing completes normal recovery and cleanup")
	monitor_movement = false
	_input("attack", false)
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed, passed + failed, failed])
	quit(1 if failed > 0 else 0)
