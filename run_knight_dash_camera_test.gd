extends SceneTree

var passes := 0
var failures := 0
var p: PlayerController
var presentation: Node
var follow: Node

func _init() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
		print("[PASS] ", label)
	else:
		failures += 1
		print("[FAIL] ", label)

func fixture(fps: bool = true, hero: String = "knight") -> void:
	if is_instance_valid(p):
		p.free()
	p = load("res://scenes/Player.tscn").instantiate()
	p.external_controlled = true
	p.hero_profile = hero
	root.add_child(p)
	await process_frame
	await process_frame
	p.set_physics_process(false)
	p.set_process(false)
	p.dodge_controller.set_physics_process(false)
	p.global_position = Vector3.ZERO
	p.visuals.rotation = Vector3.ZERO
	p._camera_yaw = 0.0
	p._camera_pitch = 0.0
	p._update_camera_rotation()
	p.set_third_person(not fps)
	p.camera.make_current()
	presentation = p.get_node("KnightDashPresentation")
	presentation.set_process(false)
	presentation.set_physics_process(false)
	follow = presentation.get_node("KnightDashCamera")
	follow.set_process(false)

func start(direction: Vector3) -> void:
	p.external_move_direction = direction
	check(p._try_dodge(), "dash starts through the unchanged gameplay API")
	p.external_move_direction = Vector3.ZERO
	p.anim_player.advance(0.08) # Complete nested FSM/entry blends before independent pose samples.
	follow._process(0.025)

func sample(frame: int) -> void:
	p.anim_player.seek(frame / 60.0, true)
	p._skeleton.force_update_all_bone_transforms()
	follow._process(1.0 / 60.0)

func visible_head_reference() -> Transform3D:
	# Obtain an independent engine Skeleton3D reference with only FPS hiding removed.
	var sk := p._skeleton
	var h := sk.find_bone("head")
	var n := sk.find_bone("neck")
	var hs := sk.get_bone_pose_scale(h)
	var ns := sk.get_bone_pose_scale(n)
	sk.set_bone_pose_scale(h, Vector3.ONE)
	sk.set_bone_pose_scale(n, Vector3.ONE)
	sk.force_update_all_bone_transforms()
	var head_world := sk.global_transform * sk.get_bone_global_pose(h)
	var rest_world := sk.global_transform * sk.get_bone_global_rest(h)
	var target := head_world * rest_world.affine_inverse() * p.camera.global_transform
	var hips := sk.find_bone("hips")
	var hips_world := sk.global_transform * sk.get_bone_global_pose(hips)
	var hips_rest_world := sk.global_transform * sk.get_bone_global_rest(hips)
	target.basis = hips_world.basis.orthonormalized() * hips_rest_world.basis.orthonormalized().inverse() * p.camera.global_basis
	sk.set_bone_pose_scale(h, hs)
	sk.set_bone_pose_scale(n, ns)
	sk.force_update_all_bone_transforms()
	return target

func run_tests() -> void:
	var directions := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]
	var clips := ["dash_forward", "dash_back", "dash_left", "dash_right"]
	for i in range(4):
		await fixture()
		var source_transform := p.camera.transform
		var pivot_transform := p.camera_pivot.transform
		await start(directions[i])
		check(follow.owns_camera and root.get_camera_3d() == follow.render_camera, "%s uses the rendering camera in FPS" % clips[i])
		var position_error := 0.0
		var rotation_error := 0.0
		var maximum_step := 0.0
		var total_angle := 0.0
		var previous_angle := 0.0
		var previous_rotation := Quaternion.IDENTITY
		var first := true
		var inverted := false
		var head_rise := 0.0
		var head_excursion := 0.0
		var core := 27 if i == 1 else 24
		for frame in range(core + 1):
			sample(frame)
			var actual: Transform3D = follow.render_camera.global_transform
			var expected := visible_head_reference()
			position_error = maxf(position_error, actual.origin.distance_to(expected.origin))
			rotation_error = maxf(rotation_error, actual.basis.get_rotation_quaternion().angle_to(expected.basis.orthonormalized().get_rotation_quaternion()))
			var angle := atan2(actual.basis.y.z, actual.basis.y.y) if i == 1 else atan2(actual.basis.z.x, actual.basis.z.z)
			if not first:
				var step := wrapf(angle - previous_angle, -PI, PI)
				total_angle += step
				maximum_step = maxf(maximum_step, previous_rotation.angle_to(actual.basis.get_rotation_quaternion()))
			first = false
			previous_angle = angle
			previous_rotation = actual.basis.get_rotation_quaternion()
			inverted = inverted or actual.basis.y.dot(Vector3.UP) < -0.8
			head_rise = maxf(head_rise, absf(actual.origin.y - p.camera.global_position.y))
			head_excursion = maxf(head_excursion, actual.origin.distance_to(p.camera.global_position))
		check(position_error < 0.00001 and rotation_error < 0.001, "%s follows head position/body rotation despite hidden neck/head scales" % clips[i])
		check(maximum_step < 0.8, "%s has no discontinuous frame rotation (max %.3f rad)" % [clips[i], maximum_step])
		if i in [1, 2, 3]:
			check(absf(absf(total_angle) - TAU) < 0.12, "%s camera completes the full 360-degree turn" % clips[i])
		if i == 1:
			check(inverted and head_rise > 0.2, "backflip camera turns upside down and follows vertical head motion")
		if i == 0:
			check(head_excursion > 0.1 and head_rise > 0.02, "forward camera follows launch/landing movement (travel %.3fm, vertical %.3fm)" % [head_excursion, head_rise])
		check(p.camera.transform.is_equal_approx(source_transform) and p.camera_pivot.transform.is_equal_approx(pivot_transform), "rendering never mutates the gameplay camera or look pivot")
		check(p.dodge_controller.world_direction.is_equal_approx(directions[i]) and p.dodge_controller.iframe_start == 0.05 and p.dodge_controller.iframe_end == 0.20 and p.dodge_controller.counter_window_duration == 0.6, "camera spin leaves direction and combat timing unchanged")
		var camera_id: int = follow.render_camera.get_instance_id()
		presentation._finish()
		follow._process(0.01)
		check(follow.returning and follow.owns_camera, "normal completion blends back before restoring the original camera")
		p._camera_yaw = 0.4
		p._camera_pitch = -0.2
		p._update_camera_rotation()
		follow._process(0.12)
		check(not follow.owns_camera and root.get_camera_3d() == p.camera, "camera returns to current mouse look within 0.12s")
		check(is_equal_approx(p.camera_pivot.rotation.y, p._camera_yaw) and is_equal_approx(p.camera_pivot.rotation.x, p._camera_pitch), "mouse look remains authoritative after return")
		check(follow.render_camera.get_instance_id() == camera_id, "the same camera is reused")
	await fixture(false)
	await start(Vector3.LEFT)
	sample(12)
	check(not follow.owns_camera and root.get_camera_3d() == p.camera, "TPS camera is unaffected by dash spin")
	# Exercise the real B input path instead of calling set_third_person directly.
	p.external_controlled = false
	var toggle := InputEventAction.new()
	toggle.action = &"toggle_perspective"
	toggle.pressed = true
	p._unhandled_input(toggle)
	follow._process(0.025)
	check(not p.is_third_person and follow.owns_camera, "B enters FPS during an existing dash")
	p._unhandled_input(toggle)
	follow._process(0.0)
	check(p.is_third_person and not follow.owns_camera and root.get_camera_3d() == p.camera, "B returns to TPS immediately during the turn")
	await fixture()
	await start(Vector3.BACK)
	sample(12)
	p.transition_to(PlayerController.CombatState.DEAD)
	check(not follow.owns_camera and root.get_camera_3d() == p.camera, "death restores the original camera immediately")
	await fixture()
	await start(Vector3.LEFT)
	sample(12)
	p.controls_enabled = false
	follow._process(0.0)
	check(not follow.owns_camera and root.get_camera_3d() == p.camera, "disabled control restores the original camera")
	await fixture()
	await start(Vector3.LEFT)
	sample(12)
	follow.enabled = false
	follow._process(0.0)
	check(not follow.owns_camera and root.get_camera_3d() == p.camera, "follow can be disabled during the turn without leaving a camera stuck")
	await fixture()
	follow.follow_rotation = false
	follow.head_motion_strength = 0.0
	await start(Vector3.BACK)
	sample(12)
	check(follow.render_camera.global_transform.is_equal_approx(p.camera.global_transform), "comfort settings can disable rotation and head movement")
	p.camera.fov = 83.0
	follow._process(0.0)
	check(follow.render_camera.fov == p.camera.fov and follow.render_camera.near == p.camera.near, "existing FOV feedback and clipping settings are preserved")
	await fixture()
	await start(Vector3.RIGHT)
	sample(12)
	var other := Camera3D.new()
	root.add_child(other)
	other.make_current()
	follow._process(0.0)
	check(not follow.owns_camera and root.get_camera_3d() == other, "camera ownership respects spectator/cutscene takeover")
	follow.render_camera.make_current() # Simulate a cinematic restoring its cached camera.
	follow._process(0.0)
	check(not follow.owns_camera and root.get_camera_3d() == p.camera, "a cinematic's stale rendering-camera reference redirects to the normal camera")
	other.free()
	await fixture()
	p.camera.clear_current(false)
	await start(Vector3.LEFT)
	check(not follow.owns_camera, "a remote/non-current player never steals the viewport")
	for hero in ["archer", "wizard"]:
		await fixture(true, hero)
		check(follow.render_camera == null and not follow.is_processing(), "%s does not allocate or run the Knight camera" % hero)
	# Simulate the actual FSM/animation/camera together, with physics displacement.
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 1, 100)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	floor_body.position.y = -0.5
	for direction in directions:
		await fixture()
		p.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		p.external_move_direction = direction
		check(p._try_dodge(), "live FPS dash starts")
		p.external_move_direction = Vector3.ZERO
		var start_position := p.global_position
		var maximum_rotation_step := 0.0
		var previous_q := p.camera.global_basis.get_rotation_quaternion()
		var tick := 0
		while p.dodge_controller.is_dodging and tick < 60:
			await physics_frame
			p._physics_process(1.0 / 60.0)
			p.dodge_controller._physics_process(1.0 / 60.0)
			presentation._physics_process(1.0 / 60.0)
			p.anim_player.advance(1.0 / 60.0)
			follow._process(1.0 / 60.0)
			var q: Quaternion = follow.render_camera.global_basis.get_rotation_quaternion()
			maximum_rotation_step = maxf(maximum_rotation_step, previous_q.angle_to(q))
			previous_q = q
			tick += 1
		check(maximum_rotation_step < 0.8, "live FPS dash has no rotation jump through FSM/entry blends")
		check(absf(p.global_position.distance_to(start_position) - 5.0) < 0.00025 and p.dodge_controller.world_direction.is_equal_approx(direction), "FPS camera follows real 5m dash without steering its captured direction")
		check(p.combat_state == PlayerController.CombatState.IDLE and absf(p.dodge_controller._timer - (0.45 if direction == Vector3.BACK else 0.40)) < 0.00001, "FPS camera does not delay the gameplay core or returned control")
		check(p.camera_pivot.basis.is_equal_approx(Basis.IDENTITY) and p.camera.basis.is_equal_approx(Basis.IDENTITY), "FPS spin leaves authoritative mouse look/aim unchanged throughout the core")
	await fixture()
	await start(Vector3.LEFT)
	sample(12)
	check(p.combat_state == PlayerController.CombatState.DODGE and not p._try_cast_ability("skill_1"), "camera adds no new skill-cancel rule during the core")
	p.dodge_controller.cancel_dodge()
	check(p._try_cast_ability("skill_1") and not follow.owns_camera and root.get_camera_3d() == p.camera, "an accepted skill restores the normal camera before taking animation ownership")
	await fixture()
	await start(Vector3.RIGHT)
	sample(12)
	p.external_controlled = false
	p._is_mouse_captured = true
	var captured_direction := p.dodge_controller.world_direction
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(35, -12)
	p._unhandled_input(motion)
	follow._process(0.0)
	check(not is_zero_approx(p._camera_yaw) and not is_zero_approx(p._camera_pitch) and p.dodge_controller.world_direction.is_equal_approx(captured_direction), "mouse look remains responsive during the spin without steering the dash")
	check(p.camera.global_basis.is_equal_approx(p.camera_pivot.global_basis), "mouse input updates the original aiming camera while the animated camera renders")
	await fixture()
	await start(Vector3.BACK)
	sample(12)
	follow.free()
	check(root.get_camera_3d() == p.camera, "removing the camera component mid-turn restores the original camera before tree exit")
	await fixture()
	await start(Vector3.BACK)
	sample(12)
	p.dodge_controller.cancel_dodge()
	check(p._try_cast_ability("ultimate") and p.giant_sword_ultimate.aiming, "V can take camera ownership after the dash core")
	follow._process(0.0)
	check(root.get_camera_3d() == p.giant_sword_ultimate.cinematic_camera and not follow.owns_camera, "dash camera respects V's cinematic camera")
	p.active_ability_action.cancel()
	follow._process(0.0)
	check(root.get_camera_3d() == p.camera and not follow.owns_camera, "V cancellation returns to the correct normal camera")
	p.free()
	print("SUMMARY: %d/%d TESTS PASSED" % [passes, passes + failures])
	quit(1 if failures else 0)
