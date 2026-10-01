extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15C: PERFECT DODGE & TIME MANAGER TEST")
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
	assert_true(p != null, "TEST 1: Player initialized in arena")

	p.stamina_component.current_stamina = 50.0

	# 1. Normal attack while not dodging: takes damage and knockback
	var attacker_pos: Vector3 = p.global_position + Vector3(0, 0, -2.0)
	var hp_before: float = p.health_component.current_health
	p.take_damage(25.0, attacker_pos)
	assert_true(p.health_component.current_health == hp_before - 25.0, "TEST 2: Normal attack deals damage when not dodging")
	assert_true(p._knockback_timer > 0.0, "TEST 3: Knockback applied on un-dodged attack")

	# Wait for knockback to settle
	await create_timer(0.20).timeout

	# 2. Perfect Dodge: Start dodge, wait to reach i-frame window (~0.10s)
	p.stamina_component.current_stamina = 50.0
	hp_before = p.health_component.current_health
	p._try_dodge()
	assert_true(p.combat_state == PlayerController.CombatState.DODGE, "TEST 4: Dodge started")

	# Advance into partial i-frame window (window is 0.05s to 0.20s)
	await create_timer(0.08).timeout
	assert_true(p.is_in_dodge_iframe(), "TEST 5: Player inside dodge partial i-frame")

	# Incoming dodgeable attack strikes player inside i-frame
	var payload: AttackPayload = AttackPayload.new(25.0, attacker_pos, 15.0, true, true, 25.0)
	var stamina_before_dodge_hit: float = p.stamina_component.current_stamina
	p.take_damage(payload)

	# Assert Perfect Dodge outcomes:
	assert_true(p.health_component.current_health == hp_before, "TEST 6: Damage completely negated by i-frame")
	assert_true(p._knockback_timer == 0.0, "TEST 7: Knockback completely negated by i-frame")
	assert_true(p.stamina_component.current_stamina == stamina_before_dodge_hit + 25.0, "TEST 8: Stamina bonus (+25) awarded on Perfect Dodge")
	assert_true(p.is_counter_window_active(), "TEST 9: Counter Window is active after Perfect Dodge")
	assert_true(Engine.time_scale < 1.0, "TEST 10: Combat slow motion triggered by Perfect Dodge")

	# Wait for real time slow motion duration to expire (~0.3s real time)
	await create_timer(0.40, true, false, true).timeout
	assert_true(Engine.time_scale == 1.0, "TEST 11: Time scale safely restored to 1.0")

	# 3. Non-dodgeable attack inside i-frame: cannot be dodged!
	# Wait for dodge cooldown
	await create_timer(0.8, true, false, true).timeout
	p.stamina_component.current_stamina = 50.0
	p._try_dodge()
	await create_timer(0.08).timeout
	assert_true(p.is_in_dodge_iframe(), "TEST 12: In i-frame for non-dodgeable test")

	var un_dodgeable_payload: AttackPayload = AttackPayload.new(25.0, attacker_pos, 15.0, false, false, 0.0)
	hp_before = p.health_component.current_health
	p.take_damage(un_dodgeable_payload)
	assert_true(p.health_component.current_health == hp_before - 25.0, "TEST 13: Non-dodgeable attack deals damage even inside i-frame")

	# 4. Safe time scale reset on death
	CombatTimeManager.apply_slow_motion(0.2, 5.0)
	assert_true(Engine.time_scale < 1.0, "TEST 14: Time dilated")
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(Engine.time_scale == 1.0, "TEST 15: Time scale safely reset to 1.0 on player death")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
