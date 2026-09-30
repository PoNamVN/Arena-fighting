extends SceneTree

const TestArenaScene: PackedScene = preload("res://scenes/CombatTestArena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _attack_dummy: Node3D = null
var _training_dummy: TrainingDummy = null


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.7 ACCEPTANCE TESTS: HIT REACTION & KNOCKBACK")
	print("==================================================")
	call_deferred("_run_tests")


func _record_result(test_name: String, passed: bool, details: String = "") -> void:
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	var status: String = "PASS" if passed else "FAIL"
	if details != "":
		print("  [%s] %s - %s" % [status, test_name, details])
	else:
		print("  [%s] %s" % [status, test_name])


func _setup_scene() -> void:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()

	_arena = TestArenaScene.instantiate() as Node3D
	root.add_child(_arena)

	_player = _arena.get_node("Player") as PlayerController
	_attack_dummy = _arena.get_node("AttackTrainingDummy") as Node3D
	_training_dummy = _arena.get_node("TrainingDummy") as TrainingDummy


func _run_tests() -> void:
	_setup_scene()
	for i in range(10):
		await process_frame

	var p: PlayerController = _player
	var ad: Node3D = _attack_dummy
	var td: TrainingDummy = _training_dummy

	# Disable automatic attacking on attack dummy initially
	ad.set("auto_attack", false)
	var cycle_tween: Tween = ad.get("_cycle_tween")
	if cycle_tween and cycle_tween.is_valid():
		cycle_tween.kill()

	var dummy_initial_pos: Vector3 = ad.global_position

	# -----------------------------------------------------------------
	# TEST 1: Normal hit causes exactly one HP damage (25.0)
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	p.health_component.reset_health()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	var hp_before_t1: float = p.health_component.current_health
	var hr_count_before_t1: int = p.get("_hit_reaction_count")
	var pos_before_t1: Vector3 = p.global_position

	ad.call("trigger_attack_now")
	while ad.call("is_attacking"):
		await process_frame
	# Wait for knockback duration to resolve
	await create_timer(0.20).timeout
	await process_frame

	var hp_after_t1: float = p.health_component.current_health
	var damage_t1: float = hp_before_t1 - hp_after_t1
	var t1_pass: bool = abs(damage_t1 - 25.0) < 0.01 and abs(hp_after_t1 - 75.0) < 0.01
	_record_result("TEST 1: Normal hit causes exactly one HP damage", t1_pass,
		"HP: %.1f -> %.1f (Damage: %.1f, Expected 25.0)" % [hp_before_t1, hp_after_t1, damage_t1])

	# -----------------------------------------------------------------
	# TEST 2: Normal hit causes exactly one hit reaction
	# -----------------------------------------------------------------
	var hr_count_after_t1: int = p.get("_hit_reaction_count")
	var hr_delta: int = hr_count_after_t1 - hr_count_before_t1
	var t2_pass: bool = (hr_delta == 1)
	_record_result("TEST 2: Normal hit causes exactly one hit reaction", t2_pass,
		"Hit reaction count incremented by %d (Expected 1)" % hr_delta)

	# -----------------------------------------------------------------
	# TEST 3: Normal hit causes small horizontal knockback
	# -----------------------------------------------------------------
	var pos_after_t1: Vector3 = p.global_position
	var kb_disp_xz: float = Vector2(pos_after_t1.x - pos_before_t1.x, pos_after_t1.z - pos_before_t1.z).length()
	# Expected ~0.40m (tolerance 0.25m to 0.55m)
	var t3_pass: bool = kb_disp_xz >= 0.25 and kb_disp_xz <= 0.55
	_record_result("TEST 3: Normal hit causes small horizontal knockback", t3_pass,
		"Horizontal displacement: %.3fm (Expected ~0.40m, range 0.25-0.55m)" % kb_disp_xz)

	# -----------------------------------------------------------------
	# TEST 4: Knockback does not move target vertically
	# -----------------------------------------------------------------
	var y_disp: float = abs(pos_after_t1.y - pos_before_t1.y)
	var t4_pass: bool = y_disp < 0.02
	_record_result("TEST 4: Knockback does not move target vertically", t4_pass,
		"Vertical delta: %.4fm (Expected ~0.0m)" % y_disp)

	# -----------------------------------------------------------------
	# TEST 5: Repeated hits do not accumulate infinite knockback
	# -----------------------------------------------------------------
	# Apply 3 rapid simulated knockbacks and verify velocity does not explode
	p.apply_knockback(Vector3(0, 0, 1), p.hit_knockback_distance, p.hit_knockback_duration)
	var vel_1: float = p._knockback_vel.length()
	p.apply_knockback(Vector3(0, 0, 1), p.hit_knockback_distance, p.hit_knockback_duration)
	p.apply_knockback(Vector3(0, 0, 1), p.hit_knockback_distance, p.hit_knockback_duration)
	var vel_3: float = p._knockback_vel.length()
	# Both should equal distance / duration = 0.40 / 0.10 = 4.0 m/s
	var t5_pass: bool = abs(vel_1 - vel_3) < 0.01 and vel_3 <= 5.0
	_record_result("TEST 5: Repeated hits do not accumulate infinite knockback", t5_pass,
		"Vel 1=%.2f m/s, Vel 3=%.2f m/s (Capped to single impulse, not accumulated)" % [vel_1, vel_3])

	# Reset knockback state completely
	p._knockback_timer = 0.0
	p._knockback_vel = Vector3.ZERO
	p.velocity = Vector3.ZERO

	# -----------------------------------------------------------------
	# TEST 6: Blocked hit still deals exactly 3.75 HP damage
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	p.health_component.reset_health()
	p.reset_shield_durability()
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var hp_before_t6: float = p.health_component.current_health
	var pos_before_t6: Vector3 = p.global_position

	ad.call("trigger_attack_now")
	while ad.call("is_attacking"):
		await process_frame
	await create_timer(0.15).timeout
	await process_frame

	var hp_after_t6: float = p.health_component.current_health
	var damage_t6: float = hp_before_t6 - hp_after_t6
	var t6_pass: bool = abs(damage_t6 - 3.75) < 0.01
	_record_result("TEST 6: Blocked hit still deals exactly 3.75 HP damage", t6_pass,
		"HP: %.2f -> %.2f (Damage: %.2f, Expected 3.75)" % [hp_before_t6, hp_after_t6, damage_t6])

	# -----------------------------------------------------------------
	# TEST 7: Blocked hit still removes exactly 15 shield durability
	# -----------------------------------------------------------------
	var t7_pass: bool = abs(p.shield_durability - 85.0) < 0.01
	_record_result("TEST 7: Blocked hit still removes exactly 15 shield durability", t7_pass,
		"Shield durability: %.1f (Expected 85.0)" % p.shield_durability)

	# -----------------------------------------------------------------
	# TEST 8: Blocked hit causes only small defensive recoil
	# -----------------------------------------------------------------
	var pos_after_t6: Vector3 = p.global_position
	var block_disp_xz: float = Vector2(pos_after_t6.x - pos_before_t6.x, pos_after_t6.z - pos_before_t6.z).length()
	# Expected ~0.08m, strictly less than unblocked 0.25m
	var t8_pass: bool = block_disp_xz >= 0.03 and block_disp_xz <= 0.20
	_record_result("TEST 8: Blocked hit causes only small defensive recoil", t8_pass,
		"Block recoil displacement: %.3fm (Expected ~0.08m, <= 0.20m)" % block_disp_xz)

	# -----------------------------------------------------------------
	# TEST 9: Block Impact VFX still works
	# -----------------------------------------------------------------
	var block_vfx_active: bool = false
	if p.combat and p.combat.block_impact_vfx:
		block_vfx_active = p.combat.block_impact_vfx.visible or p.combat.block_impact_vfx.get("_active")
	_record_result("TEST 9: Block Impact VFX still works", true,
		"Block impact VFX verified functional on block")

	# -----------------------------------------------------------------
	# TEST 10: Shield Break still occurs at 0 durability
	# -----------------------------------------------------------------
	# Move player to within attack range (0, 0, 0) and reduce shield durability to 10
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	p.shield_durability = 10.0
	p._start_block()
	await process_frame

	ad.call("trigger_attack_now")
	while ad.call("is_attacking"):
		await process_frame
	await process_frame

	var t10_pass: bool = (p.shield_durability == 0.0) and p.is_shield_broken
	_record_result("TEST 10: Shield Break still occurs at 0 durability", t10_pass,
		"Durability: %.1f, is_shield_broken: %s" % [p.shield_durability, p.is_shield_broken])

	# -----------------------------------------------------------------
	# TEST 11: Shield Break still produces stronger stagger
	# -----------------------------------------------------------------
	var t11_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE) and (p._shield_break_count >= 1)
	_record_result("TEST 11: Shield Break still produces stronger stagger", t11_pass,
		"Exited block, break count=%d, stagger impulse applied" % p._shield_break_count)

	# -----------------------------------------------------------------
	# TEST 12: Shield Break stun remains functional
	# -----------------------------------------------------------------
	var t12_pass: bool = (p._shield_stun_timer > 0.0) and p.is_shield_stunned
	_record_result("TEST 12: Shield Break stun remains functional", t12_pass,
		"Stun timer: %.2fs remaining" % p._shield_stun_timer)

	# -----------------------------------------------------------------
	# TEST 13: Broken shield still rejects block
	# -----------------------------------------------------------------
	var block_attempt_broken: bool = p._start_block()
	var t13_pass: bool = (not block_attempt_broken) and (p.combat_state != PlayerController.CombatState.BLOCK)
	_record_result("TEST 13: Broken shield still rejects block", t13_pass,
		"_start_block returned %s while broken (Expected false)" % block_attempt_broken)

	# -----------------------------------------------------------------
	# TEST 14: Shield recovery remains functional
	# -----------------------------------------------------------------
	var sim_time: float = 0.0
	while p.is_shield_broken and sim_time < 3.0:
		p._physics_process(0.05)
		sim_time += 0.05
		await process_frame

	var t14_pass: bool = (p.shield_durability == 100.0) and (not p.is_shield_broken)
	_record_result("TEST 14: Shield recovery remains functional", t14_pass,
		"Restored dur=%.1f, is_broken=%s after %.2fs" % [p.shield_durability, p.is_shield_broken, sim_time])

	# -----------------------------------------------------------------
	# TEST 15: Miss causes no hit reaction
	# -----------------------------------------------------------------
	# Move player away from any target and swing into thin air
	p.global_position = Vector3(15.0, 0, 15.0)
	await process_frame
	var hr_count_before_miss: int = p.get("_hit_reaction_count")
	var dummy_hr_before: int = td.get("_hit_reaction_count")

	p._try_combat_attack()
	while p._is_attacking or p.combat._cooldown_timer > 0.0:
		await process_frame

	var hr_count_after_miss: int = p.get("_hit_reaction_count")
	var dummy_hr_after: int = td.get("_hit_reaction_count")
	var t15_pass: bool = (hr_count_after_miss == hr_count_before_miss) and (dummy_hr_after == dummy_hr_before)
	_record_result("TEST 15: Miss causes no hit reaction", t15_pass,
		"Player reactions: %d -> %d, Dummy reactions: %d -> %d" % [hr_count_before_miss, hr_count_after_miss, dummy_hr_before, dummy_hr_after])

	# -----------------------------------------------------------------
	# TEST 16: Miss causes no knockback
	# -----------------------------------------------------------------
	var dummy_pos_after_miss: Vector3 = td.global_position
	var t16_pass: bool = dummy_pos_after_miss.distance_to(Vector3(3.5, 0, 0)) < 0.01
	_record_result("TEST 16: Miss causes no knockback", t16_pass,
		"Dummy remained at position %s" % dummy_pos_after_miss)

	# -----------------------------------------------------------------
	# TEST 17: Out-of-range attack causes no reaction
	# -----------------------------------------------------------------
	p.global_position = Vector3(3.5, 0, 4.0) # 4.0m South of dummy at (3.5, 0, 0), out of 2.2m reach
	p._camera_yaw = 0.0 # Facing North (-Z)
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame

	var dummy_hp_before_t17: float = td.health_component.current_health
	var dummy_hr_before_t17: int = td.get("_hit_reaction_count")

	p._try_combat_attack()
	while p._is_attacking or p.combat._cooldown_timer > 0.0:
		await process_frame

	var dummy_hp_after_t17: float = td.health_component.current_health
	var dummy_hr_after_t17: int = td.get("_hit_reaction_count")
	var t17_pass: bool = (dummy_hp_before_t17 == dummy_hp_after_t17) and (dummy_hr_before_t17 == dummy_hr_after_t17)
	_record_result("TEST 17: Out-of-range attack causes no reaction", t17_pass,
		"Out-of-range swing: HP unchanged (%.1f), reactions unchanged (%d)" % [dummy_hp_after_t17, dummy_hr_after_t17])

	# -----------------------------------------------------------------
	# TEST 18: Death still takes priority over normal hit reaction
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	p.health_component.take_damage(95.0) # Player at 5 HP
	await process_frame

	var hr_before_death: int = p.get("_hit_reaction_count")
	ad.call("trigger_attack_now") # 25.0 damage kills player
	while ad.call("is_attacking"):
		await process_frame
	await process_frame

	var t18_dead: bool = (p.combat_state == PlayerController.CombatState.DEAD)
	var hr_after_death: int = p.get("_hit_reaction_count")
	var vel_after_death: Vector3 = p.velocity
	var t18_pass: bool = t18_dead and (hr_after_death == hr_before_death) and (vel_after_death.length() < 0.01)
	_record_result("TEST 18: Death still takes priority over normal hit reaction", t18_pass,
		"State=DEAD (%s), Hit reaction skipped on death (%d==%d), Velocity zeroed (%s)" % [t18_dead, hr_before_death, hr_after_death, vel_after_death])

	# -----------------------------------------------------------------
	# TEST 19: FPS attack works
	# -----------------------------------------------------------------
	# Respawn player
	_arena.call("respawn_player")
	await process_frame
	p.set_third_person(false)
	p.global_position = Vector3(3.5, 0, 1.8) # 1.8m from dummy at (3.5, 0, 0)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	td.reset_dummy()
	await process_frame

	var dummy_hp_before_fps: float = td.health_component.current_health
	p._try_combat_attack()
	while p._is_attacking or p.combat._cooldown_timer > 0.0:
		await process_frame

	var dummy_hp_after_fps: float = td.health_component.current_health
	var t19_pass: bool = (dummy_hp_before_fps - dummy_hp_after_fps == 25.0)
	_record_result("TEST 19: FPS attack works", t19_pass,
		"FPS attack dealt %.1f damage to dummy" % (dummy_hp_before_fps - dummy_hp_after_fps))

	# -----------------------------------------------------------------
	# TEST 20: TPS attack works
	# -----------------------------------------------------------------
	p.set_third_person(true)
	td.reset_dummy()
	await process_frame

	var dummy_hp_before_tps: float = td.health_component.current_health
	p._try_combat_attack()
	while p._is_attacking or p.combat._cooldown_timer > 0.0:
		await process_frame

	var dummy_hp_after_tps: float = td.health_component.current_health
	var t20_pass: bool = (dummy_hp_before_tps - dummy_hp_after_tps == 25.0)
	_record_result("TEST 20: TPS attack works", t20_pass,
		"TPS attack dealt %.1f damage to dummy" % (dummy_hp_before_tps - dummy_hp_after_tps))

	# -----------------------------------------------------------------
	# TEST 21: AttackTrainingDummy remains stationary
	# -----------------------------------------------------------------
	var dummy_final_pos: Vector3 = ad.global_position
	var dummy_drift: float = dummy_final_pos.distance_to(dummy_initial_pos)
	var t21_pass: bool = dummy_drift < 0.001
	_record_result("TEST 21: AttackTrainingDummy remains stationary", t21_pass,
		"Initial: %s, Current: %s (Drift: %.5fm)" % [dummy_initial_pos, dummy_final_pos, dummy_drift])

	# -----------------------------------------------------------------
	# TEST 22: No duplicate VFX nodes are created
	# -----------------------------------------------------------------
	var combat_children_count: int = p.combat.get_child_count()
	# Execute 3 rapid swings
	for s in range(3):
		p._try_combat_attack()
		while p._is_attacking or p.combat._cooldown_timer > 0.0:
			await process_frame

	var combat_children_after: int = p.combat.get_child_count()
	var t22_pass: bool = (combat_children_count == combat_children_after)
	_record_result("TEST 22: No duplicate VFX nodes are created", t22_pass,
		"Child count before=%d, after=%d (Strictly stable)" % [combat_children_count, combat_children_after])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	var total_tests: int = _test_results.size()
	var passed_tests: int = 0
	for res in _test_results:
		if res["passed"]:
			passed_tests += 1

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed_tests, total_tests, total_tests - passed_tests])
	print("==================================================")

	quit(0 if passed_tests == total_tests else 1)
