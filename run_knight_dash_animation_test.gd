extends SceneTree

class CounterTarget extends Node3D:
	func take_damage(_payload: Variant) -> void:
		pass

var passes := 0
var failures := 0
var p: PlayerController
var presentation: Node

func _init() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	if ok:
		passes += 1
		print("[PASS] ", message)
	else:
		failures += 1
		print("[FAIL] ", message)

func fixture() -> void:
	if is_instance_valid(p):
		p.free()
	p = load("res://scenes/Player.tscn").instantiate()
	p.external_controlled = true
	root.add_child(p)
	await process_frame
	await process_frame
	presentation = p.get_node("KnightDashPresentation")
	p.global_position = Vector3.ZERO
	p.visuals.rotation.y = 0.0
	p._camera_yaw = 0.0
	p.external_move_direction = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.combat_state = PlayerController.CombatState.IDLE

func start_tail() -> void:
	await fixture()
	check(p._try_dodge(), "dash starts through original controller")
	for i in range(25):
		await physics_frame
	check(not p.dodge_controller.is_dodging and p.combat_state == PlayerController.CombatState.IDLE, "control returns at end of 0.40s core")
	check(presentation.active and presentation.tail_active, "recovery continues with no input")

func run_tests() -> void:
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(200, 1, 200)
	floor_collision.shape = floor_box
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	floor_body.position.y = -0.5
	var imported: Node = load("res://assets/models/knight_k3_dash_extended.glb").instantiate()
	var ap: AnimationPlayer = imported.get_node("AnimationPlayer")
	check(ap.get_animation_list().size() == 18, "GLB contains 18 clips")
	var skeleton: Skeleton3D = imported.get_node("Gladiator_Armature/Skeleton3D")
	check(skeleton.get_bone_count() == 19, "import retains 19 bones")
	var meshes := imported.find_children("*", "MeshInstance3D", true, false)
	var triangles := 0
	var surfaces := 0
	for mesh_instance: MeshInstance3D in meshes:
		surfaces += mesh_instance.mesh.get_surface_count()
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
	check(meshes.size() == 3 and triangles == 2666 and surfaces == 13, "import retains 3 meshes, 2666 triangles and 13 surfaces")
	for clip in [&"dash_forward", &"dash_back", &"dash_left", &"dash_right"]:
		var length := 0.60 if clip == &"dash_back" else 0.55
		check(ap.has_animation(clip) and absf(ap.get_animation(clip).length - length) < 0.00001, "%s has exact %.2fs length" % [clip, length])
	for clip in ["dash_back", "dash_left", "dash_right"]:
		var animation: Animation = ap.get_animation(clip)
		var angles: Array[float] = []
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and String(animation.track_get_path(track)).ends_with(":hips"):
				var previous := 0.0
				for sample in range(37):
					var q: Quaternion = animation.rotation_track_interpolate(track, sample / 60.0)
					var angle := 2.0 * atan2(q.x if clip == "dash_back" else q.y, q.w)
					if clip == "dash_left":
						angle = -angle
					while angle - previous > PI:
						angle -= TAU
					while angle - previous < -PI:
						angle += TAU
					angles.append(angle)
					previous = angle
		var monotonic := angles.size() == 37
		for sample in range(1, angles.size()):
			monotonic = monotonic and angles[sample] - angles[sample - 1] >= -0.000002
		check(monotonic and absf(angles[27 if clip == "dash_back" else 24] - angles[0] - TAU) < 0.000002, "%s completes 360 degrees by the directional core end without reversing" % clip)
	imported.free()
	await fixture()
	var directions := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	var clips := [&"dash_forward", &"dash_back", &"dash_left", &"dash_right"]
	for yaw in [0.0, PI * 0.5]:
		for i in range(4):
			await fixture()
			p.visuals.rotation.y = yaw
			var heading_basis := Basis(Vector3.UP, yaw)
			p.external_move_direction = heading_basis * directions[i]
			check(p._try_dodge(), "directional dash starts")
			check(presentation.selected_clip == clips[i] and p.anim_player.current_animation == clips[i], "world direction selects %s relative to heading %.2f" % [clips[i], yaw])
			check(absf(p.dodge_controller.dodge_duration - (0.45 if clips[i] == &"dash_back" else 0.40)) < 0.000001, "duration matches facing-selected dash at either camera yaw")
			check(p.dodge_controller.world_direction.distance_to(p.external_move_direction) < 0.00001, "animation leaves original movement direction unchanged")
			for frame in range(3):
				await physics_frame
			check(absf(wrapf(presentation.model.global_rotation.y - yaw, -PI, PI)) < 0.00001, "model keeps captured heading while Visuals auto-faces")
	check(presentation.select_clip(Vector3(0.4, 0, -0.9), Basis.IDENTITY) == &"dash_forward", "dominant component selects forward")
	check(presentation.select_clip(Vector3(-0.9, 0, 0.4), Basis.IDENTITY) == &"dash_left", "dominant component selects left")
	await start_tail()
	check(p.anim_player.current_animation == "dash_forward", "tail retains the dash clip")
	for frame in range(12):
		await physics_frame
	check(not presentation.active and p.anim_player.current_animation == "idle", "uninterrupted tail finishes and restores idle")
	await start_tail()
	p.external_move_direction = Vector3.RIGHT
	await physics_frame
	await process_frame
	check(not presentation.active and p.anim_player.current_animation == "run", "movement resumes immediately with recovery blended into run")
	check(presentation.movement_blend_remaining > 0.0 and presentation.movement_blend_remaining <= 0.15, "movement keeps a 0.15s outgoing recovery mix")
	check(p._try_combat_attack(), "attack is accepted during the movement recovery mix")
	check(presentation.movement_blend_remaining == 0.0 and p.anim_player.current_animation.begins_with("attack"), "attack clears outgoing recovery without replacing the attack")
	for action in [&"attack", &"block", &"dodge", &"skill_1", &"skill_2", &"skill_3", &"ultimate"]:
		await start_tail()
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		presentation._unhandled_input(event)
		check(not presentation.active and not presentation.tail_active, "%s cuts recovery in the same call" % action)
	await start_tail()
	check(p._try_combat_attack(), "attack is available during recovery")
	check(not presentation.active and p.anim_player.current_animation.begins_with("attack"), "attack replaces tail without being overwritten")
	await start_tail()
	check(p._start_block(), "block is available during recovery")
	check(not presentation.active and p.anim_player.current_animation.begins_with("block"), "block replaces tail without being overwritten")
	await start_tail()
	p.dodge_controller._cooldown_timer = 0.0 # Fixture only: no production cooldown change.
	check(p._try_dodge() and presentation.active and not presentation.tail_active, "another accepted dash replaces recovery")
	await start_tail()
	check(p._try_cast_ability("skill_1"), "Z remains castable during recovery")
	await process_frame
	check(not presentation.active and p.active_ability_action != null, "skill owns its animation after tail cancellation")
	await start_tail()
	p.transition_to(PlayerController.CombatState.DEAD)
	check(not presentation.active, "death cancels recovery immediately")
	await start_tail()
	p.controls_enabled = false
	presentation._process(0.0)
	check(not presentation.active, "disabled controls cancel recovery")
	check(absf(presentation.FADE - 0.07) < 0.000001, "recovery cancellation fades within 0.08s")
	for hero in ["archer", "wizard"]:
		p.free()
		p = load("res://scenes/Player.tscn").instantiate()
		p.hero_profile = hero
		p.external_controlled = true
		root.add_child(p)
		await process_frame
		await process_frame
		check(absf(p.dodge_controller.dodge_duration - 0.25) < 0.000001, "%s retains its old 0.25s dodge" % hero)
	for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		await fixture()
		p.external_move_direction = direction
		check(p._try_dodge(), "held-input orientation fixture starts")
		var maximum_heading_error := 0.0
		for frame in range(42):
			await physics_frame
			await process_frame
			maximum_heading_error = maxf(maximum_heading_error, absf(wrapf(presentation.model.global_rotation.y, -PI, PI)))
		check(maximum_heading_error < 0.00001, "model never counter-snaps while held input changes from dash to run")
	var old_rate := Engine.physics_ticks_per_second
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		await fixture()
		p.set_physics_process(false)
		p.set_process(false)
		p.dodge_controller.set_physics_process(false)
		await physics_frame
		await physics_frame
		p.global_position = Vector3.ZERO
		p.external_move_direction = Vector3.LEFT
		check(p._try_dodge(), "distance fixture starts at %d Hz" % rate)
		p.external_move_direction = Vector3.ZERO
		var start := p.global_position
		var tick := 0
		var iframe_ticks: Array[int] = []
		while p.dodge_controller.is_dodging and tick < rate:
			await physics_frame
			p._physics_process(1.0 / rate)
			p.dodge_controller._physics_process(1.0 / rate)
			tick += 1
			if p.dodge_controller.is_in_iframe():
				iframe_ticks.append(tick)
		check(absf(p.global_position.distance_to(start) - 5.0) < 0.0001, "dash travels exactly 5.0m at %d Hz, including partial final tick" % rate)
		check(not p.dodge_controller.is_dodging and p.combat_state == PlayerController.CombatState.IDLE and absf(p.dodge_controller._timer - 0.40) <= 1.0 / rate, "control returns within one physics tick of 0.40s at %d Hz" % rate)
		check(p.dodge_controller.iframe_start == 0.05 and p.dodge_controller.iframe_end == 0.20 and p.dodge_controller.counter_window_duration == 0.6 and p.dodge_controller.cooldown == 1.0 and p.dodge_controller.stamina_cost == 0.0, "locked iframe/counter/cooldown/cost remain unchanged")
		if rate == 60:
			check(iframe_ticks == [3,4,5,6,7,8,9,10,11,12], "60 Hz iframe tick log remains identical to the old dash")
	for rate in [30, 60, 120]:
		Engine.physics_ticks_per_second = rate
		await fixture()
		p.set_physics_process(false)
		p.set_process(false)
		p.dodge_controller.set_physics_process(false)
		await physics_frame
		await physics_frame
		p.global_position = Vector3.ZERO
		p.external_move_direction = Vector3.BACK
		check(p._try_dodge(), "backflip starts at %d Hz" % rate)
		p.external_move_direction = Vector3.ZERO
		var start := p.global_position
		var tick := 0
		while p.dodge_controller.is_dodging and tick < rate:
			await physics_frame
			p._physics_process(1.0 / rate)
			p.dodge_controller._physics_process(1.0 / rate)
			tick += 1
		# move_and_slide floor recovery accumulates ~0.12mm over 54 ticks at 120Hz.
		# A 0.25mm bound still rejects any meaningful distance/timing regression.
		check(absf(p.global_position.distance_to(start) - 5.0) < 0.00025, "backflip travels exactly 5.0m at %d Hz (actual %.7f, ticks %d)" % [rate, p.global_position.distance_to(start), tick])
		check(absf(p.dodge_controller._timer - 0.45) <= 1.0 / rate and p.combat_state == PlayerController.CombatState.IDLE, "backflip control returns at 0.45s within one physics tick")
		check(presentation.selected_clip == &"dash_back" and absf(p.anim_player.get_animation("dash_back").length - 0.60) < 0.00001, "backflip presentation matches its longer gameplay core")
	Engine.physics_ticks_per_second = old_rate
	for direction in [Vector3.FORWARD, Vector3.BACK]:
		await fixture()
		p.external_move_direction = direction
		check(p._try_dodge(), "real Perfect Dodge fixture starts")
		p.external_move_direction = Vector3.ZERO
		var target := CounterTarget.new()
		root.add_child(target)
		target.add_to_group("targets")
		target.global_position = direction * 6.0
		for frame in range(6):
			await physics_frame
		check(p.dodge_controller.register_perfect_dodge(), "real Perfect Dodge registers inside unchanged iframe window")
		var registered_at := p.dodge_controller._timer
		while p.dodge_controller.is_dodging:
			await physics_frame
		check(p.dodge_controller.counter_window_active and absf(p.dodge_controller._counter_timer - (0.6 - p.dodge_controller._timer + registered_at)) < 0.00001, "0.6s counter window retains its original clock after the longer dash")
		check(p.try_counter_attack(true) and p.combat_state == PlayerController.CombatState.COUNTER, "Perfect Dodge counter is accepted immediately after the longer core")
		check(not presentation.active and not presentation.tail_active, "counter action cuts recovery immediately")
		target.free()
	p.free()
	print("SUMMARY: %d/%d TESTS PASSED" % [passes, passes + failures])
	quit(1 if failures else 0)
