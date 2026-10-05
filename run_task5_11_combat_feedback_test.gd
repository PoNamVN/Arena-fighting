extends SceneTree

# ==============================================================================
# Acceptance Test Suite for Task 5.11: Combat Feedback Polish
# ==============================================================================

var _total_tests: int = 0
var _passed_tests: int = 0
var _failed_tests: int = 0


func _record_result(test_name: String, condition: bool, details: String = "") -> void:
	_total_tests += 1
	if condition:
		_passed_tests += 1
		print("  [PASS] %s%s" % [test_name, " - " + details if details != "" else ""])
	else:
		_failed_tests += 1
		print("  [FAIL] %s%s" % [test_name, " - " + details if details != "" else ""])


func _init() -> void:
	print("\n==================================================")
	print("RUNNING TASK 5.11 ACCEPTANCE TESTS: COMBAT FEEDBACK POLISH")
	print("==================================================")
	call_deferred("_run_tests")


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
	# -----------------------------------------------------------------
	# TEST 1: Combat Arena loads successfully
	# -----------------------------------------------------------------
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: CombatTestArena = arena_scene.instantiate() as CombatTestArena
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.player
	var ad: AttackTrainingDummy = arena.attack_dummy
	var td: TrainingDummy = arena.training_dummy
	var combat: PlayerCombat = p.combat
	# Opt in here to retain coverage of the optional legacy VFX geometry.
	combat.show_basic_attack_trail = true
	combat.show_basic_attack_telegraph = true

	# Ensure attack dummy doesn't auto-swing during test setup
	ad.set("auto_attack", false)
	var ad_tween: Tween = ad.get("_cycle_tween")
	if ad_tween and ad_tween.is_valid():
		ad_tween.kill()

	var ad_initial_pos: Vector3 = ad.global_position

	var t1_pass: bool = (arena != null and is_instance_valid(arena) and p != null and ad != null and td != null)
	_record_result("TEST 1: Combat Arena loads successfully", t1_pass,
		"Arena, Player, TrainingDummy, and AttackDummy instances verified")

	# -----------------------------------------------------------------
	# TEST 2: Crosshair is completely removed from scene tree
	# -----------------------------------------------------------------
	var crosshairs: Array[Node] = arena.find_children("Crosshair", "", true, false)
	var t2_pass: bool = crosshairs.is_empty()
	_record_result("TEST 2: Crosshair is completely removed from scene tree", t2_pass,
		"Crosshair count: %d (Expected 0)" % crosshairs.size())
	var feedback: CombatFeedback = p.combat_feedback

	# -----------------------------------------------------------------
	# TEST 3: Valid target produces target detection state
	# -----------------------------------------------------------------
	td.global_position = Vector3(3.5, 0, 0)
	td.rotation = Vector3.ZERO
	p.set_third_person(true)
	p.global_position = Vector3(3.5, 0, 1.8) # 1.8m from dummy, facing -Z
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	if feedback:
		feedback.update_target_detection()
	await process_frame
	var t3_pass: bool = (feedback != null and feedback.has_target)
	_record_result("TEST 3: Valid target produces target detection state", t3_pass,
		"Target detected: %s" % str(feedback.has_target if feedback else false))

	# -----------------------------------------------------------------
	# TEST 4: No target clears target detection state
	# -----------------------------------------------------------------
	p.global_position = Vector3(3.5, 0, 10.0) # 10m away, out of range
	await process_frame
	if feedback:
		feedback.update_target_detection()
	await process_frame
	var t4_pass: bool = (feedback != null and not feedback.has_target)
	_record_result("TEST 4: No target clears target detection state", t4_pass,
		"Target detected: %s" % str(feedback.has_target if feedback else false))

	# -----------------------------------------------------------------
	# TEST 5: Normal attack still deals exactly 25 damage
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	var hp_before_t7: float = td.health_component.current_health
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var hp_after_t7: float = td.health_component.current_health
	var damage_t7: float = hp_before_t7 - hp_after_t7
	var t7_pass: bool = (damage_t7 == 25.0)
	_record_result("TEST 5: Normal attack still deals exactly 25 damage", t7_pass,
		"Damage dealt: %.2f (Expected 25.0)" % damage_t7)

	# -----------------------------------------------------------------
	# TEST 6: Normal confirmed hit triggers target hit feedback
	# -----------------------------------------------------------------
	var t8_pass: bool = td.is_flashing_hit or td._mesh_material.albedo_color == td.hit_color
	_record_result("TEST 6: Normal confirmed hit triggers target hit feedback", t8_pass,
		"is_flashing_hit: %s" % str(td.is_flashing_hit))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 7: Miss does not trigger target hit feedback
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = PI # Turn 180 degrees away
	p.camera_pivot.rotation.y = PI
	p.visuals.rotation.y = PI
	await process_frame
	var hp_before_t9: float = td.health_component.current_health
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var hp_after_t9: float = td.health_component.current_health
	var t9_pass: bool = (hp_before_t9 == hp_after_t9) and (not td.is_flashing_hit)
	_record_result("TEST 7: Miss does not trigger target hit feedback", t9_pass,
		"Target HP unchanged: %s, is_flashing_hit: %s" % [str(hp_before_t9 == hp_after_t9), str(td.is_flashing_hit)])
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 8: Out-of-range attack does not trigger target hit feedback
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.global_position = Vector3(3.5, 0, 4.5) # 4.5m away (beyond 2.2m)
	p._camera_yaw = 0.0 # Facing North at dummy
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	var hp_before_t10: float = td.health_component.current_health
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var hp_after_t10: float = td.health_component.current_health
	var t10_pass: bool = (hp_before_t10 == hp_after_t10) and (not td.is_flashing_hit)
	_record_result("TEST 8: Out-of-range attack does not trigger target hit feedback", t10_pass,
		"Target HP unchanged: %s, is_flashing_hit: %s" % [str(hp_before_t10 == hp_after_t10), str(td.is_flashing_hit)])
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 9: Blocked attack still deals exactly 3.75 damage
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.rotation.y = PI
	td.is_blocking = true
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	var hp_before_t11: float = td.health_component.current_health
	var shield_before_t11: float = td.shield_durability
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var hp_after_t11: float = td.health_component.current_health
	var damage_t11: float = hp_before_t11 - hp_after_t11
	var t11_pass: bool = is_equal_approx(damage_t11, 3.75)
	_record_result("TEST 9: Blocked attack still deals exactly 3.75 damage", t11_pass,
		"Blocked damage: %.2f (Expected 3.75)" % damage_t11)

	# -----------------------------------------------------------------
	# TEST 10: Blocked attack still removes exactly 15 shield durability
	# -----------------------------------------------------------------
	var shield_after_t12: float = td.shield_durability
	var shield_damage_t12: float = shield_before_t11 - shield_after_t12
	var t12_pass: bool = is_equal_approx(shield_damage_t12, 15.0)
	_record_result("TEST 10: Blocked attack still removes exactly 15 shield durability", t12_pass,
		"Shield damage: %.2f (Expected 15.0)" % shield_damage_t12)

	# -----------------------------------------------------------------
	# TEST 11: Blocked attack triggers Block Impact VFX
	# -----------------------------------------------------------------
	var t13_pass: bool = (combat.block_impact_vfx != null and combat.block_impact_vfx.visible)
	_record_result("TEST 11: Blocked attack triggers Block Impact VFX", t13_pass,
		"BlockImpactVFX visible: %s" % str(t13_pass))

	# -----------------------------------------------------------------
	# TEST 12: Blocked attack does NOT trigger normal Hit Impact VFX
	# -----------------------------------------------------------------
	var t14_pass: bool = (combat.hit_impact_vfx != null and not combat.hit_impact_vfx.visible)
	_record_result("TEST 12: Blocked attack does NOT trigger normal Hit Impact VFX", t14_pass,
		"HitImpactVFX visible: %s (Expected false)" % str(combat.hit_impact_vfx.visible if combat.hit_impact_vfx else false))

	# -----------------------------------------------------------------
	# TEST 13: Blocked attack does NOT trigger normal damage flash
	# -----------------------------------------------------------------
	var t15_pass: bool = (td._mesh_material != null and td._mesh_material.albedo_color != td.hit_color)
	_record_result("TEST 13: Blocked attack does NOT trigger normal damage flash", t15_pass,
		"Target material albedo_color != hit_color: %s" % str(t15_pass))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 14: Shield Break still occurs at shield 0
	# -----------------------------------------------------------------
	# Deplete dummy shield: was 85, hit 5 more times to drop to 10 then 0
	for i in range(5):
		td.rotation.y = PI
		td.is_blocking = true
		p._try_combat_attack()
		await _wait_for_player_attack_impact(p)
		await _wait_for_player_attack_finish(p)

	# One final hit to break from 10 -> 0
	td.rotation.y = PI
	td.is_blocking = true
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var t16_pass: bool = (td.shield_durability == 0.0 and td.is_shield_broken)
	_record_result("TEST 14: Shield Break still occurs at shield 0", t16_pass,
		"Shield durability: %.1f, is_shield_broken: %s" % [td.shield_durability, str(td.is_shield_broken)])

	# -----------------------------------------------------------------
	# TEST 15: Shield Break still produces ShieldBreakVFX
	# -----------------------------------------------------------------
	var t17_pass: bool = (combat.shield_break_vfx != null and combat.shield_break_vfx.visible)
	_record_result("TEST 15: Shield Break still produces ShieldBreakVFX", t17_pass,
		"ShieldBreakVFX visible: %s" % str(t17_pass))

	# -----------------------------------------------------------------
	# TEST 16: Shield Break still produces stronger stagger
	# -----------------------------------------------------------------
	var t18_pass: bool = (td.get("_flinch_tween") != null and (td.get("_flinch_tween") as Tween).is_valid())
	_record_result("TEST 16: Shield Break still produces stronger stagger", t18_pass,
		"Flinch tween valid: %s" % str(t18_pass))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 17: Shield Break camera feedback is temporary
	# -----------------------------------------------------------------
	p.apply_camera_recoil(2) # SHIELD_BREAK
	var break_kick_active: bool = (p.get_camera_recoil_pitch() > deg_to_rad(2.5))
	for f in range(40):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	var break_kick_cleared: bool = is_zero_approx(p.get_camera_recoil_pitch())
	var t19_pass: bool = break_kick_active and break_kick_cleared
	_record_result("TEST 17: Shield Break camera feedback is temporary", t19_pass,
		"Kicked active: %s, returned to zero: %s" % [str(break_kick_active), str(break_kick_cleared)])

	# -----------------------------------------------------------------
	# TEST 18: Normal hit camera feedback is temporary
	# -----------------------------------------------------------------
	p.apply_camera_recoil(0) # NORMAL_HIT
	var hit_kick_active: bool = (p.get_camera_recoil_pitch() > deg_to_rad(1.0))
	for f in range(35):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	var hit_kick_cleared: bool = is_zero_approx(p.get_camera_recoil_pitch())
	var t20_pass: bool = hit_kick_active and hit_kick_cleared
	_record_result("TEST 18: Normal hit camera feedback is temporary", t20_pass,
		"Kicked active: %s, returned to zero: %s" % [str(hit_kick_active), str(hit_kick_cleared)])

	# -----------------------------------------------------------------
	# TEST 19: Block camera feedback is temporary
	# -----------------------------------------------------------------
	p.apply_camera_recoil(1) # BLOCK
	var block_kick_active: bool = (p.get_camera_recoil_pitch() > deg_to_rad(0.4))
	for f in range(30):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	var block_kick_cleared: bool = is_zero_approx(p.get_camera_recoil_pitch())
	var t21_pass: bool = block_kick_active and block_kick_cleared
	_record_result("TEST 19: Block camera feedback is temporary", t21_pass,
		"Kicked active: %s, returned to zero: %s" % [str(block_kick_active), str(block_kick_cleared)])

	# -----------------------------------------------------------------
	# TEST 20: Repeated camera feedback produces no camera drift
	# -----------------------------------------------------------------
	var initial_pitch: float = p._camera_pitch
	var initial_yaw: float = p._camera_yaw
	# Trigger 10 normal hits, 10 blocks, 10 shield-break kicks
	for i in range(10):
		p.apply_camera_recoil(0)
	for i in range(10):
		p.apply_camera_recoil(1)
	for i in range(10):
		p.apply_camera_recoil(2)
	# Wait for all recoil tweens to settle
	for f in range(50):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	var final_pitch: float = p.camera_pivot.rotation.x
	var final_yaw: float = p.camera_pivot.rotation.y
	var pitch_drift: float = absf(final_pitch - initial_pitch)
	var yaw_drift: float = absf(final_yaw - initial_yaw)
	var t22_pass: bool = (pitch_drift < 0.0001 and yaw_drift < 0.0001)
	_record_result("TEST 20: Repeated camera feedback produces no camera drift", t22_pass,
		"Pitch drift: %.6f rad, Yaw drift: %.6f rad" % [pitch_drift, yaw_drift])

	# -----------------------------------------------------------------
	# TEST 21: FPS normal-hit feedback works
	# -----------------------------------------------------------------
	p.set_third_person(false)
	await process_frame
	p.apply_camera_recoil(0)
	var t23_pass: bool = (p.get_camera_recoil_pitch() > 0.0)
	for f in range(35):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	t23_pass = t23_pass and is_zero_approx(p.get_camera_recoil_pitch())
	_record_result("TEST 21: FPS normal-hit feedback works", t23_pass,
		"FPS normal hit feedback triggered and returned to baseline")

	# -----------------------------------------------------------------
	# TEST 22: FPS block feedback works
	# -----------------------------------------------------------------
	p.apply_camera_recoil(1)
	var t24_pass: bool = (p.get_camera_recoil_pitch() > 0.0)
	for f in range(30):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	t24_pass = t24_pass and is_zero_approx(p.get_camera_recoil_pitch())
	_record_result("TEST 22: FPS block feedback works", t24_pass,
		"FPS block feedback triggered and returned to baseline")

	# -----------------------------------------------------------------
	# TEST 23: FPS shield-break feedback works
	# -----------------------------------------------------------------
	p.apply_camera_recoil(2)
	var t25_pass: bool = (p.get_camera_recoil_pitch() > 0.0)
	for f in range(40):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	t25_pass = t25_pass and is_zero_approx(p.get_camera_recoil_pitch())
	_record_result("TEST 23: FPS shield-break feedback works", t25_pass,
		"FPS shield break feedback triggered and returned to baseline")

	# -----------------------------------------------------------------
	# TEST 24: TPS normal-hit feedback works
	# -----------------------------------------------------------------
	p.set_third_person(true)
	await process_frame
	p.apply_camera_recoil(0)
	var t26_pass: bool = (p.get_camera_recoil_pitch() > 0.0)
	for f in range(35):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	t26_pass = t26_pass and is_zero_approx(p.get_camera_recoil_pitch())
	_record_result("TEST 24: TPS normal-hit feedback works", t26_pass,
		"TPS normal hit feedback triggered and returned to baseline")

	# -----------------------------------------------------------------
	# TEST 25: TPS block feedback works
	# -----------------------------------------------------------------
	p.apply_camera_recoil(1)
	var t27_pass: bool = (p.get_camera_recoil_pitch() > 0.0)
	for f in range(30):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	t27_pass = t27_pass and is_zero_approx(p.get_camera_recoil_pitch())
	_record_result("TEST 25: TPS block feedback works", t27_pass,
		"TPS block feedback triggered and returned to baseline")

	# -----------------------------------------------------------------
	# TEST 26: TPS shield-break feedback works
	# -----------------------------------------------------------------
	p.apply_camera_recoil(2)
	var t28_pass: bool = (p.get_camera_recoil_pitch() > 0.0)
	for f in range(40):
		await process_frame
		if is_zero_approx(p.get_camera_recoil_pitch()):
			break
	t28_pass = t28_pass and is_zero_approx(p.get_camera_recoil_pitch())
	_record_result("TEST 26: TPS shield-break feedback works", t28_pass,
		"TPS shield break feedback triggered and returned to baseline")

	# -----------------------------------------------------------------
	# TEST 27: Miss produces no damage number
	# -----------------------------------------------------------------
	combat.damage_number_pool.stop_all()
	td.reset_dummy()
	p.global_position = Vector3(3.5, 0, 10.0) # Miss
	await process_frame
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var active_numbers_miss: int = combat.damage_number_pool.get_active_count()
	var t29_pass: bool = (active_numbers_miss == 0)
	_record_result("TEST 27: Miss produces no damage number", t29_pass,
		"Active damage numbers: %d (Expected 0)" % active_numbers_miss)
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 28: Miss produces no Hit Impact VFX
	# -----------------------------------------------------------------
	var t30_pass: bool = (combat.hit_impact_vfx != null and not combat.hit_impact_vfx.visible)
	_record_result("TEST 28: Miss produces no Hit Impact VFX", t30_pass,
		"HitImpactVFX visible: %s (Expected false)" % str(combat.hit_impact_vfx.visible if combat.hit_impact_vfx else false))

	# -----------------------------------------------------------------
	# TEST 29: Miss produces no knockback
	# -----------------------------------------------------------------
	var td_pos_before_miss: Vector3 = td.global_position
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var td_pos_after_miss: Vector3 = td.global_position
	var t31_pass: bool = td_pos_before_miss.distance_to(td_pos_after_miss) < 0.001
	_record_result("TEST 29: Miss produces no knockback", t31_pass,
		"Target position drift: %.5fm" % td_pos_before_miss.distance_to(td_pos_after_miss))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 30: Miss produces no target reaction
	# -----------------------------------------------------------------
	var td_hr_before_miss: int = td.get("_hit_reaction_count")
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var td_hr_after_miss: int = td.get("_hit_reaction_count")
	var t32_pass: bool = (td_hr_before_miss == td_hr_after_miss)
	_record_result("TEST 30: Miss produces no target reaction", t32_pass,
		"Hit reactions before: %d, after: %d" % [td_hr_before_miss, td_hr_after_miss])
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 31: Repeated hit feedback creates no permanent nodes
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._camera_yaw = 0.0
	p.camera_pivot.rotation.y = 0.0
	p.visuals.rotation.y = 0.0
	await process_frame
	var initial_node_count: int = get_node_count()
	for i in range(3):
		td.reset_dummy()
		p._try_combat_attack()
		await _wait_for_player_attack_impact(p)
		await _wait_for_player_attack_finish(p)
	# Wait for tweens to finish
	for f in range(30):
		await process_frame
	var final_node_count: int = get_node_count()
	var t33_pass: bool = (initial_node_count == final_node_count)
	_record_result("TEST 31: Repeated hit feedback creates no permanent nodes", t33_pass,
		"Node count before: %d, after: %d" % [initial_node_count, final_node_count])

	# -----------------------------------------------------------------
	# TEST 32: Repeated target state updates create no duplicate nodes
	# -----------------------------------------------------------------
	var node_count_before: int = arena.get_child_count()
	for i in range(10):
		feedback._set_target_state(true, td)
		feedback._set_target_state(false, null)
	var node_count_after: int = arena.get_child_count()
	var t32_nodes_pass: bool = (node_count_before == node_count_after)
	_record_result("TEST 32: Repeated target state updates create no duplicate nodes", t32_nodes_pass,
		"Node count before: %d, after: %d" % [node_count_before, node_count_after])

	# -----------------------------------------------------------------
	# TEST 33: Existing Slash Arc VFX still works
	# -----------------------------------------------------------------
	td.reset_dummy()
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var t35_pass: bool = (combat.slash_arc_vfx != null and combat.slash_arc_vfx.visible)
	_record_result("TEST 33: Existing Slash Arc VFX still works", t35_pass,
		"SlashArcVFX visible on attack apex: %s" % str(t35_pass))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 34: Existing Attack Telegraph still works
	# -----------------------------------------------------------------
	td.reset_dummy()
	combat.start_attack()
	combat.trigger_attack_telegraph(Vector3.FORWARD, 0.35)
	await process_frame
	var t36_pass: bool = (combat.attack_telegraph_vfx != null and combat.attack_telegraph_vfx.visible)
	_record_result("TEST 34: Existing Attack Telegraph still works", t36_pass,
		"AttackTelegraphVFX visible during windup: %s" % str(t36_pass))
	combat.attack_telegraph_vfx.stop()

	# -----------------------------------------------------------------
	# TEST 35: Existing Damage Number VFX still works
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	combat._cooldown_timer = 0.0
	p._attack_impact_applied = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var t37_pass: bool = (combat.damage_number_pool.get_active_count() > 0)
	_record_result("TEST 35: Existing Damage Number VFX still works", t37_pass,
		"Active damage numbers after hit: %d" % combat.damage_number_pool.get_active_count())
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 36: Existing Block Impact VFX still works
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.rotation.y = PI
	td.is_blocking = true
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var t38_pass: bool = (combat.block_impact_vfx != null and combat.block_impact_vfx.visible)
	_record_result("TEST 36: Existing Block Impact VFX still works", t38_pass,
		"BlockImpactVFX visible on block: %s" % str(t38_pass))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 37: Existing Shield Break VFX still works
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.rotation.y = PI
	td.shield_durability = 10.0 # Will break on next blocked hit
	td.is_blocking = true
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var t39_pass: bool = (combat.shield_break_vfx != null and combat.shield_break_vfx.visible)
	_record_result("TEST 37: Existing Shield Break VFX still works", t39_pass,
		"ShieldBreakVFX visible on break: %s" % str(t39_pass))
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 38: Attack impact remains exactly 0.35 seconds
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	# Check at 0.20s windup -> no damage yet
	for i in range(12):
		await process_frame
	var hp_windup: float = td.health_component.current_health
	await _wait_for_player_attack_impact(p)
	var hp_impact: float = td.health_component.current_health
	var t40_pass: bool = (hp_windup == 100.0 and hp_impact == 75.0)
	_record_result("TEST 38: Attack impact remains exactly 0.35 seconds", t40_pass,
		"Windup HP: %.1f, Impact HP: %.1f" % [hp_windup, hp_impact])
	await _wait_for_player_attack_finish(p)

	# -----------------------------------------------------------------
	# TEST 39: Block cone remains exactly 120 degrees
	# -----------------------------------------------------------------
	var t41_pass: bool = (p.block_cone_deg == 120.0 and td.block_cone_deg == 120.0)
	_record_result("TEST 39: Block cone remains exactly 120 degrees", t41_pass,
		"Player cone: %.1f deg, Dummy cone: %.1f deg" % [p.block_cone_deg, td.block_cone_deg])

	# -----------------------------------------------------------------
	# TEST 40: Normal knockback remains exactly 0.40m
	# -----------------------------------------------------------------
	var t42_pass: bool = (p.hit_knockback_distance == 0.40 and td.hit_knockback_distance == 0.40)
	_record_result("TEST 40: Normal knockback remains exactly 0.40m", t42_pass,
		"Player KB: %.2fm, Dummy KB: %.2fm" % [p.hit_knockback_distance, td.hit_knockback_distance])

	# -----------------------------------------------------------------
	# TEST 41: Block recoil remains exactly 0.08m
	# -----------------------------------------------------------------
	var t43_pass: bool = (p.block_recoil_distance == 0.08 and td.block_recoil_distance == 0.08)
	_record_result("TEST 41: Block recoil remains exactly 0.08m", t43_pass,
		"Player recoil: %.2fm, Dummy recoil: %.2fm" % [p.block_recoil_distance, td.block_recoil_distance])

	# -----------------------------------------------------------------
	# TEST 42: AttackTrainingDummy remains stationary
	# -----------------------------------------------------------------
	var ad_final_pos: Vector3 = ad.global_position
	var ad_drift: float = ad_final_pos.distance_to(ad_initial_pos)
	var t44_pass: bool = (ad_drift < 0.001)
	_record_result("TEST 42: AttackTrainingDummy remains stationary", t44_pass,
		"Initial: %s, Current: %s (Drift: %.5fm)" % [ad_initial_pos, ad_final_pos, ad_drift])

	# -----------------------------------------------------------------
	# TEST 43: AttackTrainingDummy attack range remains 2.2m
	# -----------------------------------------------------------------
	var t45_pass: bool = (ad.attack_range == 2.2)
	_record_result("TEST 43: AttackTrainingDummy attack range remains 2.2m", t45_pass,
		"AttackTrainingDummy range: %.1fm (Expected 2.2m)" % ad.attack_range)

	# -----------------------------------------------------------------
	# TEST 44: No duplicate damage occurs
	# -----------------------------------------------------------------
	td.reset_dummy()
	td.is_blocking = false
	p.global_position = Vector3(3.5, 0, 1.8)
	p._try_combat_attack()
	await _wait_for_player_attack_impact(p)
	var hp_after_impact_t46: float = td.health_component.current_health
	await _wait_for_player_attack_finish(p)
	var hp_after_finish_t46: float = td.health_component.current_health
	var t46_pass: bool = (hp_after_impact_t46 == 75.0 and hp_after_finish_t46 == 75.0)
	_record_result("TEST 44: No duplicate damage occurs", t46_pass,
		"Impact HP: %.1f, Finish HP: %.1f (Single 25.0 damage applied)" % [hp_after_impact_t46, hp_after_finish_t46])

	# -----------------------------------------------------------------
	# FINAL SUMMARY
	# -----------------------------------------------------------------
	print("\n==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passed_tests, _total_tests, _failed_tests])
	print("==================================================")

	quit(0 if _failed_tests == 0 else 1)
