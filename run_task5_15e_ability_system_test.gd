extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15E: ABILITY SYSTEM & HERO SKILLS TEST")
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
	assert_true(p != null and p.ability_system != null, "TEST 1: Player and AbilitySystem initialized")

	var asys: AbilitySystem = p.ability_system
	var sc: StaminaComponent = p.stamina_component
	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	if dummy:
		dummy.global_position = p.global_position + Vector3(0, 0, -2.0)
	await process_frame
	await physics_frame

	# 1. Prototype skill definitions check
	var s1: AbilityData = asys.get_ability("skill_1")
	var s2: AbilityData = asys.get_ability("skill_2")
	var s3: AbilityData = asys.get_ability("skill_3")
	var ult: AbilityData = asys.get_ability("ultimate")

	assert_true(s1 != null and s1.damage == 35.0 and s1.stamina_cost == 20.0 and s1.cooldown == 3.0, "TEST 2: Skill 1 (Thrust) configured correctly")
	assert_true(s2 != null and s2.damage == 20.0 and s2.stamina_cost == 25.0 and s2.cooldown == 4.0, "TEST 3: Skill 2 (Shield Bash) configured correctly")
	assert_true(s3 != null and s3.damage == 40.0 and s3.stamina_cost == 35.0 and s3.cooldown == 6.0, "TEST 4: Skill 3 (Whirlwind AoE) configured correctly")
	assert_true(ult != null and ult.damage == 100.0 and ult.requires_full_stamina and ult.cooldown == 0.0, "TEST 5: Ultimate (Judgment Blade) configured correctly")

	# 2. Skill 1 Casting & Damage
	sc.current_stamina = 50.0
	var dummy_hp_before: float = dummy.health_component.current_health
	var cast_s1: bool = p._try_cast_ability("skill_1")
	assert_true(cast_s1, "TEST 6: Skill 1 cast via PlayerController")
	assert_true(asys.get_cooldown_remaining("skill_1") > 2.5, "TEST 7: Skill 1 triggered its 3.0s cooldown")
	assert_true(dummy.health_component.current_health == dummy_hp_before - s1.damage, "TEST 8: Skill 1 dealt 35 damage to target")

	# 3. Independent Cooldowns: Skill 2, 3 and Ult cooldowns remain 0.0
	assert_true(asys.get_cooldown_remaining("skill_2") == 0.0, "TEST 9: Skill 2 unaffected by Skill 1 cooldown")
	assert_true(asys.get_cooldown_remaining("skill_3") == 0.0, "TEST 10: Skill 3 unaffected by Skill 1 cooldown")

	# Skill 1 spam rejection during cooldown
	var cast_s1_spam: bool = p._try_cast_ability("skill_1")
	assert_true(not cast_s1_spam, "TEST 11: Skill 1 rejected while on cooldown")

	# 4. Skill 2 Casting (Shield Bash & shield recovery)
	sc.current_stamina = 50.0
	p.shield_durability = 50.0
	dummy_hp_before = dummy.health_component.current_health
	var cast_s2: bool = p._try_cast_ability("skill_2")
	assert_true(cast_s2, "TEST 12: Skill 2 cast successfully")
	assert_true(dummy.health_component.current_health == dummy_hp_before - s2.damage, "TEST 13: Skill 2 dealt 20 damage")
	assert_true(p.shield_durability == 75.0, "TEST 14: Skill 2 restored 25 shield durability")

	# 5. Skill 3 Area Casting (Whirlwind)
	sc.current_stamina = 50.0
	dummy_hp_before = dummy.health_component.current_health
	var cast_s3: bool = p._try_cast_ability("skill_3")
	assert_true(cast_s3, "TEST 15: Skill 3 cast successfully")
	assert_true(dummy.health_component.current_health == dummy_hp_before - s3.damage, "TEST 16: Skill 3 dealt 40 AoE damage")

	# 6. Ultimate Casting (Requires 100 stamina)
	sc.current_stamina = 90.0
	var ult_low_stamina: bool = p._try_cast_ability("ultimate")
	assert_true(not ult_low_stamina, "TEST 17: Ultimate rejected when stamina < 100")

	sc.current_stamina = 100.0
	dummy.health_component.current_health = 100.0
	dummy_hp_before = dummy.health_component.current_health
	var ult_full_stamina: bool = p._try_cast_ability("ultimate")
	assert_true(ult_full_stamina, "TEST 18: Ultimate cast successfully at 100 stamina")
	assert_true(sc.current_stamina == 0.0, "TEST 19: Ultimate consumed all stamina")
	assert_true(dummy.health_component.current_health == dummy_hp_before - ult.damage, "TEST 20: Ultimate dealt 100 damage")

	# 7. Recovery lockouts: Finisher recovery forbids skills
	p._combo_finisher_recovery_timer = 0.5
	sc.current_stamina = 100.0
	asys.reset_cooldowns()
	var cast_during_finisher: bool = p._try_cast_ability("skill_1")
	assert_true(not cast_during_finisher, "TEST 21: Skills strictly forbidden during finisher recovery")
	p._combo_finisher_recovery_timer = 0.0

	# 8. Dead state forbids skills
	p.transition_to(PlayerController.CombatState.DEAD)
	var cast_when_dead: bool = p._try_cast_ability("skill_1")
	assert_true(not cast_when_dead, "TEST 22: Skills strictly forbidden when DEAD")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
