extends SceneTree

const ArenaScene: PackedScene = preload("res://scenes/Arena.tscn")

var _test_results: Array[Dictionary] = []
var _arena_node: Node3D = null
var _player: PlayerController = null


func _init() -> void:
	print("====================================================")
	print("RUNTIME TEST SUITE: RMB BLOCK LIFECYCLE & LOCOMOTION")
	print("====================================================")
	call_deferred("_run_test_suite")


func _record_result(test_name: String, passed: bool, details: String) -> void:
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	var status: String = "PASS" if passed else "FAIL"
	print("[%s] %s: %s" % [status, test_name, details])


func _setup_arena_and_player() -> PlayerController:
	if _arena_node and is_instance_valid(_arena_node):
		_arena_node.queue_free()
	
	_arena_node = ArenaScene.instantiate() as Node3D
	root.add_child(_arena_node)
	_player = _arena_node.get_node("Player") as PlayerController
	return _player


func _simulate_mouse_button(player: PlayerController, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	player._unhandled_input(event)


func _run_test_suite() -> void:
	var p: PlayerController = _setup_arena_and_player()
	
	# Wait for physics / nodes to settle
	for i in range(10):
		await process_frame
		
	# -------------------------------------------------------------
	# STEP 1: INITIAL STATE VERIFICATION
	# -------------------------------------------------------------
	var init_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	init_pass = init_pass and (p._block_transition == "")
	init_pass = init_pass and (not p.is_blocking) and (not p.is_attacking)
	_record_result("STEP 1: Initial state", init_pass, "Player is IDLE with _block_transition == '' and is_blocking == false")

	# -------------------------------------------------------------
	# STEP 2: RMB DOWN -> BLOCK -> block_start
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	
	var rmb_down_pass: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	rmb_down_pass = rmb_down_pass and p.is_blocking
	rmb_down_pass = rmb_down_pass and (p._block_transition == "start")
	rmb_down_pass = rmb_down_pass and (p.anim_player.current_animation == "block_start")
	_record_result("STEP 2: RMB down -> BLOCK (block_start)", rmb_down_pass, "State is BLOCK, _block_transition == 'start', playing block_start")

	# -------------------------------------------------------------
	# STEP 3: WAIT FOR block_start -> block_hold
	# -------------------------------------------------------------
	# block_start length is ~0.208s, wait until it transitions to block_hold
	for i in range(35):
		await process_frame
		if p._block_transition == "holding":
			break
		
	var hold_start_pass: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	hold_start_pass = hold_start_pass and (p._block_transition == "holding")
	hold_start_pass = hold_start_pass and (p.anim_player.current_animation == "block_hold")
	_record_result("STEP 3: block_start finishes -> block_hold", hold_start_pass, "State is BLOCK, _block_transition == 'holding', playing block_hold")

	# -------------------------------------------------------------
	# STEP 4: HOLD RMB FOR 1 SECOND (~60 FRAMES) & VERIFY 45% SPEED
	# -------------------------------------------------------------
	var stable_hold: bool = true
	var expected_block_speed: float = p.walk_speed * 0.45 # 6.0 * 0.45 = 2.7 m/s
	
	# Press move_forward to simulate moving while holding block
	Input.action_press("move_forward")
	
	for f in range(60):
		await process_frame
		
		if p.combat_state != PlayerController.CombatState.BLOCK:
			stable_hold = false
		if p._block_transition != "holding":
			stable_hold = false
		if p.anim_player.current_animation != "block_hold":
			stable_hold = false
			
	var horiz_speed: float = Vector2(p.velocity.x, p.velocity.z).length()
	# After 60 frames (1.0s) of acceleration (acceleration = 12.0), velocity reaches ~2.7 m/s
	var speed_ratio_correct: bool = abs(horiz_speed - expected_block_speed) < 0.25
	
	# Release move_forward
	Input.action_release("move_forward")
	for f in range(20):
		await process_frame


	var step4_pass: bool = stable_hold and speed_ratio_correct
	_record_result("STEP 4: Hold RMB for 1 second (Stability & 45% speed)", step4_pass, "State remained BLOCK, _block_transition remained 'holding', speed capped at 45%% (%.2f m/s)" % horiz_speed)


	# -------------------------------------------------------------
	# STEP 5: RELEASE RMB -> block_release
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, false)
	await process_frame
	
	var rmb_release_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE or p.combat_state == PlayerController.CombatState.RUN)
	rmb_release_pass = rmb_release_pass and (not p.is_blocking)
	rmb_release_pass = rmb_release_pass and (p._block_transition == "releasing")
	rmb_release_pass = rmb_release_pass and (p.anim_player.current_animation == "block_release")
	_record_result("STEP 5: Release RMB -> block_release", rmb_release_pass, "Exited BLOCK, _block_transition == 'releasing', playing block_release")

	# -------------------------------------------------------------
	# STEP 6: WAIT FOR block_release TO FINISH -> IDLE / locomotion resumes
	# -------------------------------------------------------------
	for i in range(20):
		await process_frame
		
	var release_done_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	release_done_pass = release_done_pass and (p._block_transition == "")
	release_done_pass = release_done_pass and (p.anim_player.current_animation == "idle")
	_record_result("STEP 6: block_release finished -> IDLE resumed", release_done_pass, "State is IDLE, _block_transition == '', locomotion animation resumed 'idle'")

	# -------------------------------------------------------------
	# STEP 7: W/A/S/D MOVEMENT WORKS NORMALLY (100% SPEED & RUN ANIMATION)
	# -------------------------------------------------------------
	# Simulate moving forward with W key (100% speed)
	Input.action_press("move_forward")
	for f in range(45):
		await process_frame
	
	var full_speed: float = Vector2(p.velocity.x, p.velocity.z).length()
	var move_pass: bool = (p.combat_state == PlayerController.CombatState.RUN)
	move_pass = move_pass and (p._block_transition == "")
	move_pass = move_pass and (p.anim_player.current_animation == "run")
	move_pass = move_pass and (abs(full_speed - p.walk_speed) < 0.25)
	
	# Stop movement and verify return to IDLE
	Input.action_release("move_forward")
	for f in range(35):
		await process_frame
	move_pass = move_pass and (p.combat_state == PlayerController.CombatState.IDLE)
	move_pass = move_pass and (p.anim_player.current_animation == "idle")
	_record_result("STEP 7: W/A/S/D normal movement", move_pass, "Normal 100%% movement operates (%.2f m/s), transitions to RUN with 'run' anim, returns to IDLE" % full_speed)

	# -------------------------------------------------------------
	# STEP 8: PRESS RMB AGAIN -> BLOCK WORKS AGAIN
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	
	var rmb_again_pass: bool = (p.combat_state == PlayerController.CombatState.BLOCK)
	rmb_again_pass = rmb_again_pass and p.is_blocking
	rmb_again_pass = rmb_again_pass and (p._block_transition == "start")
	
	# Wait for block_hold
	for i in range(35):
		await process_frame
		if p._block_transition == "holding":
			break
	rmb_again_pass = rmb_again_pass and (p._block_transition == "holding")
	rmb_again_pass = rmb_again_pass and (p.anim_player.current_animation == "block_hold")
	_record_result("STEP 8: Press RMB second time -> BLOCK works again", rmb_again_pass, "Successfully re-entered BLOCK and transitioned to block_hold")

	# -------------------------------------------------------------
	# STEP 9: RELEASE AGAIN -> EXITS BLOCK AGAIN
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, false)
	await process_frame
	
	for i in range(35):
		await process_frame
		if p._block_transition == "":
			break
		
	var exit_again_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	exit_again_pass = exit_again_pass and (not p.is_blocking)
	exit_again_pass = exit_again_pass and (p._block_transition == "")
	exit_again_pass = exit_again_pass and (p.anim_player.current_animation == "idle")
	_record_result("STEP 9: Release RMB second time -> exits BLOCK again", exit_again_pass, "Successfully exited BLOCK, _block_transition == '', resumed 'idle'")

	# -------------------------------------------------------------
	# STEP 10: BLOCK + LMB -> ATTACK
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	for i in range(12):
		await process_frame
	# Now while blocking, click LMB to attack
	_simulate_mouse_button(p, MOUSE_BUTTON_LEFT, true)
	await process_frame
	
	var block_lmb_pass: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	block_lmb_pass = block_lmb_pass and p.is_attacking and (not p.is_blocking)
	block_lmb_pass = block_lmb_pass and (p._block_transition == "")
	block_lmb_pass = block_lmb_pass and (p.anim_player.current_animation == "attack")
	_record_result("STEP 10: BLOCK + LMB -> ATTACK", block_lmb_pass, "Block cleanly dropped, transitioned to ATTACK with _block_transition == ''")

	# Wait for attack swing to complete
	for i in range(50):
		await process_frame
		if not p.is_attacking:
			break
			
	# -------------------------------------------------------------
	# STEP 11: ATTACK + RMB -> BLOCK REJECTED UNTIL ATTACK COMPLETES
	# -------------------------------------------------------------
	# Start fresh attack
	p.transition_to(PlayerController.CombatState.ATTACK)
	await process_frame
	
	# While attacking, try to press RMB
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	
	var attack_rmb_rejected: bool = (p.combat_state == PlayerController.CombatState.ATTACK)
	attack_rmb_rejected = attack_rmb_rejected and (not p.is_blocking)
	_record_result("STEP 11: ATTACK + RMB (Rejected mid-swing)", attack_rmb_rejected, "RMB block request correctly rejected while attack animation is active")

	# -------------------------------------------------------------
	# STEP 12: SEQUENCE D (RMB held -> LMB -> Attack finishes while RMB held -> IDLE/RUN, no freeze)
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	for i in range(12): await process_frame
	_simulate_mouse_button(p, MOUSE_BUTTON_LEFT, true)
	await process_frame
	_simulate_mouse_button(p, MOUSE_BUTTON_LEFT, false)
	# Wait for attack to finish while RMB is still held
	for i in range(50):
		await process_frame
		if not p.is_attacking:
			break
	var seq_d_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE or p.combat_state == PlayerController.CombatState.RUN)
	seq_d_pass = seq_d_pass and (not p.is_attacking)
	seq_d_pass = seq_d_pass and (p._block_transition == "")
	seq_d_pass = seq_d_pass and (p.anim_player.current_animation == "idle" or p.anim_player.current_animation == "run")
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, false)
	await process_frame
	_record_result("STEP 12: Sequence D (Block -> Attack finishes with RMB held)", seq_d_pass, "Attack cleanly returns to locomotion without freeze or invalid block lockup")

	# -------------------------------------------------------------
	# STEP 13: SEQUENCE E (Release during block_start -> snappy recovery)
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	await process_frame
	await process_frame # ~30ms in, block_start is playing
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, false)
	for i in range(25): await process_frame
	var seq_e_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE)
	seq_e_pass = seq_e_pass and (p._block_transition == "")
	seq_e_pass = seq_e_pass and (p.anim_player.current_animation == "idle")
	_record_result("STEP 13: Sequence E (Release during block_start)", seq_e_pass, "Rapid tap during block_start cleanly recovers to IDLE with _block_transition == ''")

	# -------------------------------------------------------------
	# STEP 14: SEQUENCE G (Lose/re-capture mouse focus during block)
	# -------------------------------------------------------------
	_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
	for i in range(35):
		await process_frame
		if p._block_transition == "holding":
			break
	# Uncapture mouse (ESC)
	p._set_mouse_captured(false)
	var seq_g_pass: bool = (p.combat_state != PlayerController.CombatState.BLOCK) # Block released on focus loss
	# Recapture
	p._set_mouse_captured(true)
	for i in range(25): await process_frame
	seq_g_pass = seq_g_pass and (p.combat_state == PlayerController.CombatState.IDLE)
	seq_g_pass = seq_g_pass and (p._block_transition == "")
	_record_result("STEP 14: Sequence G (Mouse uncapture/recapture)", seq_g_pass, "Block safely released on focus loss, no stuck stance upon recapture")

	# -------------------------------------------------------------
	# STEP 15: REPEAT 10 CYCLES: Hold RMB 1s -> Release RMB -> Move WASD
	# -------------------------------------------------------------
	var cycles_passed: bool = true
	for cycle in range(10):
		# 1. Hold RMB
		_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, true)
		for f in range(35):
			await process_frame
			if p._block_transition == "holding":
				break
		if p.combat_state != PlayerController.CombatState.BLOCK or p._block_transition != "holding":
			cycles_passed = false
			print("Cycle %d failed at hold (state=%s, trans=%s)" % [cycle, p.combat_state, p._block_transition])
			break
			
		# 2. Release RMB
		_simulate_mouse_button(p, MOUSE_BUTTON_RIGHT, false)
		for f in range(35):
			await process_frame
			if p.combat_state != PlayerController.CombatState.BLOCK and p._block_transition == "":
				break
		if p.combat_state == PlayerController.CombatState.BLOCK or p._block_transition != "":
			cycles_passed = false
			print("Cycle %d failed at release" % cycle)
			break
			
		# 3. Move with WASD
		Input.action_press("move_forward")
		for f in range(30):
			await process_frame
			if p.combat_state == PlayerController.CombatState.RUN and p.anim_player.current_animation == "run":
				break
		if p.combat_state != PlayerController.CombatState.RUN or p.anim_player.current_animation != "run":
			cycles_passed = false
			print("Cycle %d failed at WASD move" % cycle)
			break
		Input.action_release("move_forward")
		for f in range(40):
			await process_frame
			if p.combat_state == PlayerController.CombatState.IDLE and p.anim_player.current_animation == "idle":
				break
		if p.combat_state != PlayerController.CombatState.IDLE or p.anim_player.current_animation != "idle":
			cycles_passed = false
			print("Cycle %d failed at WASD stop" % cycle)
			break

	_record_result("STEP 15: 10x Cycles (Hold RMB 1s -> Release -> WASD)", cycles_passed, "All 10 full gameplay cycles executed without a single freeze or state desync")

	# -------------------------------------------------------------
	# FINAL REPORT
	# -------------------------------------------------------------
	print("====================================================")
	var pass_count: int = 0
	for r in _test_results:
		if r.passed:
			pass_count += 1
	print("RMB LIFECYCLE TEST SUMMARY: %d / %d TESTS PASSED" % [pass_count, _test_results.size()])
	print("====================================================")
	
	quit(0 if pass_count == _test_results.size() else 1)

