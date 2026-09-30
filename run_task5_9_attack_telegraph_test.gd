extends SceneTree

const TestArenaScene: PackedScene = preload("res://scenes/CombatTestArena.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _attack_dummy: AttackTrainingDummy = null
var _training_dummy: TrainingDummy = null
var _hud: CombatTestHUD = null


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.9 ACCEPTANCE TESTS: ATTACK TELEGRAPH & IMPACT READABILITY")
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
	_attack_dummy = _arena.get_node("AttackTrainingDummy") as AttackTrainingDummy
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
	var ad: AttackTrainingDummy = _attack_dummy
	var td: TrainingDummy = _training_dummy
	var combat: PlayerCombat = p.combat
	var dummy_health: HealthComponent = td.get_node("HealthComponent") as HealthComponent

	# Disable automatic attacking on attack dummy initially
	ad.auto_attack = false
	var cycle_tween: Tween = ad.get("_cycle_tween")
	if cycle_tween and cycle_tween.is_valid():
		cycle_tween.kill()

	var dummy_initial_pos: Vector3 = ad.global_position
	var ad_tele: AttackTelegraphVFX = ad.attack_telegraph_vfx

	# -----------------------------------------------------------------
	# TEST 1: AttackTrainingDummy attack starts telegraph
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	p.reset_shield_durability()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	ad.trigger_attack_now()
	await process_frame # Frame 1 of attack sequence

	var t1_active: bool = (ad_tele != null and ad_tele.is_active and ad_tele.visible)
	_record_result("TEST 1: AttackTrainingDummy attack starts telegraph", t1_active,
		"Telegraph is_active=%s, visible=%s immediately after attack start" % [str(ad_tele.is_active if ad_tele else false), str(ad_tele.visible if ad_tele else false)])

	# -----------------------------------------------------------------
	# TEST 2: Telegraph is visible during wind-up
	# -----------------------------------------------------------------
	# Wait midway through wind-up (~0.15s into 0.35s windup)
	await create_timer(0.15).timeout
	await process_frame

	var t2_visible: bool = (ad_tele != null and ad_tele.is_active and ad_tele.visible and ad.is_attacking())
	_record_result("TEST 2: Telegraph is visible during wind-up", t2_visible,
		"At t=0.15s windup: is_active=%s, visible=%s, dummy is_attacking=%s" % [str(ad_tele.is_active if ad_tele else false), str(ad_tele.visible if ad_tele else false), str(ad.is_attacking())])

	# -----------------------------------------------------------------
	# TEST 3: Telegraph is positioned correctly
	# -----------------------------------------------------------------
	var tele_pos: Vector3 = ad_tele.global_position if ad_tele else Vector3.ZERO
	var horiz_dist_to_ad: float = Vector2(tele_pos.x - ad.global_position.x, tele_pos.z - ad.global_position.z).length()
	var t3_pass: bool = horiz_dist_to_ad < 0.2
	_record_result("TEST 3: Telegraph is positioned correctly", t3_pass,
		"Telegraph pos: %s, Distance to attacker center: %.3fm (Expected < 0.2m)" % [str(tele_pos), horiz_dist_to_ad])

	# -----------------------------------------------------------------
	# TEST 4: Telegraph direction matches attack direction
	# -----------------------------------------------------------------
	var dummy_fwd: Vector3 = -ad.visuals.global_basis.z if ad.visuals else -ad.global_basis.z
	dummy_fwd.y = 0.0
	dummy_fwd = dummy_fwd.normalized()
	var tele_dir: Vector3 = ad_tele.last_direction if ad_tele else Vector3.ZERO
	var dot_dir: float = dummy_fwd.dot(tele_dir)
	var t4_pass: bool = dot_dir > 0.95
	_record_result("TEST 4: Telegraph direction matches attack direction", t4_pass,
		"Dummy forward: %s, Telegraph dir: %s, Dot: %.3f (Expected > 0.95)" % [str(dummy_fwd), str(tele_dir), dot_dir])

	# -----------------------------------------------------------------
	# TEST 5: Telegraph disappears at impact
	# -----------------------------------------------------------------
	# Wait until impact timestamp arrives (0.35s total, ~0.22s remaining from 0.15s)
	while ad.is_attacking() and ad_tele.is_active:
		await process_frame
	await process_frame

	var t5_pass: bool = (not ad_tele.is_active and not ad_tele.visible)
	_record_result("TEST 5: Telegraph disappears at impact", t5_pass,
		"At impact: is_active=%s, visible=%s" % [str(ad_tele.is_active), str(ad_tele.visible)])

	# Wait for recovery to finish
	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout

	# -----------------------------------------------------------------
	# TEST 6: Damage still occurs only at 0.35s
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	await process_frame

	ad.trigger_attack_now()
	# Check at 0.15s (wind-up): damage must be 0
	await create_timer(0.15).timeout
	await process_frame
	var hp_mid_windup: float = p.health_component.current_health

	# Wait for impact at 0.35s
	while ad.is_attacking() and p.health_component.current_health == hp_mid_windup:
		await process_frame

	var hp_at_impact: float = p.health_component.current_health
	var damage_at_impact: float = hp_mid_windup - hp_at_impact
	var t6_pass: bool = (hp_mid_windup == 100.0 and abs(damage_at_impact - 25.0) < 0.01)
	_record_result("TEST 6: Damage still occurs only at 0.35s", t6_pass,
		"Mid-windup HP: %.1f, Post-impact HP: %.1f, Damage: %.1f" % [hp_mid_windup, hp_at_impact, damage_at_impact])

	# Wait for recovery
	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout

	# -----------------------------------------------------------------
	# TEST 7: No early damage
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	await process_frame

	ad.trigger_attack_now()
	await create_timer(0.10).timeout
	await process_frame
	var hp_early_1: float = p.health_component.current_health
	await create_timer(0.10).timeout
	await process_frame
	var hp_early_2: float = p.health_component.current_health
	ad.cancel_attack()
	await process_frame

	var t7_pass: bool = (hp_early_1 == 100.0 and hp_early_2 == 100.0)
	_record_result("TEST 7: No early damage", t7_pass,
		"HP at 0.10s: %.1f, HP at 0.20s: %.1f (Expected 100.0, 100.0)" % [hp_early_1, hp_early_2])

	# -----------------------------------------------------------------
	# TEST 8: Normal hit still deals exactly 25
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	var hp_before_t8: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout
	await process_frame

	var hp_after_t8: float = p.health_component.current_health
	var damage_t8: float = hp_before_t8 - hp_after_t8
	var t8_pass: bool = abs(damage_t8 - 25.0) < 0.01
	_record_result("TEST 8: Normal hit still deals exactly 25", t8_pass,
		"HP: %.1f -> %.1f, Damage: %.1f (Expected 25.0)" % [hp_before_t8, hp_after_t8, damage_t8])

	# -----------------------------------------------------------------
	# TEST 9: Blocked hit still deals exactly 3.75
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

	var hp_before_t9: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	await create_timer(0.15).timeout
	await process_frame

	var hp_after_t9: float = p.health_component.current_health
	var damage_t9: float = hp_before_t9 - hp_after_t9
	var t9_pass: bool = abs(damage_t9 - 3.75) < 0.01
	_record_result("TEST 9: Blocked hit still deals exactly 3.75", t9_pass,
		"Blocked HP damage: %.2f (Expected 3.75)" % damage_t9)

	# -----------------------------------------------------------------
	# TEST 10: Successful block still removes exactly 15 shield
	# -----------------------------------------------------------------
	var dur_t10: float = p.shield_durability
	var t10_pass: bool = abs(dur_t10 - 85.0) < 0.01
	_record_result("TEST 10: Successful block still removes exactly 15 shield", t10_pass,
		"Shield durability: %.1f (Expected 85.0)" % dur_t10)

	# -----------------------------------------------------------------
	# TEST 11: Block Impact VFX still works
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.velocity = Vector3.ZERO
	p.reset_shield_durability()
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	p.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	ad.trigger_attack_now()
	var block_vfx_detected: bool = false
	while ad.is_attacking():
		await process_frame
		if p.combat.block_impact_vfx and (p.combat.block_impact_vfx.visible or p.combat.block_impact_vfx.get("_active")):
			block_vfx_detected = true

	var t11_pass: bool = block_vfx_detected or (p.combat.block_impact_vfx and p.combat.block_impact_vfx.visible)
	_record_result("TEST 11: Block Impact VFX still works", t11_pass,
		"BlockImpactVFX visibility detected during block: %s" % str(t11_pass))

	# -----------------------------------------------------------------
	# TEST 12: Hit Impact VFX still works
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	ad.trigger_attack_now()
	var hit_vfx_detected: bool = false
	while ad.is_attacking():
		await process_frame
		if p.combat.hit_impact_vfx and p.combat.hit_impact_vfx.visible:
			hit_vfx_detected = true

	var t12_pass: bool = hit_vfx_detected or (p.combat.hit_impact_vfx and p.combat.hit_impact_vfx.visible)
	_record_result("TEST 12: Hit Impact VFX still works", t12_pass,
		"HitImpactVFX visibility detected during hit: %s" % str(t12_pass))

	# -----------------------------------------------------------------
	# TEST 13: Damage Number VFX still works
	# -----------------------------------------------------------------
	var latest_damage_num: DamageNumberVFX = p.combat.damage_number_pool.get_latest_instance()
	var t13_pass: bool = (latest_damage_num != null and latest_damage_num.last_hp_value > 0.0)
	_record_result("TEST 13: Damage Number VFX still works", t13_pass,
		"Latest damage number: value=%.1f, text='%s'" % [latest_damage_num.last_hp_value if latest_damage_num else 0.0, latest_damage_num.hp_label.text if (latest_damage_num and latest_damage_num.hp_label) else ""])

	# -----------------------------------------------------------------
	# TEST 14: Miss creates no damage
	# -----------------------------------------------------------------
	p.global_position = Vector3(5.0, 0, 5.0) # Completely away
	p.health_component.reset_health()
	await process_frame

	var hp_before_t14: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame

	var hp_after_t14: float = p.health_component.current_health
	var t14_pass: bool = (hp_before_t14 == hp_after_t14)
	_record_result("TEST 14: Miss creates no damage", t14_pass,
		"HP before: %.1f, HP after: %.1f (Zero damage on miss)" % [hp_before_t14, hp_after_t14])

	# -----------------------------------------------------------------
	# TEST 15: Out-of-range attack creates no damage
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 2.5) # > 2.2m from dummy at (0, 0, -1.8) (dist = 4.3m)
	p.health_component.reset_health()
	await process_frame

	var hp_before_t15: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame

	var hp_after_t15: float = p.health_component.current_health
	var t15_pass: bool = (hp_before_t15 == hp_after_t15)
	_record_result("TEST 15: Out-of-range attack creates no damage", t15_pass,
		"HP before: %.1f, HP after: %.1f (Zero damage out-of-range)" % [hp_before_t15, hp_after_t15])

	# -----------------------------------------------------------------
	# TEST 16: Cancelled attack removes telegraph
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	await process_frame

	ad.trigger_attack_now()
	await create_timer(0.12).timeout
	await process_frame
	var was_active_before_cancel: bool = ad_tele.is_active

	ad.cancel_attack()
	await process_frame

	var is_hidden_after_cancel: bool = (not ad_tele.is_active and not ad_tele.visible and not ad.is_attacking())
	var t16_pass: bool = (was_active_before_cancel and is_hidden_after_cancel)
	_record_result("TEST 16: Cancelled attack removes telegraph", t16_pass,
		"Before cancel: active=%s; After cancel: active=%s, visible=%s" % [str(was_active_before_cancel), str(ad_tele.is_active), str(ad_tele.visible)])

	# -----------------------------------------------------------------
	# TEST 17: Repeated attacks do not accumulate telegraph nodes
	# -----------------------------------------------------------------
	var ad_children_before: int = ad.get_child_count()
	var combat_children_before: int = combat.get_child_count()

	for swing in range(8):
		ad.trigger_attack_now()
		while ad.is_attacking():
			await process_frame
		await create_timer(0.05).timeout

	var ad_children_after: int = ad.get_child_count()
	var combat_children_after: int = combat.get_child_count()
	var t17_pass: bool = (ad_children_before == ad_children_after and combat_children_before == combat_children_after)
	_record_result("TEST 17: Repeated attacks do not accumulate telegraph nodes", t17_pass,
		"Dummy children: %d -> %d; Player combat children: %d -> %d" % [ad_children_before, ad_children_after, combat_children_before, combat_children_after])

	# -----------------------------------------------------------------
	# TEST 18: AttackTrainingDummy remains stationary
	# -----------------------------------------------------------------
	var dummy_drift: float = (ad.global_position - dummy_initial_pos).length()
	var t18_pass: bool = dummy_drift < 0.001
	_record_result("TEST 18: AttackTrainingDummy remains stationary", t18_pass,
		"Dummy drift: %.5fm (Expected 0.0m)" % dummy_drift)

	# -----------------------------------------------------------------
	# TEST 19: FPS behavior remains correct
	# -----------------------------------------------------------------
	p.set_third_person(false)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation.y = 0.0
	td.is_blocking = false
	dummy_health.reset_health()
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	await _wait_for_player_attack_finish(p)

	var hp_after_fps: float = dummy_health.current_health
	var t19_pass: bool = abs(hp_after_fps - 75.0) < 0.01
	_record_result("TEST 19: FPS behavior remains correct", t19_pass,
		"FPS attack dealt 25 damage: dummy HP = %.1f" % hp_after_fps)

	# -----------------------------------------------------------------
	# TEST 20: TPS behavior remains correct
	# -----------------------------------------------------------------
	p.set_third_person(true)
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.visuals.rotation.y = 0.0
	dummy_health.reset_health()
	await process_frame

	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	await _wait_for_player_attack_finish(p)

	var hp_after_tps: float = dummy_health.current_health
	var t20_pass: bool = abs(hp_after_tps - 75.0) < 0.01
	_record_result("TEST 20: TPS behavior remains correct", t20_pass,
		"TPS attack dealt 25 damage: dummy HP = %.1f" % hp_after_tps)

	# -----------------------------------------------------------------
	# TEST 21: Shield Break remains unchanged
	# -----------------------------------------------------------------
	p.shield_durability = 10.0
	p.apply_shield_damage(10.0)
	var t21_pass: bool = (p.is_shield_broken and p.shield_durability == 0.0 and p._shield_stun_timer > 0.0)
	_record_result("TEST 21: Shield Break remains unchanged", t21_pass,
		"is_shield_broken=%s, durability=%.1f, stun_timer=%.2fs" % [str(p.is_shield_broken), p.shield_durability, p._shield_stun_timer])

	# -----------------------------------------------------------------
	# TEST 22: Existing knockback/flinch remains unchanged
	# -----------------------------------------------------------------
	p.reset_shield_durability()
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	p.transition_to(PlayerController.CombatState.IDLE)
	await process_frame

	var hr_before: int = p.get("_hit_reaction_count")
	var pos_before: Vector3 = p.global_position

	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	await create_timer(0.20).timeout
	await process_frame

	var hr_after: int = p.get("_hit_reaction_count")
	var pos_after: Vector3 = p.global_position
	var kb_disp: float = Vector2(pos_after.x - pos_before.x, pos_after.z - pos_before.z).length()
	var t22_pass: bool = (hr_after - hr_before == 1) and (kb_disp >= 0.25 and kb_disp <= 0.55)
	_record_result("TEST 22: Existing knockback/flinch remains unchanged", t22_pass,
		"Hit reaction count: +%d, Knockback displacement: %.3fm" % [hr_after - hr_before, kb_disp])

	# -----------------------------------------------------------------
	# TEST 23: Slash Arc remains unchanged
	# -----------------------------------------------------------------
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	var slash_vfx_active: bool = false
	while not p._attack_impact_applied and p.combat_state == PlayerController.CombatState.ATTACK:
		await process_frame
	if combat.slash_arc_vfx and combat.slash_arc_vfx.visible:
		slash_vfx_active = true

	var t23_pass: bool = slash_vfx_active
	_record_result("TEST 23: Slash Arc remains unchanged", t23_pass,
		"SlashArcVFX visible on swing: %s" % str(slash_vfx_active))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 24: No duplicate damage is applied
	# -----------------------------------------------------------------
	p.global_position = Vector3(0, 0, 0)
	p.health_component.reset_health()
	await process_frame

	var hp_before_t24: float = p.health_component.current_health
	ad.trigger_attack_now()
	while ad.is_attacking():
		await process_frame
	await create_timer(0.30).timeout
	await process_frame

	var hp_after_t24: float = p.health_component.current_health
	var damage_t24: float = hp_before_t24 - hp_after_t24
	var t24_pass: bool = abs(damage_t24 - 25.0) < 0.01
	_record_result("TEST 24: No duplicate damage is applied", t24_pass,
		"Total damage from single attack: %.1f (Expected exactly 25.0)" % damage_t24)

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
