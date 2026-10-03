extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15C-A: DODGE I-FRAME FOUNDATION TEST")
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
	var arena: Node3D = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.find_child("Player", true, false) as PlayerController
	assert_true(p != null, "TEST 0: Player exists in arena")

	var dc: DodgeController = p.dodge_controller
	assert_true(dc != null, "TEST 0b: DodgeController exists on Player")

	# Ensure baseline configuration
	dc.dodge_duration = 0.25
	dc.iframe_start = 0.05
	dc.iframe_end = 0.20
	p.stamina_component.current_stamina = 100.0

	var attacker_pos: Vector3 = p.global_position + Vector3(0, 0, -2.0)

	# =========================================================================
	# TEST 1: Dash starts normally
	# =========================================================================
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	var started: bool = p._try_dodge()
	assert_true(started and p.combat_state == PlayerController.CombatState.DODGE and dc.is_dodging,
		"TEST 1: Dash starts normally (state == DODGE, is_dodging == true)")

	# =========================================================================
	# TEST 2: i-frame is NOT active before its window (t < 0.05s)
	# =========================================================================
	# On the immediate next frame (~0.016s), timer is < 0.05s
	await p.get_tree().physics_frame
	assert_true(not dc.is_in_iframe(), "TEST 2a: DodgeController is_in_iframe() is FALSE before window (windup)")
	assert_true(not p.is_in_dodge_iframe(), "TEST 2b: PlayerController is_in_dodge_iframe() is FALSE before window")
	assert_true(not p.is_invulnerable, "TEST 2c: PlayerController is_invulnerable is FALSE before window")
	assert_true(not p.is_dodging_iframe, "TEST 2d: PlayerController is_dodging_iframe is FALSE before window")

	# =========================================================================
	# TEST 3: i-frame becomes active during configured window (0.05s <= t <= 0.20s)
	# =========================================================================
	# Advance 4 more physics frames (~0.016 * 5 = ~0.08s into dash)
	for i in range(4):
		await p.get_tree().physics_frame
	assert_true(dc.is_in_iframe(), "TEST 3a: DodgeController is_in_iframe() is TRUE in window (~0.08s)")
	assert_true(p.is_in_dodge_iframe(), "TEST 3b: PlayerController is_in_dodge_iframe() is TRUE in window")
	assert_true(p.is_invulnerable, "TEST 3c: PlayerController is_invulnerable is TRUE in window")
	assert_true(p.is_dodging_iframe, "TEST 3d: PlayerController is_dodging_iframe is TRUE in window")

	# =========================================================================
	# TEST 4: i-frame ends before Dash ends (0.20s < t < 0.25s)
	# =========================================================================
	# Advance to frame 14 (~0.233s, between 0.20s iframe_end and 0.25s dodge_duration)
	for i in range(9):
		await p.get_tree().physics_frame
	assert_true(p.combat_state == PlayerController.CombatState.DODGE and dc.is_dodging,
		"TEST 4a: Player is still dashing at t ~0.23s")
	assert_true(not dc.is_in_iframe(), "TEST 4b: DodgeController i-frame has ENDED before dash finishes (~0.23s)")
	assert_true(not p.is_in_dodge_iframe(), "TEST 4c: PlayerController is_in_dodge_iframe() is FALSE at ~0.23s")
	assert_true(not p.is_invulnerable, "TEST 4d: PlayerController is_invulnerable is FALSE at ~0.23s")

	# Wait for dash to finish completely
	var safety: int = 50
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# =========================================================================
	# TEST 5: Attack during i-frame is prevented & triggers Perfect Dodge
	# =========================================================================
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.health_component.reset_health()
	var hp_before: float = p.health_component.current_health
	var event_tracker: Array = [0]
	var on_event = func(): event_tracker[0] += 1
	dc.perfect_dodge_triggered.connect(on_event)

	p._try_dodge()
	# Step into i-frame window (~0.10s)
	for i in range(6):
		await p.get_tree().physics_frame
	assert_true(p.is_in_dodge_iframe(), "TEST 5a: Confirmed inside i-frame for attack test")

	var dodgeable_payload := AttackPayload.new(25.0, attacker_pos, 15.0, true, true, 25.0)
	p.take_damage(dodgeable_payload)

	assert_true(p.health_component.current_health == hp_before, "TEST 5b: Damage prevented during i-frame (HP: %.1f -> %.1f)" % [hp_before, p.health_component.current_health])
	assert_true(p._knockback_timer == 0.0, "TEST 5c: Knockback completely prevented during i-frame")
	assert_true(event_tracker[0] == 1, "TEST 5d: Perfect Dodge event registered (Count: %d)" % event_tracker[0])
	assert_true(dc.perfect_dodge_count == 1, "TEST 5e: DodgeController perfect_dodge_count is 1")

	# =========================================================================
	# TEST 8: Multiple checks during one Dash do not create duplicate Perfect Dodge events
	# =========================================================================
	# Hit player a second time with another attack within the SAME i-frame
	var second_payload := AttackPayload.new(20.0, attacker_pos, 15.0, true, true, 25.0)
	p.take_damage(second_payload)

	assert_true(p.health_component.current_health == hp_before, "TEST 8a: Second attack during same i-frame also negated")
	assert_true(event_tracker[0] == 1, "TEST 8b: No duplicate Perfect Dodge event fired on second hit (Count: %d)" % event_tracker[0])
	assert_true(dc.perfect_dodge_count == 1, "TEST 8c: perfect_dodge_count remains 1")

	dc.perfect_dodge_triggered.disconnect(on_event)

	# Wait for dash to finish
	safety = 50
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# =========================================================================
	# TEST 5_RAW_NUMERIC: Raw numeric damage float/int during i-frame (Manual scenario reproduction)
	# =========================================================================
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.health_component.reset_health()
	var hp_numeric_before: float = p.health_component.current_health
	var numeric_event_tracker: Array = [0]
	var on_numeric_event = func(): numeric_event_tracker[0] += 1
	dc.perfect_dodge_triggered.connect(on_numeric_event)

	p._try_dodge()
	# Step into i-frame window (~0.10s)
	for i in range(6):
		await p.get_tree().physics_frame
	assert_true(p.is_in_dodge_iframe(), "TEST 5_num_a: Confirmed inside i-frame for raw numeric attack")

	# Type safety checks: calling can_perfect_dodge_attack with float/int must not crash
	assert_true(not dc.can_perfect_dodge_attack(25.0), "TEST 5_num_b: dc.can_perfect_dodge_attack(25.0) safely returns false without crash")
	assert_true(not dc.can_perfect_dodge_attack(25), "TEST 5_num_c: dc.can_perfect_dodge_attack(25) safely returns false without crash")
	assert_true(not p.can_perfect_dodge_attack(25.0), "TEST 5_num_d: p.can_perfect_dodge_attack(25.0) safely returns false without crash")

	# Calling take_damage with raw float (the exact bug scenario)
	p.take_damage(25.0, attacker_pos)

	assert_true(p.health_component.current_health == hp_numeric_before, "TEST 5_num_e: HP unchanged on raw float damage during i-frame")
	assert_true(p._knockback_timer == 0.0, "TEST 5_num_f: Knockback unchanged (0.0)")
	assert_true(numeric_event_tracker[0] == 1, "TEST 5_num_g: Perfect Dodge registered exactly once for raw float attack")

	dc.perfect_dodge_triggered.disconnect(on_numeric_event)

	# Wait for dash to finish
	safety = 50
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# =========================================================================
	# TEST 6: Attack outside i-frame still damages normally
	# =========================================================================
	# 6a. Normal standing hit
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	hp_before = p.health_component.current_health
	p.take_damage(25.0, attacker_pos)
	assert_true(p.health_component.current_health == hp_before - 25.0, "TEST 6a: Attack outside dodge damages normally")

	# 6b. Hit during recovery portion of dash (after i-frame ends at t > 0.20s)
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.health_component.reset_health()
	p._try_dodge()
	# Advance 13 frames (~0.216s, past 0.20s i-frame window)
	for i in range(13):
		await p.get_tree().physics_frame
	assert_true(p.combat_state == PlayerController.CombatState.DODGE and not p.is_in_dodge_iframe(),
		"TEST 6b: In dash recovery window, outside i-frame")
	hp_before = p.health_component.current_health
	p.take_damage(25.0, attacker_pos)
	assert_true(p.health_component.current_health == hp_before - 25.0,
		"TEST 6c: Attack in dash recovery window deals full damage")

	# Wait for dash to finish
	safety = 50
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# =========================================================================
	# TEST 7: dodgeable = false cannot trigger Perfect Dodge
	# =========================================================================
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p.health_component.reset_health()
	hp_before = p.health_component.current_health
	p._try_dodge()
	# Step into i-frame window (~0.10s)
	for i in range(6):
		await p.get_tree().physics_frame
	assert_true(p.is_in_dodge_iframe(), "TEST 7a: Inside i-frame for non-dodgeable attack")

	var un_dodgeable := AttackPayload.new(30.0, attacker_pos, 15.0, false, false, 0.0)
	assert_true(not p.can_perfect_dodge_attack(un_dodgeable), "TEST 7b: can_perfect_dodge_attack is FALSE for dodgeable=false")
	assert_true(not dc.can_perfect_dodge_attack(un_dodgeable), "TEST 7c: DodgeController can_perfect_dodge_attack is FALSE")

	var count_before: int = dc.perfect_dodge_count
	p.take_damage(un_dodgeable)

	assert_true(p.health_component.current_health == hp_before - 30.0, "TEST 7d: Non-dodgeable attack deals damage inside i-frame")
	assert_true(dc.perfect_dodge_count == count_before, "TEST 7e: No Perfect Dodge event registered for non-dodgeable attack")

	# Wait for dash to finish
	safety = 50
	while p.combat_state == PlayerController.CombatState.DODGE and safety > 0:
		await p.get_tree().physics_frame
		safety -= 1

	# =========================================================================
	# TEST 9: Death/respawn clears i-frame state
	# =========================================================================
	dc.reset()
	p.combat_state = PlayerController.CombatState.IDLE
	p._try_dodge()
	# Step into i-frame
	for i in range(6):
		await p.get_tree().physics_frame
	assert_true(p.is_in_dodge_iframe(), "TEST 9a: Confirmed in i-frame before death")

	# Trigger DEATH
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(not p.is_in_dodge_iframe(), "TEST 9b: is_in_dodge_iframe is FALSE immediately on DEAD")
	assert_true(not p.is_invulnerable, "TEST 9c: is_invulnerable is FALSE on DEAD")
	assert_true(not dc.is_in_iframe(), "TEST 9d: DodgeController is_in_iframe is FALSE on DEAD")
	assert_true(not dc.is_dodging, "TEST 9e: is_dodging is FALSE on DEAD")

	# Respawn
	p.respawn(Vector3(0, 0.1, 0), 0.0)
	await process_frame
	assert_true(not p.is_in_dodge_iframe(), "TEST 9f: is_in_dodge_iframe remains FALSE after respawn")
	assert_true(not p.is_invulnerable, "TEST 9g: is_invulnerable remains FALSE after respawn")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
