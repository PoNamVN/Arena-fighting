extends SceneTree

var passed: int = 0
var failed: int = 0
var arena: Node3D
var player: PlayerController
var targets: Array[TrainingDummy] = []
var hits: int = 0
var feedbacks: int = 0
var budget: int = 2600


func _initialize() -> void:
	call_deferred("_run")
	physics_frame.connect(func() -> void:
		budget -= 1
		if budget <= 0:
			push_error("V test timed out")
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
	for action: StringName in [&"ultimate", &"attack", &"block", &"move_forward"]:
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
	feedbacks = 0
	player.combat.hit_landed.connect(func(_target: Node, _damage: float, _blocked: bool) -> void: hits += 1)
	player.combat.combat_feedback.audio_ultimate_used.connect(func() -> void: feedbacks += 1)
	for target: TrainingDummy in targets:
		target.health_component.current_health = 100.0


func _click_point(point: Vector3) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = player.giant_sword_ultimate.cinematic_camera.unproject_position(point)
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _step()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _cast(confirm: bool = true, point: Vector3 = Vector3.ZERO) -> void:
	_input("ultimate", true)
	await _step()
	_assert(player.active_ability_action != null and player.active_ability_action.data.id == "giant_sword_ultimate" and player.giant_sword_ultimate.aiming, "V opens targeting mode")
	if confirm:
		await _step(30)
		await _click_point(point)
		_assert(not player.giant_sword_ultimate.aiming and player.active_ability_action.current_phase == AbilityAction.Phase.STARTUP, "Real LMB ray confirms a ground target and starts descent")


func _wait_active() -> bool:
	for frame: int in range(180):
		if player.active_ability_action and player.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE:
			return true
		await _step()
	_assert(false, "V never reached ACTIVE")
	return false


func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(40, 1, 40)
	floor_shape.shape = floor_box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	var wall: StaticBody3D = StaticBody3D.new()
	var wall_shape: CollisionShape3D = CollisionShape3D.new()
	var wall_box: BoxShape3D = BoxShape3D.new()
	wall_box.size = Vector3(0.2, 3, 1.2)
	wall_shape.shape = wall_box
	wall.position = Vector3(1, 1, 0)
	wall.add_child(wall_shape)
	arena.add_child(wall)
	for offset: Vector3 in [Vector3(0, 0, -2), Vector3(0, 0, 3.8), Vector3(-4.4, 0, 0), Vector3(2, 0, 0), Vector3(-4.6, 0, 0), Vector3(0, 4, 0)]:
		var target: TrainingDummy = load("res://scenes/TrainingDummy.tscn").instantiate() as TrainingDummy
		arena.add_child(target)
		target.position = offset
		targets.append(target)
	await _new_player()
	# A held LMB from the prior attack cannot confirm the new ultimate.
	_input("attack", true)
	await _step(24)
	await _cast(false)
	await _step(70)
	_assert(player.giant_sword_ultimate.aiming and not player.combat.giant_sword_vfx.sword.visible, "Held LMB before V cannot auto-confirm")
	_input("attack", false)
	await _step()
	await _click_point(Vector3.ZERO)
	_assert(not player.giant_sword_ultimate.aiming and player.active_ability_action.custom_data.has("impact_origin"), "Fresh LMB after release confirms normally")
	player.active_ability_action.cancel()
	await _new_player()
	# AIM must not progress until a fresh click; invalid surfaces cannot commit.
	var original_camera: Camera3D = player.camera
	var original_mouse_mode: int = Input.mouse_mode
	await _cast(false)
	await _step(180)
	_assert(player.giant_sword_ultimate.aiming and player.active_ability_action.current_phase == AbilityAction.Phase.STARTUP and hits == 0, "Aiming freezes ability timeline without timeout or damage")
	_assert(player.giant_sword_ultimate.cinematic_camera.current and player.giant_sword_ultimate.cinematic_camera.global_position.distance_to(player.global_position) > 30 and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "V zooms out and frees cursor for selection")
	_assert(not player.combat.giant_sword_vfx.sword.visible, "Sword does not appear before selection")
	await _click_point(Vector3(1, 1, 0.5))
	_assert(player.giant_sword_ultimate.aiming, "Clicking vertical wall cannot commit")
	await _click_point(Vector3(30, 0, 0))
	_assert(player.giant_sword_ultimate.aiming, "Off-map/out-of-range click cannot commit")
	_input("ui_cancel", true)
	await _step()
	_input("ui_cancel", false)
	_assert(player.active_ability_action == null and original_camera.current and Input.mouse_mode == original_mouse_mode and player._is_mouse_captured and player.stamina_component.current_stamina == 100, "ESC during aim restores camera/cursor and returns stamina reservation")
	await _new_player()
	var data: AbilityData = player.ability_system.get_ability("ultimate")
	_assert(data.damage == 90 and data.range == 4.5 and data.requires_full_stamina and data.stamina_cost == 100 and data.cooldown == 0, "V preserves Knight tuning")
	_assert(player.anim_player.has_animation("Knight_V_GiantSword") and is_equal_approx(player.anim_player.get_animation("Knight_V_GiantSword").length, 1.7), "Authored V clip is reused with fall-time playback scaling")
	player.stamina_component.current_stamina = 99
	_input("ultimate", true)
	await _step()
	_assert(player.active_ability_action == null and player.stamina_component.current_stamina == 99 and not player.combat.giant_sword_vfx.visible, "99 stamina rejects V without effects or spending")
	_input("ultimate", false)
	await _step()
	player.stamina_component.current_stamina = 100
	await _cast()
	_assert(player.stamina_component.current_stamina == 0 and not player.ability_system.is_on_cooldown("ultimate"), "V spends all stamina once without cooldown")
	_assert(player.anim_player.current_animation == "Knight_V_GiantSword" and player.combat.giant_sword_vfx.visible, "Startup owns clip and sword telegraph")
	var origin: Vector3 = player.global_position
	var sword_height: float = player.combat.giant_sword_vfx.sword.position.y
	var child_count: int = player.combat.giant_sword_vfx.get_child_count()
	_input("move_forward", true)
	await _step(60)
	_assert(player.combat.giant_sword_vfx.sword.position.y < sword_height and player.combat.giant_sword_vfx.sword.position.y > 0, "Sword descends during startup")
	_assert(hits == 0 and feedbacks == 0 and targets[0].current_hp == 100, "No early damage or ultimate impact audio")
	_assert(player.global_position.distance_to(origin) < 0.02, "WASD is locked while casting")
	_assert(not player._try_combat_attack() and not player._start_block() and not player._try_dodge() and not player._try_cast_ability("skill_3"), "LMB/RMB/Q/C cannot interrupt V")
	if not await _wait_active():
		quit(1)
		return
	_assert(targets[0].current_hp == 10 and targets[1].current_hp == 10 and targets[2].current_hp == 10, "V hits front/rear/near-edge targets for 90")
	_assert(targets[3].current_hp == 100 and targets[4].current_hp == 100 and targets[5].current_hp == 100, "Wall, range and vertical separation reject targets")
	_assert(hits == 3 and feedbacks == 1 and is_equal_approx(player.combat.giant_sword_vfx.sword.position.y, -0.4), "One impact/audio occurs exactly when sword lands")
	_assert(not player.combat.whirling_blade_vfx.visible, "V does not trigger C spin effect")
	player.combat.execute_radial_ability_impact(data, player.active_ability_action)
	_assert(hits == 3 and feedbacks == 1, "Retry cannot duplicate damage or ultimate feedback")
	await _step(145)
	_input("move_forward", false)
	_input("ultimate", false)
	_assert(player.active_ability_action == null and player.anim_player.current_animation != "Knight_V_GiantSword" and not player.combat.giant_sword_vfx.visible, "Recovery releases action, animation and effects")
	_assert(player.combat.giant_sword_vfx.get_child_count() == child_count and hits == 3, "Held V never repeats or accumulates visual nodes")
	_assert(player.stamina_component.current_stamina == 0 and not player._try_cast_ability("ultimate"), "AOE does not refund stamina; empty bar blocks another V")
	_assert(player._try_combat_attack(), "LMB is restored after V")
	await _new_player()
	await _cast()
	player.active_ability_action.cancel()
	await _step(55)
	_assert(targets[0].current_hp == 100 and hits == 0 and feedbacks == 0, "Startup cancellation prevents delayed impact")
	_assert(player.active_ability_action == null and not player.combat.giant_sword_vfx.visible and player.stamina_component.current_stamina == 0, "Cancellation cleans up without refund")
	await _new_player()
	await _cast()
	player.take_damage(9999.0)
	await _step(55)
	_assert(player.is_dead and player.active_ability_action == null and not player.combat.giant_sword_vfx.visible and hits == 0, "Death cancels V, remains terminal and prevents impact")
	player.respawn(Vector3(0, 0.1, 0))
	await _step(4)
	_assert(player._start_block(), "Respawn restores RMB")
	await _new_player()
	player.set_third_person(false)
	targets[1].is_blocking = true
	var shield_before: float = targets[1].shield_durability
	await _cast()
	if not await _wait_active():
		quit(1)
		return
	_assert(is_equal_approx(targets[1].current_hp, 86.5) and targets[1].shield_durability == shield_before - 15, "V respects frontal block and shared shield damage")
	var skeleton: Skeleton3D = player.visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	_assert(skeleton.get_bone_pose_scale(skeleton.find_bone("head")).x > 0.99, "Cinematic camera temporarily shows FPS player head")
	player.active_ability_action.cancel()
	await _step(3)
	_assert(skeleton.get_bone_pose_scale(skeleton.find_bone("head")).x < 0.001 and not player.is_third_person and player.camera.current, "Cancellation restores FPS camera and head mask")
	_assert(player._try_dodge(), "ACTIVE cancellation restores Q")
	await _new_player()
	await _cast()
	# Knockback may move the caster, but the telegraphed impact remains fixed.
	origin = player.active_ability_action.custom_data["impact_origin"]
	player._knockback_timer = 0.1
	player._knockback_vel = Vector3(0, 0, 4)
	await _step(20)
	_assert(player.global_position.distance_to(origin) < 0.02 and player.combat.giant_sword_vfx.global_position.distance_to(origin) < 0.02 and paused, "Cinematic freezes caster knockback and preserves selected telegraph position")
	if not await _wait_active():
		quit(1)
		return
	_assert(targets[2].current_hp == 10 and targets[4].current_hp == 100, "Damage range follows telegraph origin after caster moves")
	player.active_ability_action.cancel()
	await _new_player()
	var receiver: PlayerController = load("res://scenes/Player.tscn").instantiate() as PlayerController
	arena.add_child(receiver)
	receiver.global_position = Vector3(0, 0.1, -1.2)
	receiver.collision_layer = 4
	receiver.set_process_unhandled_input(false)
	await _step(4)
	receiver.set_physics_process(false)
	receiver.stamina_component.current_stamina = 0
	await _cast(false)
	await _step(30)
	_assert(receiver.dodge_controller.start_dodge(), "Receiver starts dodge before committed world freeze")
	await _step(5)
	_assert(receiver.is_in_dodge_iframe(), "Pre-existing i-frame is active when target is confirmed")
	await _click_point(Vector3.ZERO)
	if not await _wait_active():
		quit(1)
		return
	_assert(receiver.health_component.current_health == 100 and receiver.dodge_controller.perfect_dodge_count == 1 and receiver.dodge_controller.counter_window_active, "V respects dodge i-frame and opens Perfect Dodge/Counter once")
	player.combat.execute_radial_ability_impact(data, player.active_ability_action)
	_assert(receiver.dodge_controller.perfect_dodge_count == 1, "Retry cannot re-award Perfect Dodge")
	player.active_ability_action.cancel()
	receiver.queue_free()
	# Remote selection must damage around the selected point, not caster.
	await _new_player()
	await _cast(true, Vector3(0, 0, 8))
	_assert(player.active_ability_action.custom_data["impact_origin"].distance_to(Vector3(0, 0, 8)) < 0.05, "Mouse ray stores exact remote impact origin")
	if not await _wait_active():
		quit(1)
		return
	_assert(targets[0].current_hp == 100 and targets[1].current_hp == 10, "Remote AOE is centered on clicked location")
	_assert(player.giant_sword_ultimate._shake_timer > 0 and player.combat.giant_sword_vfx.shockwave.visible and player.combat.giant_sword_vfx._debris_batch.visible_instance_count == 32, "Impact triggers camera shake, shockwave and batched debris")
	await _step(70)
	_assert(float(player.combat.giant_sword_vfx._sword_materials[0].get_shader_parameter("dissolve")) > 0, "Solid sword dissolves only after impact")
	await _step(75)
	_assert(player.camera.current and not player.combat.giant_sword_vfx.visible, "Natural completion restores gameplay camera and hides effects")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed, passed + failed, failed])
	quit(1 if failed > 0 else 0)
