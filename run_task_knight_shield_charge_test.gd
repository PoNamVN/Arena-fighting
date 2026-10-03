extends SceneTree

var _passes: int = 0
var _failures: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK: KNIGHT Z — GIANT SHIELD CHARGE TEST")
	print("==================================================")
	call_deferred("_run_all_tests")


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("[PASS] %s" % message)
	else:
		_failures += 1
		print("[FAIL] %s" % message)


func _run_all_tests() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	if not arena_scene:
		print("[FAIL] Failed to load CombatTestArena.tscn")
		quit(1)
		return

	var arena: Node3D = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.find_child("Player", true, false) as PlayerController
	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	assert_true(p != null and dummy != null, "TEST 1: Player and TrainingDummy initialized in test arena")

	p.hero_profile = "knight"
	p.equip_knight_loadout()
	await process_frame

	var asys: AbilitySystem = p.ability_system
	var sc: StaminaComponent = p.stamina_component
	var s1: AbilityData = asys.get_ability("skill_1")
	# Keep the movement measurement clear of the arena's nearby attack dummy.
	p.global_position = Vector3(0.0, 0.1, 10.0)
	p._camera_yaw = 0.0
	for frame: int in range(4):
		await physics_frame
		await process_frame

	# 1. Config & Activation test
	assert_true(s1 != null and s1.id == "shield_charge" and s1.damage == 25.0 and s1.stamina_cost == 20.0 and s1.cooldown == 4.0, "TEST 2: Skill 1 data matches Giant Shield Charge (25 dmg, 20 sta, 4s cd)")

	# 2. Stamina requirement: fail if stamina < 20
	sc.current_stamina = 15.0
	var low_sta_cast: bool = p._try_cast_ability("skill_1")
	assert_true(not low_sta_cast, "TEST 3: Shield Charge rejected when stamina < 20")

	# 3. Successful activation and stamina consumption
	sc.current_stamina = 50.0
	asys.reset_cooldowns()
	var cast_ok: bool = p._try_cast_ability("skill_1")
	assert_true(cast_ok, "TEST 4: Shield Charge cast successfully with sufficient stamina")
	assert_true(sc.current_stamina == 30.0, "TEST 5: Stamina correctly deducted by 20.0 (50 -> 30)")

	# 4. Cooldown active & re-cast lockout
	assert_true(asys.get_cooldown_remaining("skill_1") > 3.5, "TEST 6: Cooldown active (~4.0s)")
	var recast: bool = p._try_cast_ability("skill_1")
	assert_true(not recast, "TEST 7: Cannot re-trigger Z while active or on cooldown")

	# 5. Shield enlargement during startup
	assert_true(p.is_shield_enlarged, "TEST 8: Shield visibly enlarges during startup/active phase")
	assert_true(p.active_ability_action != null and p.active_ability_action.is_active(), "TEST 9: AbilityAction is active")

	# 6. Real charge movement & steering (advance through startup into active phase)
	p.active_ability_action.phase_timer = 0.001
	p.active_ability_action.update(0.01) # Transition to ACTIVE phase
	assert_true(p.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE, "TEST 10: Transitioned to ACTIVE charge phase")

	var pos_before: Vector3 = p.global_position
	p._camera_yaw = 0.0 # Facing forward (-Z)
	for i in range(15):
		await physics_frame
		await process_frame
	var pos_after: Vector3 = p.global_position
	var moved_dist: float = (pos_after - pos_before).length()
	assert_true(moved_dist > 0.5, "TEST 11: Real charge movement occurred via physics (moved %.2fm, no teleport)" % moved_dist)

	# 7. Steering turn rate limit (turn camera 90° / 1.57 rad; step should be limited)
	var prev_yaw: float = p.visuals.rotation.y
	p._camera_yaw = prev_yaw + 1.57
	p._process_shield_charge(0.02) # 20ms physics step
	var current_yaw: float = p.visuals.rotation.y
	var turn_diff: float = abs(wrapf(current_yaw - prev_yaw, -PI, PI))
	var max_allowed_turn: float = p.steering_turn_rate * 0.02 + 0.01 # ~0.15 rad
	assert_true(turn_diff <= max_allowed_turn and turn_diff > 0.01, "TEST 12: Steering respects turn rate limit (turned %.3f rad, max allowed %.3f rad, no instant snapping)" % [turn_diff, max_allowed_turn])

	# 8. Front protection: Frontal incoming attack deals 0 damage to HP and 0 damage to shield
	var attacker_front: Vector3 = p.global_position + (-p.visuals.global_basis.z) * 2.0
	var hp_before_front: float = p.health_component.current_health
	var shield_before_front: float = p.shield_durability
	p.take_damage(30.0, attacker_front, 15.0)
	assert_true(p.health_component.current_health == hp_before_front, "TEST 13: Frontal attack 100%% blocked by enlarged shield (HP unaffected)")
	assert_true(p.shield_durability == shield_before_front, "TEST 14: Frontal attack does NOT degrade shield durability during charge")

	# 9. Side/back vulnerability: Attack from behind hits player normally
	var attacker_behind: Vector3 = p.global_position - (-p.visuals.global_basis.z) * 2.0
	var hp_before_back: float = p.health_component.current_health
	p.take_damage(20.0, attacker_behind, 10.0)
	assert_true(p.health_component.current_health < hp_before_back, "TEST 15: Flank/rear attack bypasses shield charge protection and deals damage")

	# 10. Collision, damage, and single hit per cast
	dummy.global_position = p.global_position + (-p.visuals.global_basis.z) * 1.8 # In charge range, away from the old snap distance
	var dummy_hp_before: float = dummy.health_component.current_health
	var position_before_impact: Vector3 = p.global_position
	p._check_shield_charge_hit(-p.visuals.global_basis.z)
	assert_true(dummy.health_component.current_health == dummy_hp_before - 25.0, "TEST 16: Collision dealt 25 damage to enemy dummy")
	assert_true(p.global_position.is_equal_approx(position_before_impact), "Impact stops at physics position without teleporting toward the recoiling target")

	# 11. Stagger verification: TrainingDummy flinched / registered hit reaction
	assert_true(dummy._hit_reaction_count > 0, "TEST 17: Enemy dummy received stagger/hit reaction on impact")

	# 12. No duplicate damage: Second collision check in same cast must not damage dummy again
	var dummy_hp_second: float = dummy.health_component.current_health
	p._check_shield_charge_hit(-p.visuals.global_basis.z)
	assert_true(dummy.health_component.current_health == dummy_hp_second, "TEST 18: Single hit per cast enforced (no duplicate damage on subsequent frames)")

	# 13. Recovery phase & shield retraction
	p.active_ability_action.phase_timer = 0.001
	p.active_ability_action.update(0.01) # Transition to RECOVERY phase
	assert_true(p.active_ability_action.current_phase == AbilityAction.Phase.RECOVERY, "TEST 19: Transitioned to RECOVERY phase")
	assert_true(not p.is_shield_enlarged, "TEST 20: Shield retracted upon entering recovery")

	# 14. Completion of recovery & immediate LMB combo availability
	p.active_ability_action.phase_timer = 0.001
	p.active_ability_action.update(0.01) # Advance past recovery to FINISHED
	assert_true(p.active_ability_action == null, "TEST 21: AbilityAction finished and cleaned up")
	var lmb_combo_ok: bool = p._try_combat_attack()
	assert_true(lmb_combo_ok and p.combat_state == PlayerController.CombatState.ATTACK and p._combo_step == 1, "TEST 22: Existing LMB 3-hit combo immediately usable after recovery")
	p._attack_impact_applied = true
	p._on_animation_finished("attack")
	p._combo_finisher_recovery_timer = 0.0
	p.reset_combo()
	p.transition_to(PlayerController.CombatState.IDLE)

	# 15. Death cancellation: Dying during charge cancels action cleanly
	sc.current_stamina = 100.0
	asys.reset_cooldowns()
	var cast_before_death: bool = p._try_cast_ability("skill_1")
	assert_true(cast_before_death and p.is_shield_enlarged and p.active_ability_action != null, "TEST 23: Shield Charge active prior to death test")
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(not p.is_shield_enlarged, "TEST 24: Shield retracted immediately upon death")
	assert_true(p.active_ability_action == null, "TEST 25: Active ability action cancelled cleanly on death")
	assert_true(p.combat_state == PlayerController.CombatState.DEAD, "TEST 26: Character firmly in DEAD state")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
