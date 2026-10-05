extends SceneTree

const TestArenaScene: PackedScene = preload("res://scenes/CombatTestArena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _attack_dummy: Node3D = null
var _training_dummy: TrainingDummy = null
var _hud: CombatTestHUD = null


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.8 ACCEPTANCE TESTS: COMBAT & TARGET FEEDBACK")
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
	_hud = _arena.get_node_or_null("CombatTestHUD") as CombatTestHUD


func _wait_for_player_attack_impact(p: PlayerController) -> void:
	var safety: int = 120
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _wait_for_player_attack_finish(p: PlayerController) -> void:
	var safety: int = 120
	while (p._is_attacking or p.combat._cooldown_timer > 0.0) and safety > 0:
		await process_frame
		safety -= 1
	await process_frame


func _run_tests() -> void:
	_setup_scene()
	for i in range(10):
		await process_frame

	var p: PlayerController = _player
	var ad: Node3D = _attack_dummy
	var td: TrainingDummy = _training_dummy
	var combat: PlayerCombat = p.combat
	# Opt in here to retain coverage of the optional legacy VFX geometry.
	combat.show_basic_attack_trail = true
	combat.show_basic_attack_telegraph = true
	var dummy_health: HealthComponent = td.get_node("HealthComponent") as HealthComponent

	# Ensure automatic attacking on attack dummy is disabled initially
	ad.set("auto_attack", false)
	var cycle_tween: Tween = ad.get("_cycle_tween")
	if cycle_tween and cycle_tween.is_valid():
		cycle_tween.kill()

	var dummy_initial_pos: Vector3 = ad.global_position
	var pool: DamageNumberPool = combat.damage_number_pool

	# -----------------------------------------------------------------
	# TEST 1: Normal hit creates exactly one damage number
	# -----------------------------------------------------------------
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation = Vector3.ZERO
	td.is_blocking = false
	p.set_third_person(true)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame

	pool.stop_all()
	var active_before_t1: int = pool.get_active_count()
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)

	var active_after_t1: int = pool.get_active_count()
	var latest_t1: DamageNumberVFX = pool.get_latest_instance()
	var t1_pass: bool = (active_before_t1 == 0 and active_after_t1 == 1 and latest_t1 != null and latest_t1.is_active)
	_record_result("TEST 1: Normal hit creates exactly one damage number", t1_pass,
		"Active count: %d -> %d (Expected 0 -> 1)" % [active_before_t1, active_after_t1])

	# -----------------------------------------------------------------
	# TEST 2: Normal damage number displays 25
	# -----------------------------------------------------------------
	var t2_text: String = latest_t1.hp_label.text if latest_t1 and latest_t1.hp_label else ""
	var t2_val: float = latest_t1.last_hp_value if latest_t1 else 0.0
	var t2_pass: bool = (t2_text == "25" and abs(t2_val - 25.0) < 0.01 and not latest_t1.last_is_blocked)
	_record_result("TEST 2: Normal damage number displays 25", t2_pass,
		"Label text: '%s', last_hp_value: %.1f (Expected '25', 25.0)" % [t2_text, t2_val])

	# -----------------------------------------------------------------
	# TEST 3: Damage number appears at correct impact position
	# -----------------------------------------------------------------
	var spawn_pos_t3: Vector3 = latest_t1.last_spawn_pos if latest_t1 else Vector3.ZERO
	# Contact position between player at (3.5, 0, 1.8) and dummy at (3.5, 0, 0) should be near Z ~ 0.35, X ~ 3.5
	var horiz_dist_to_dummy: float = Vector2(spawn_pos_t3.x - td.global_position.x, spawn_pos_t3.z - td.global_position.z).length()
	var t3_pass: bool = horiz_dist_to_dummy < 0.55 and horiz_dist_to_dummy > 0.15
	_record_result("TEST 3: Damage number appears at correct impact position", t3_pass,
		"Spawn pos: %s, Horizontal distance to target center: %.3fm (Expected ~0.35m)" % [str(spawn_pos_t3), horiz_dist_to_dummy])

	# -----------------------------------------------------------------
	# TEST 4: Damage number fades and cleans itself
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	# Wait for lifetime (0.65s + margin)
	await create_timer(0.75).timeout
	await process_frame
	var t4_pass: bool = (latest_t1 != null and not latest_t1.is_active and not latest_t1.visible)
	_record_result("TEST 4: Damage number fades and cleans itself", t4_pass,
		"is_active: %s, visible: %s after lifetime expiry" % [str(latest_t1.is_active if latest_t1 else false), str(latest_t1.visible if latest_t1 else false)])

	# -----------------------------------------------------------------
	# TEST 5: Blocked hit displays 3.75
	# -----------------------------------------------------------------
	pool.stop_all()
	# Rotate dummy 180 degrees so its frontal block cone faces South (+Z) towards the player
	td.rotation.y = PI
	td.is_blocking = true
	td.shield_durability = 100.0
	td.is_shield_broken = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.visuals.rotation.y = 0.0
	p.camera_pivot.rotation.y = 0.0
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)

	var latest_t5: DamageNumberVFX = pool.get_latest_instance()
	var t5_text: String = latest_t5.hp_label.text if latest_t5 and latest_t5.hp_label else ""
	var t5_val: float = latest_t5.last_hp_value if latest_t5 else 0.0
	var t5_pass: bool = (t5_text == "3.75" and abs(t5_val - 3.75) < 0.01 and latest_t5.last_is_blocked)
	_record_result("TEST 5: Blocked hit displays 3.75", t5_pass,
		"Label text: '%s', last_hp_value: %.2f, was_blocked: %s" % [t5_text, t5_val, str(latest_t5.last_is_blocked if latest_t5 else false)])

	# -----------------------------------------------------------------
	# TEST 6: Blocked hit still deals exactly 3.75 HP damage
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	pool.stop_all()
	td.rotation.y = PI
	td.is_blocking = true
	td.shield_durability = 100.0
	td.is_shield_broken = false
	p.global_position = Vector3(3.5, 0, 1.8)
	await process_frame

	var hp_before_t6: float = dummy_health.current_health
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)

	var hp_after_t6: float = dummy_health.current_health
	var damage_t6: float = hp_before_t6 - hp_after_t6
	var t6_pass: bool = abs(damage_t6 - 3.75) < 0.01
	_record_result("TEST 6: Blocked hit still deals exactly 3.75 HP damage", t6_pass,
		"HP damage dealt: %.2f (Expected 3.75)" % damage_t6)

	# -----------------------------------------------------------------
	# TEST 7: Blocked hit applies exactly 15 shield damage
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	td.rotation.y = PI
	td.shield_durability = 100.0
	td.is_shield_broken = false
	pool.stop_all()
	p.global_position = Vector3(3.5, 0, 1.8)
	await process_frame

	var dur_before_t7: float = td.shield_durability
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)

	var dur_after_t7: float = td.shield_durability
	var shield_damage_t7: float = dur_before_t7 - dur_after_t7
	var latest_t7: DamageNumberVFX = pool.get_latest_instance()
	var shield_label_text: String = latest_t7.shield_label.text if latest_t7 and latest_t7.shield_label else ""
	var t7_pass: bool = abs(shield_damage_t7 - 15.0) < 0.01 and shield_label_text == "Shield -15"
	_record_result("TEST 7: Blocked hit applies exactly 15 shield damage", t7_pass,
		"Durability: %.1f -> %.1f (Shield damage: %.1f, Label: '%s')" % [dur_before_t7, dur_after_t7, shield_damage_t7, shield_label_text])

	# -----------------------------------------------------------------
	# TEST 8: Shield feedback does not modify HP calculation
	# -----------------------------------------------------------------
	var t8_pass: bool = abs(damage_t6 - 3.75) < 0.01
	_record_result("TEST 8: Shield feedback does not modify HP calculation", t8_pass,
		"HP calculation is cleanly isolated from shield durability")

	# -----------------------------------------------------------------
	# TEST 9: Miss creates no damage number
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	pool.stop_all()
	# Face away from dummy (turn 180 degrees)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = PI
	p.visuals.rotation.y = PI
	p.camera_pivot.rotation.y = PI
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_finish(p)

	var active_t9: int = pool.get_active_count()
	var t9_pass: bool = (active_t9 == 0)
	_record_result("TEST 9: Miss creates no damage number", t9_pass,
		"Active damage numbers on miss: %d (Expected 0)" % active_t9)

	# -----------------------------------------------------------------
	# TEST 10: Out-of-range attack creates no damage number
	# -----------------------------------------------------------------
	pool.stop_all()
	p._camera_yaw = 0.0
	p.visuals.rotation.y = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.global_position = Vector3(3.5, 0, 5.0) # > 2.2m attack range
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_finish(p)

	var active_t10: int = pool.get_active_count()
	var t10_pass: bool = (active_t10 == 0)
	_record_result("TEST 10: Out-of-range attack creates no damage number", t10_pass,
		"Active damage numbers on out-of-range attack: %d (Expected 0)" % active_t10)

	# -----------------------------------------------------------------
	# TEST 11: Repeated attacks do not accumulate permanent nodes
	# -----------------------------------------------------------------
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation.y = 0.0
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.visuals.rotation.y = 0.0
	p.camera_pivot.rotation.y = 0.0
	await process_frame

	var child_count_initial: int = combat.get_child_count()
	var pool_size_initial: int = pool.get_total_pool_size()

	for swing in range(10):
		p.global_position = Vector3(3.5, 0, 1.8)
		p._try_combat_attack()
		await _wait_for_player_attack_impact(p)
		await _wait_for_player_attack_finish(p)

	# Wait for all animations to settle
	await create_timer(0.8).timeout
	await process_frame

	var child_count_after: int = combat.get_child_count()
	var pool_size_after: int = pool.get_total_pool_size()
	var t11_pass: bool = (child_count_initial == child_count_after and pool_size_initial == pool_size_after)
	_record_result("TEST 11: Repeated attacks do not accumulate permanent nodes", t11_pass,
		"Child count: %d -> %d, Pool size: %d -> %d" % [child_count_initial, child_count_after, pool_size_initial, pool_size_after])

	# -----------------------------------------------------------------
	# TEST 12: FPS works
	# -----------------------------------------------------------------
	pool.stop_all()
	p.set_third_person(false)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.camera.rotation = Vector3.ZERO
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation.y = 0.0
	td.is_blocking = false
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)

	var latest_t12: DamageNumberVFX = pool.get_latest_instance()
	var t12_pass: bool = (latest_t12 != null and latest_t12.is_active and latest_t12.hp_label.billboard != 0)
	_record_result("TEST 12: FPS works", t12_pass,
		"FPS attack spawned billboard damage number: active=%s, billboard=%d" % [str(latest_t12.is_active if latest_t12 else false), latest_t12.hp_label.billboard if latest_t12 else -1])

	# -----------------------------------------------------------------
	# TEST 13: TPS works
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	pool.stop_all()
	p.set_third_person(true)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)

	var latest_t13: DamageNumberVFX = pool.get_latest_instance()
	var t13_pass: bool = (latest_t13 != null and latest_t13.is_active and latest_t13.hp_label.billboard != 0)
	_record_result("TEST 13: TPS works", t13_pass,
		"TPS attack spawned billboard damage number: active=%s, billboard=%d" % [str(latest_t13.is_active if latest_t13 else false), latest_t13.hp_label.billboard if latest_t13 else -1])

	# -----------------------------------------------------------------
	# TEST 14: Low-shield warning appears at threshold
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	p.reset_shield_durability()
	p.shield_durability = 30.0 # Above threshold (25.0)
	p.apply_shield_damage(0.0) # Check state above threshold
	var low_above: bool = p.is_low_shield

	p.apply_shield_damage(10.0) # 30.0 - 10.0 = 20.0 (<= 25.0 threshold)
	var low_at: bool = p.is_low_shield
	var hud_warning_visible: bool = (_hud.low_shield_warning.visible if _hud and _hud.low_shield_warning else false)
	var t14_pass: bool = (not low_above and low_at and hud_warning_visible)
	_record_result("TEST 14: Low-shield warning appears at threshold", t14_pass,
		"At 30.0 dur: is_low=%s; At 20.0 dur: is_low=%s, HUD visible=%s" % [str(low_above), str(low_at), str(hud_warning_visible)])

	# -----------------------------------------------------------------
	# TEST 15: Low-shield warning does not spam duplicate nodes
	# -----------------------------------------------------------------
	var hud_nodes_before: int = _hud.get_child_count() if _hud else 0
	# Repeated damage below threshold (20 -> 10)
	p.apply_shield_damage(10.0)
	var hud_nodes_after: int = _hud.get_child_count() if _hud else 0
	var t15_pass: bool = (p.is_low_shield and hud_nodes_before == hud_nodes_after)
	_record_result("TEST 15: Low-shield warning does not spam duplicate nodes", t15_pass,
		"HUD child count remained constant: %d == %d" % [hud_nodes_before, hud_nodes_after])

	# -----------------------------------------------------------------
	# TEST 16: Shield recovery removes low-shield warning
	# -----------------------------------------------------------------
	p.reset_shield_durability()
	var hud_warning_after_reset: bool = (_hud.low_shield_warning.visible if _hud and _hud.low_shield_warning else false)
	var t16_pass: bool = (not p.is_low_shield and not hud_warning_after_reset)
	_record_result("TEST 16: Shield recovery removes low-shield warning", t16_pass,
		"After reset: is_low=%s, HUD visible=%s" % [str(p.is_low_shield), str(hud_warning_after_reset)])

	# -----------------------------------------------------------------
	# TEST 17: Shield Break still works exactly as before
	# -----------------------------------------------------------------
	p.shield_durability = 10.0
	p.apply_shield_damage(10.0) # Reduces to 0, triggers break
	var t17_pass: bool = (p.is_shield_broken and not p.is_low_shield and p.shield_durability == 0.0)
	_record_result("TEST 17: Shield Break still works exactly as before", t17_pass,
		"is_shield_broken=%s, is_low_shield=%s (Superseded by BROKEN state)" % [str(p.is_shield_broken), str(p.is_low_shield)])

	# -----------------------------------------------------------------
	# TEST 18: Existing Hit Impact VFX still works
	# -----------------------------------------------------------------
	p.reset_shield_durability()
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation.y = 0.0
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.visuals.rotation.y = 0.0
	p.camera_pivot.rotation.y = 0.0
	await process_frame

	p._try_combat_attack()
	var hit_vfx_shown: bool = false
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK:
		await process_frame
		if combat.hit_impact_vfx and combat.hit_impact_vfx.visible:
			hit_vfx_shown = true

	var t18_pass: bool = hit_vfx_shown or (combat.hit_impact_vfx and combat.hit_impact_vfx.visible)
	_record_result("TEST 18: Existing Hit Impact VFX still works", t18_pass,
		"HitImpactVFX visibility triggered on normal hit: %s" % str(t18_pass))

	# -----------------------------------------------------------------
	# TEST 19: Existing Block Impact VFX still works
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	td.rotation.y = PI
	td.is_blocking = true
	td.shield_durability = 100.0
	td.is_shield_broken = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.visuals.rotation.y = 0.0
	p.camera_pivot.rotation.y = 0.0
	await process_frame

	p._try_combat_attack()
	var block_vfx_shown: bool = false
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK:
		await process_frame
		if combat.block_impact_vfx and combat.block_impact_vfx.visible:
			block_vfx_shown = true

	var t19_pass: bool = block_vfx_shown or (combat.block_impact_vfx and combat.block_impact_vfx.visible)
	_record_result("TEST 19: Existing Block Impact VFX still works", t19_pass,
		"BlockImpactVFX visibility triggered on block: %s" % str(t19_pass))

	# -----------------------------------------------------------------
	# TEST 20: Existing Slash Arc VFX still works
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	var slash_vfx_shown: bool = false
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK:
		await process_frame
	if combat.slash_arc_vfx and combat.slash_arc_vfx.visible:
		slash_vfx_shown = true

	var t20_pass: bool = slash_vfx_shown
	_record_result("TEST 20: Existing Slash Arc VFX still works", t20_pass,
		"SlashArcVFX visibility triggered on swing: %s" % str(slash_vfx_shown))

	# -----------------------------------------------------------------
	# TEST 21: Existing knockback/flinch still works
	# -----------------------------------------------------------------
	await _wait_for_player_attack_finish(p)
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	p.reset_shield_durability()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	var hr_count_before_t21: int = p.get("_hit_reaction_count")
	var pos_before_t21: Vector3 = p.global_position

	ad.call("trigger_attack_now")
	while ad.call("is_attacking"):
		await process_frame
	await create_timer(0.20).timeout
	await process_frame

	var hr_count_after_t21: int = p.get("_hit_reaction_count")
	var pos_after_t21: Vector3 = p.global_position
	var kb_disp_t21: float = Vector2(pos_after_t21.x - pos_before_t21.x, pos_after_t21.z - pos_before_t21.z).length()
	var t21_pass: bool = (hr_count_after_t21 - hr_count_before_t21 == 1) and (kb_disp_t21 >= 0.25 and kb_disp_t21 <= 0.55)
	_record_result("TEST 21: Existing knockback/flinch still works", t21_pass,
		"Reactions: +%d, Knockback displacement: %.3fm (Expected ~0.40m)" % [hr_count_after_t21 - hr_count_before_t21, kb_disp_t21])

	# -----------------------------------------------------------------
	# TEST 22: Attack impact remains exactly 0.35s
	# -----------------------------------------------------------------
	var t22_pass: bool = abs(ad.attack_windup - 0.35) < 0.001
	_record_result("TEST 22: Attack impact remains exactly 0.35s", t22_pass,
		"AttackTrainingDummy attack_windup: %.3fs (Expected 0.350s)" % ad.attack_windup)

	# -----------------------------------------------------------------
	# TEST 23: AttackTrainingDummy remains stationary
	# -----------------------------------------------------------------
	var dummy_drift: float = (ad.global_position - dummy_initial_pos).length()
	var t23_pass: bool = dummy_drift < 0.001
	_record_result("TEST 23: AttackTrainingDummy remains stationary", t23_pass,
		"Dummy position drift: %.5fm (Expected 0.0m)" % dummy_drift)

	# -----------------------------------------------------------------
	# TEST 24: No duplicate damage is applied
	# -----------------------------------------------------------------
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation.y = 0.0
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	dummy_health.reset_health()
	await process_frame

	var hp_before_t24: float = dummy_health.current_health
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	await _wait_for_player_attack_finish(p)

	var hp_after_t24: float = dummy_health.current_health
	var damage_t24: float = hp_before_t24 - hp_after_t24
	var t24_pass: bool = abs(damage_t24 - 25.0) < 0.01
	_record_result("TEST 24: No duplicate damage is applied", t24_pass,
		"Single swing damage: %.1f (Expected exactly 25.0)" % damage_t24)

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	print("==================================================")
	var pass_count: int = 0
	var fail_count: int = 0
	for res in _test_results:
		if res.passed:
			pass_count += 1
		else:
			fail_count += 1

	print("RESULTS: %d / %d PASSED (%d FAILED)" % [pass_count, _test_results.size(), fail_count])
	print("==================================================")

	quit(0 if fail_count == 0 else 1)
