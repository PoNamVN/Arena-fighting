extends SceneTree

var passed: int = 0
var failed: int = 0
var arena: Node3D
var player: PlayerController
var targets: Array[TrainingDummy] = []
var budget: int = 1500
var hits: int = 0


func _initialize() -> void:
	call_deferred("_run")
	physics_frame.connect(func() -> void:
		budget -= 1
		if budget <= 0:
			push_error("C test timed out")
			quit(1)
	)


func _assert(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[PASS] " + label)
	else:
		failed += 1
		push_error("[FAIL] " + label)


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


func _new_player() -> void:
	for action: StringName in [&"skill_3", &"attack", &"block", &"move_forward"]:
		_input(action, false)
	if is_instance_valid(player):
		player.queue_free()
		await _step(2)
	player = load("res://scenes/Player.tscn").instantiate() as PlayerController
	arena.add_child(player)
	player.position.y = 0.1
	await _step(4)
	player.stamina_component.current_stamina = 100.0
	hits = 0
	player.combat.hit_landed.connect(func(_target: Node, _damage: float, _blocked: bool) -> void: hits += 1)


func _cast() -> void:
	_input("skill_3", true)
	await _step()
	_assert(player.active_ability_action != null and player.active_ability_action.data.id == "whirling_blade", "C input activates Whirling Blade")


func _wait_active() -> bool:
	for frame: int in range(20):
		if player.active_ability_action and player.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE:
			return true
		await _step()
	_assert(false, "C never reached ACTIVE")
	return false


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = floor_box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	var wall: StaticBody3D = StaticBody3D.new()
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(0.2, 3.0, 1.2)
	wall_shape.shape = wall_box
	wall.position = Vector3(1.0, 1.0, 0.0)
	wall.add_child(wall_shape)
	arena.add_child(wall)
	for offset: Vector3 in [Vector3(0, 0, -2), Vector3(0, 0, 2), Vector3(-2, 0, 0), Vector3(2, 0, 0), Vector3(5, 0, 0), Vector3(0, 4, 0)]:
		var target: TrainingDummy = load("res://scenes/TrainingDummy.tscn").instantiate() as TrainingDummy
		arena.add_child(target)
		target.position = offset
		targets.append(target)
	await _new_player()
	var data: AbilityData = player.ability_system.get_ability("skill_3")
	_assert(data.damage == 30.0 and data.range == 3.0 and data.stamina_cost == 30.0 and data.cooldown == 5.0, "C preserves existing Knight tuning")
	_assert(player.anim_player.has_animation("Knight_C_WhirlingBlade"), "Authored C clip is installed on the existing AnimationPlayer")
	_assert(is_equal_approx(player.anim_player.get_animation("Knight_C_WhirlingBlade").length, 0.9), "C clip matches 0.15/0.45/0.30 lifecycle")
	player.stamina_component.current_stamina = 29.0
	_input("skill_3", true)
	await _step()
	_assert(player.active_ability_action == null and player.stamina_component.current_stamina == 29.0, "Insufficient stamina rejects C without spending")
	_input("skill_3", false)
	await _step()
	player.stamina_component.current_stamina = 100.0
	await _cast()
	_assert(player.stamina_component.current_stamina == 70.0, "C spends stamina exactly once")
	_assert(player.ability_system.get_cooldown_remaining("skill_3") > 4.9, "C starts its five-second cooldown once")
	_assert(player.anim_player.current_animation == "Knight_C_WhirlingBlade", "C owns its authored animation")
	await _step(3)
	_assert(targets[0].current_hp == 100.0 and targets[1].current_hp == 100.0 and hits == 0, "No early damage/feedback during startup")
	var initial_position: Vector3 = player.global_position
	_input("move_forward", true)
	if not await _wait_active():
		quit(1)
		return
	_assert(targets[0].current_hp == 70.0 and targets[1].current_hp == 70.0 and targets[2].current_hp == 70.0, "C hits front, rear and side targets for 30 damage")
	_assert(targets[3].current_hp == 100.0, "C cannot hit through a wall")
	_assert(targets[4].current_hp == 100.0 and targets[5].current_hp == 100.0, "Out-of-range/elevated targets remain unharmed")
	_assert(hits == 3, "Exactly one hit signal per reachable target")
	player.combat.execute_radial_ability_impact(data, player.active_ability_action)
	_assert(hits == 3 and targets[0].current_hp == 70.0, "Repeated impact dispatch cannot damage registered targets again")
	_assert(player.combat.whirling_blade_vfx.visible, "Reusable circular VFX starts at ACTIVE")
	var node_count: int = player.get_child_count()
	var skeleton: Skeleton3D = player.visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	var root_bone: int = skeleton.find_bone("hips")
	var root_rotation: Quaternion = skeleton.get_bone_pose_rotation(root_bone)
	await _step(8)
	_assert(absf(root_rotation.dot(skeleton.get_bone_pose_rotation(root_bone))) < 0.95, "Authored hips rotation produces a real spin with a stationary root")
	_assert(player.global_position.distance_to(initial_position) < 0.02, "WASD cannot move player during C")
	_assert(not player._try_combat_attack() and not player._start_block() and not player._try_dodge() and not player._try_cast_ability("skill_1"), "Combo/block/Q/Z cannot interrupt active C")
	_assert(targets[0].current_hp == 70.0 and hits == 3, "ACTIVE does not spam per-frame damage")
	_assert(player.stamina_component.current_stamina == 70.0, "C hits do not refund basic-attack stamina")
	await _step(50)
	_input("move_forward", false)
	_input("skill_3", false)
	_assert(player.active_ability_action == null and player.anim_player.current_animation != "Knight_C_WhirlingBlade", "Recovery releases ability and animation ownership")
	_assert(not player.combat.whirling_blade_vfx.visible and player.get_child_count() == node_count, "VFX stops without node accumulation")
	var stamina_before: float = player.stamina_component.current_stamina
	_assert(not player._try_cast_ability("skill_3") and player.stamina_component.current_stamina == stamina_before, "Cooldown rejects retrigger without spending")
	_assert(targets[0].current_hp == 70.0 and hits == 3, "Held C never repeats after recovery")
	await _step(2)
	_assert(player._try_combat_attack() and player.combo_step == 1, "Normal LMB combo works after C")

	# Startup cancellation cannot damage, and death remains terminal.
	await _new_player()
	var hp_before: float = targets[0].current_hp
	await _cast()
	player.active_ability_action.cancel()
	await _step(20)
	_assert(targets[0].current_hp == hp_before and player.active_ability_action == null, "Startup cancellation causes no delayed damage")
	_assert(not player.combat.whirling_blade_vfx.visible and player.anim_player.current_animation != "Knight_C_WhirlingBlade", "Cancellation releases C visuals")
	_assert(player.ability_system.is_on_cooldown("skill_3") and player.stamina_component.current_stamina == 70.0, "Cancellation preserves cost and cooldown")
	await _new_player()
	await _cast()
	player.take_damage(9999.0)
	await _step(20)
	_assert(player.is_dead and player.active_ability_action == null and not player.combat.whirling_blade_vfx.visible, "Death cancels C and keeps DEAD state")
	_assert(targets[0].current_hp == hp_before, "Death during startup prevents impact")
	player.respawn(Vector3(0, 0.1, 0))
	await _step(4)
	_assert(player._start_block(), "Respawn restores normal RMB input")
	player._release_block()
	await _step(20)
	_assert(player._try_dodge(), "Q works after C death/respawn")

	# FPS and a frontal blocking target use the same damage/shield pipeline.
	await _new_player()
	player.set_third_person(false)
	targets[1].is_blocking = true
	var blocked_hp: float = targets[1].current_hp
	var shield_before: float = targets[1].shield_durability
	await _cast()
	if not await _wait_active():
		quit(1)
		return
	_assert(is_equal_approx(targets[1].current_hp, blocked_hp - 4.5), "Frontal block reduces C HP damage by 85 percent")
	_assert(targets[1].shield_durability == shield_before - 15.0, "Blocked C applies shield damage once")
	_assert(not player.is_third_person and player.anim_player.current_animation == "Knight_C_WhirlingBlade", "C also runs with FPS camera")
	var fps_skeleton: Skeleton3D = player.visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	_assert(fps_skeleton.get_bone_pose_scale(fps_skeleton.find_bone("head")).x < 0.001, "C preserves FPS head hiding")
	player.active_ability_action.cancel()
	await _step(3)
	_assert(player.active_ability_action == null and player._start_block(), "Cancelling ACTIVE C restores input")

	# Enemy-player receiver: exercise AttackPayload, damage avoidance and counter.
	await _new_player()
	var receiver: PlayerController = load("res://scenes/Player.tscn").instantiate() as PlayerController
	arena.add_child(receiver)
	receiver.global_position = Vector3(0, 0.1, -1.2)
	receiver.collision_layer = 4
	receiver.set_process_unhandled_input(false)
	await _step(4)
	receiver.set_physics_process(false) # Hold the receiver inside AOE while its dodge timing runs.
	receiver.stamina_component.current_stamina = 0.0
	_assert(receiver.dodge_controller.start_dodge(), "Enemy player starts a real dodge lifecycle")
	await _cast()
	if not await _wait_active():
		quit(1)
		return
	_assert(receiver.health_component.current_health == 100.0, "C AttackPayload respects receiver dodge i-frame")
	_assert(receiver.dodge_controller.perfect_dodge_count == 1 and receiver.dodge_controller.counter_window_active, "Dodgeable C opens exactly one Perfect Dodge/Counter window")
	var received_stamina: float = receiver.stamina_component.current_stamina
	player.combat.execute_radial_ability_impact(data, player.active_ability_action)
	_assert(receiver.dodge_controller.perfect_dodge_count == 1 and receiver.stamina_component.current_stamina == received_stamina, "Repeated impact cannot re-award Perfect Dodge")
	player.active_ability_action.cancel()
	receiver.queue_free()
	await _step(2)
	await _new_player()
	_assert(player._start_block(), "Block setup for C transition")
	await _step(15)
	await _cast()
	_assert(not player.is_blocking and player._block_transition == "" and player.anim_player.current_animation == "Knight_C_WhirlingBlade", "C replaces block without stale block animation/state")
	player.active_ability_action.cancel()
	await _new_player()
	_assert(player._try_combat_attack(), "Attack setup for C follow-through transition")
	await _step(24)
	await _cast()
	if not await _wait_active():
		quit(1)
		return
	_assert(player.combat_state != PlayerController.CombatState.ATTACK and player.combo_step == 0, "C replaces attack follow-through without stale combo state")
	var c_skeleton: Skeleton3D = player.visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	var hand_index: int = c_skeleton.find_bone("hand.R")
	_assert(absf(c_skeleton.get_bone_pose_rotation(hand_index).dot(c_skeleton.get_bone_rest(hand_index).basis.get_rotation_quaternion())) > 0.999, "C restores the authored wrist pose after a basic attack")
	player.active_ability_action.cancel()
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed, passed + failed, failed])
	quit(1 if failed > 0 else 0)
