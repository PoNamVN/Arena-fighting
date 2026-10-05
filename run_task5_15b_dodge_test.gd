extends SceneTree

# ==============================================================================
# Task 5.15B-FIX-2 Acceptance Test Suite: Directional Dash with Q
# ==============================================================================

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15B-FIX-2: REAL DASH TEST SUITE")
	print("==================================================")
	call_deferred("_run_all_tests")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] %s" % msg)
	else:
		_failures += 1
		print("[FAIL] %s" % msg)


func _run_all_tests() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = arena_scene.instantiate() as CombatTestArena
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.player
	var dummy: TrainingDummy = arena.training_dummy
	var dummy_health: HealthComponent = dummy.health_component if dummy else null

	# TEST 1: Q action exists in InputMap
	assert_true(InputMap.has_action("dodge"), "TEST 1: Q action exists in InputMap ('dodge')")

	# TEST 2: Q is bound to dodge
	var has_q: bool = false
	for ev in InputMap.action_get_events("dodge"):
		if ev is InputEventKey and (ev.physical_keycode == KEY_Q or ev.keycode == KEY_Q):
			has_q = true
			break
	assert_true(has_q, "TEST 2: Q is bound to dodge action")

	# TEST 3: Dash can start from IDLE
	p.stamina_component.current_stamina = 100.0
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	var stamina_before: float = p.stamina_component.current_stamina
	var pos_start: Vector3 = p.global_position
	var started_from_idle: bool = p._try_dodge()
	assert_true(started_from_idle and p.combat_state == PlayerController.CombatState.DODGE, "TEST 3: Dash starts from IDLE")

	# TEST 4: Stamina unchanged before/after dash (0 cost)
	assert_true(p.stamina_component.current_stamina == stamina_before, "TEST 4: Stamina is unchanged before/after dash (100 -> 100, 0 cost)")

	# TEST 5: Dash moves the player through the world (real displacement)
	for i in range(10):
		await p.get_tree().physics_frame
	var moved: bool = p.global_position.distance_to(pos_start) > 0.5
	assert_true(moved, "TEST 5: Dash creates real world displacement (not just rotation)")

	# Wait for dash to finish
	var safety: int = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# TEST 6: Actual dash distance is approximately 4.5m
	var total_dist: float = p.global_position.distance_to(pos_start)
	assert_true(absf(total_dist - 5.0) < 0.01, "TEST 6: Measured global_position displacement is ~5.0m (Actual: %.2fm)" % total_dist)

	# TEST 7: Knight dash duration is 0.40s
	assert_true(absf(p.dodge_controller.dodge_duration - 0.40) < 0.000001, "TEST 7: Knight dash duration is 0.40s (Config: %.2fs)" % p.dodge_controller.dodge_duration)

	# TEST 7b: Dash speed is significantly faster than Sprint (12.5 m/s > 10.5 m/s)
	var dash_speed: float = p.dodge_controller.dodge_distance / p.dodge_controller.dodge_duration
	assert_true(dash_speed > p.sprint_speed, "TEST 7b: Dash speed (%.1f m/s) is significantly faster than sprint speed (%.1f m/s)" % [dash_speed, p.sprint_speed])

	# TEST 8: Cooldown activates to ~1.0s (0.40s core, rounded to physics tick; ~0.67s remaining)
	assert_true(absf(p.dodge_controller._cooldown_timer - (1.0 - p.dodge_controller._timer)) < 0.00001 and p.dodge_controller.cooldown == 1.0, "TEST 8: Cooldown is ~1.0s (Remaining: %.2fs, Config: %.1fs)" % [p.dodge_controller._cooldown_timer, p.dodge_controller.cooldown])

	# TEST 9: Dash cannot be spammed during cooldown
	var pos_cooldown_start: Vector3 = p.global_position
	var rejected_cooldown: bool = not p._try_dodge()
	assert_true(rejected_cooldown and p.combat_state != PlayerController.CombatState.DODGE, "TEST 9: Dash rejected during cooldown")
	assert_true(p.global_position.distance_to(pos_cooldown_start) < 0.05, "TEST 9b: Position unchanged on rejected cooldown dash")

	# Wait for cooldown to expire
	p.dodge_controller._cooldown_timer = 0.0

	# TEST 10: Can dash even with 0 stamina (stamina is not required)
	p.stamina_component.current_stamina = 0.0
	var zero_stamina_allowed: bool = p._try_dodge()
	assert_true(zero_stamina_allowed and p.combat_state == PlayerController.CombatState.DODGE, "TEST 10: Dash allowed with 0 stamina (no stamina required)")
	assert_true(p.stamina_component.current_stamina == 0.0, "TEST 10b: Stamina remains 0 after dash")

	# Wait for dash to finish
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	p.dodge_controller.reset()
	p.stamina_component.current_stamina = 100.0

	# ==========================================================================
	# Directional Tests: W+Q, S+Q, A+Q, D+Q and Q alone
	# ==========================================================================
	p._camera_yaw = 0.0 # Facing North (-Z)

	# TEST 11: W+Q produces forward displacement (-Z)
	Input.action_press("move_forward")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_w_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("move_forward")
	var disp_w: Vector3 = p.global_position - pos_w_start
	assert_true(disp_w.z < -4.0 and absf(disp_w.x) < 0.5, "TEST 11: W+Q produces forward displacement (-Z: %.2fm)" % disp_w.z)

	# TEST 12: S+Q produces backward displacement (+Z)
	Input.action_press("move_backward")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_s_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("move_backward")
	var disp_s: Vector3 = p.global_position - pos_s_start
	assert_true(disp_s.z > 4.0 and absf(disp_s.x) < 0.5, "TEST 12: S+Q produces backward displacement (+Z: %.2fm)" % disp_s.z)

	# TEST 13: A+Q produces left displacement (-X)
	Input.action_press("move_left")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_a_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("move_left")
	var disp_a: Vector3 = p.global_position - pos_a_start
	assert_true(disp_a.x < -4.0 and absf(disp_a.z) < 0.5, "TEST 13: A+Q produces left displacement (-X: %.2fm)" % disp_a.x)

	# TEST 14: D+Q produces right displacement (+X)
	Input.action_press("move_right")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_d_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("move_right")
	var disp_d: Vector3 = p.global_position - pos_d_start
	assert_true(disp_d.x > 4.0 and absf(disp_d.z) < 0.5, "TEST 14: D+Q produces right displacement (+X: %.2fm)" % disp_d.x)

	# TEST 15: Q alone without WASD produces camera-relative forward displacement
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.velocity = Vector3.ZERO
	var pos_q_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	var disp_q: Vector3 = p.global_position - pos_q_start
	assert_true(disp_q.z < -4.0 and absf(disp_q.x) < 0.3, "TEST 15: Q alone produces camera forward displacement (-Z: %.2fm)" % disp_q.z)

	# TEST 15b: W + Shift + Q (Sprint + Q) overrides sprint speed and dashes ~5.0m forward
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_sprint_start: Vector3 = p.global_position
	var sprint_dash_started: bool = p._try_dodge()
	assert_true(sprint_dash_started and p.combat_state == PlayerController.CombatState.DODGE, "TEST 15b: W+Shift+Q starts DODGE")
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var disp_sprint: Vector3 = p.global_position - pos_sprint_start
	assert_true(disp_sprint.z < -4.0 and absf(disp_sprint.x) < 0.5, "TEST 15c: W+Shift+Q produces forward displacement override (-Z: %.2fm)" % disp_sprint.z)

	# ==========================================================================
	# Combat Cancellations: Attack -> Q and Block -> Q
	# ==========================================================================
	# TEST 16: Attack -> Q cancels attack during windup
	p.dodge_controller.reset()
	p.stamina_component.current_stamina = 100.0
	p._try_combat_attack()
	assert_true(p.combat_state == PlayerController.CombatState.ATTACK, "TEST 16a: Attack started")
	var attack_cancelled: bool = p._try_dodge()
	assert_true(attack_cancelled and p.combat_state == PlayerController.CombatState.DODGE, "TEST 16b: Attack + Q cancels attack into DODGE")

	# Wait for dodge to complete; verify no damage to dummy
	safety = 100
	while p.dodge_controller.is_dodging and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	var hp_remained: bool = (dummy_health == null or dummy_health.current_health == dummy_health.max_health)
	assert_true(hp_remained, "TEST 17: Attack cancelled cleanly; zero damage dealt to target")
	assert_true(p.combo_step == 0, "TEST 18: Combo step reset to 0 after attack cancel")

	# TEST 19: Block + Q cancels BLOCK into DODGE
	p.dodge_controller.reset()
	p._start_block()
	assert_true(p.combat_state == PlayerController.CombatState.BLOCK, "TEST 19a: In BLOCK state")
	var block_cancelled: bool = p._try_dodge()
	assert_true(block_cancelled and p.combat_state == PlayerController.CombatState.DODGE, "TEST 19b: Block + Q cancels BLOCK into DODGE")
	safety = 100
	while p.dodge_controller.is_dodging and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# TEST 20: Finisher recovery + Q is rejected
	p._combo_finisher_recovery_timer = 0.8
	var finisher_rejected: bool = not p._try_dodge()
	assert_true(finisher_rejected and p.combat_state != PlayerController.CombatState.DODGE, "TEST 20: Finisher recovery + Q is strictly rejected")
	p._combo_finisher_recovery_timer = 0.0

	# TEST 21: DEAD + Q is rejected
	p.dodge_controller.reset()
	p.transition_to(PlayerController.CombatState.DEAD)
	var dead_rejected: bool = not p._try_dodge()
	assert_true(dead_rejected and p.combat_state == PlayerController.CombatState.DEAD, "TEST 21: DEAD + Q is rejected")

	# Respawn player
	p.respawn(Vector3(0, 0.1, 0), 0.0)
	await process_frame
	p.stamina_component.current_stamina = 100.0
	p.dodge_controller.reset()

	# ==========================================================================
	# Camera-relative Direction in FPS and TPS
	# ==========================================================================
	# Rotate camera 90 degrees right (yaw = -PI/2)
	p._camera_yaw = -PI / 2.0
	p.set_third_person(true)

	# TEST 22: In TPS, W+Q follows rotated camera yaw (+X forward when yaw = -90 deg)
	Input.action_press("move_forward")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_tps_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("move_forward")
	var disp_tps: Vector3 = p.global_position - pos_tps_start
	assert_true(disp_tps.x > 4.0, "TEST 22: TPS dash follows camera yaw (+X: %.2fm)" % disp_tps.x)

	# TEST 23: In FPS, W+Q follows camera yaw
	p.set_third_person(false)
	p._camera_yaw = PI / 2.0 # 90 deg left (camera forward is -X)
	Input.action_press("move_forward")
	await p.get_tree().physics_frame
	p.dodge_controller.reset()
	p.combat_state = PlayerController.CombatState.RUN
	var pos_fps_start: Vector3 = p.global_position
	p._try_dodge()
	safety = 100
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1
	Input.action_release("move_forward")
	var disp_fps: Vector3 = p.global_position - pos_fps_start
	assert_true(disp_fps.x < -4.0, "TEST 23: FPS dash follows camera yaw (-X: %.2fm)" % disp_fps.x)

	# TEST 24: Echo input does not trigger repeat dashes (Hold Q)
	p.set_third_person(true)
	p._camera_yaw = 0.0
	p.dodge_controller.reset()
	var echo_event := InputEventKey.new()
	echo_event.physical_keycode = KEY_Q
	echo_event.pressed = true
	echo_event.echo = true
	var state_before_echo = p.combat_state
	p._unhandled_input(echo_event)
	assert_true(p.combat_state == state_before_echo, "TEST 24: Echo event (Hold Q) does not trigger dash")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
