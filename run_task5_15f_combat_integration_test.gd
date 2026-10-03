extends SceneTree

var _failures: int = 0
var _passes: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK 5.15F: COMBAT SYSTEM FULL INTEGRATION TEST")
	print("==================================================")
	call_deferred("_run_all_tests")


func assert_true(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
		print("[PASS] %s" % msg)
	else:
		_failures += 1
		print("[FAIL] %s" % msg)


func _step(count: int = 1) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame


func _wait_ability_finished(player: PlayerController) -> bool:
	for frame: int in range(300):
		if player.active_ability_action == null:
			return true
		await _step()
	assert_true(false, "Ability lifecycle timed out")
	return false


func _run_all_tests() -> void:
	# Headless default viewport is tiny; the real HUD otherwise consumes the click.
	root.size = Vector2i(1152, 720)
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	var arena: Node3D = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var arena_attacker: Node = arena.get_node_or_null("AttackTrainingDummy")
	if arena_attacker:
		arena_attacker.set_physics_process(false)
		arena_attacker.set_process(false)

	var p: PlayerController = arena.find_child("Player", true, false) as PlayerController
	assert_true(p != null, "TEST 1: Player initialized in arena")

	var sc: StaminaComponent = p.stamina_component
	var asys: AbilitySystem = p.ability_system
	var dc: DodgeController = p.dodge_controller
	var hc: HealthComponent = p.health_component
	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	if dummy:
		dummy.global_position = p.global_position + Vector3(0, 0, -1.5)
	await process_frame
	await physics_frame

	# ----------------------------------------------------
	# SECTION 1: 3-HIT COMBO & FINISHER RECOVERY INTEGRATION
	# ----------------------------------------------------
	p.stamina_component.current_stamina = 50.0

	# Execute Hit 1
	p._try_combat_attack()
	assert_true(p.combat_state == PlayerController.CombatState.ATTACK and p._combo_step == 1, "TEST 2: Hit 1 started")

	# Wait past impact to hit 2 window, advance hit 2 manually
	p._attack_impact_applied = true
	p.anim_player.seek(PlayerController.COMBO_WINDOW_START + 0.05, true)
	var hit2_ok: bool = p._try_combat_attack()
	assert_true(hit2_ok and p._combo_step == 2, "TEST 3: Hit 2 manually advanced in combo window")

	# Verify Hit 2 active
	assert_true(p.combat_state == PlayerController.CombatState.ATTACK and p._combo_step == 2, "TEST 4: Hit 2 active")

	# Advance Hit 3 manually
	p._attack_impact_applied = true
	p.anim_player.seek(PlayerController.COMBO_WINDOW_START + 0.05, true)
	var hit3_ok: bool = p._try_combat_attack()
	assert_true(hit3_ok and p._combo_step == 3, "TEST 5: Hit 3 manually advanced in combo window")

	# Verify Hit 3 active
	assert_true(p.combat_state == PlayerController.CombatState.ATTACK and p._combo_step == 3, "TEST 6: Hit 3 active")

	# Complete Hit 3 animation -> enters 0.8s finisher recovery
	p._on_animation_finished("attack")
	assert_true(p._combo_finisher_recovery_timer > 0.0, "TEST 7: Finisher recovery timer active (~0.8s)")

	# Verify strict lockout during finisher recovery
	var attack_locked: bool = p.transition_to(PlayerController.CombatState.ATTACK)
	assert_true(not attack_locked, "TEST 8: Attack locked out during finisher recovery")
	var block_locked: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	assert_true(not block_locked, "TEST 9: Block locked out during finisher recovery")
	var dodge_locked: bool = p.transition_to(PlayerController.CombatState.DODGE)
	assert_true(not dodge_locked, "TEST 10: Dodge locked out during finisher recovery")
	var skill_locked: bool = p._try_cast_ability("skill_1")
	assert_true(not skill_locked, "TEST 11: Skills locked out during finisher recovery")
	var ult_locked: bool = p._try_cast_ability("ultimate")
	assert_true(not ult_locked, "TEST 12: Ultimate locked out during finisher recovery")

	# Clear finisher recovery
	p._combo_finisher_recovery_timer = 0.0

	# ----------------------------------------------------
	# SECTION 2: BLOCK & SHIELD INTEGRATION
	# ----------------------------------------------------
	var block_started: bool = p.transition_to(PlayerController.CombatState.BLOCK)
	assert_true(block_started and p.combat_state == PlayerController.CombatState.BLOCK, "TEST 13: Block entered successfully")

	# Directional block incoming attack
	var attacker_pos: Vector3 = p.global_position + Vector3(0, 0, -2.0)
	var hp_before_block: float = hc.current_health
	var shield_before: float = p.shield_durability
	p.take_damage(20.0, attacker_pos, 15.0)

	# 85% damage reduction: damage taken is 20 * 0.15 = 3.0
	assert_true(hc.current_health == hp_before_block - 3.0, "TEST 14: Block applies 85% damage reduction")
	assert_true(p.shield_durability == shield_before - 15.0, "TEST 15: Shield durability reduced by incoming shield damage")

	# ----------------------------------------------------
	# SECTION 3: DODGE TRANSITIONS & I-FRAME INTEGRATION
	# ----------------------------------------------------
	# Ensure stamina headroom for zero-cost dodge and perfect dodge (+25)
	sc.current_stamina = 50.0
	var stamina_before_dodge: float = sc.current_stamina
	p._try_dodge()
	assert_true(p.combat_state == PlayerController.CombatState.DODGE, "TEST 16: Dodge cancelled BLOCK into DODGE")
	assert_true(sc.current_stamina == stamina_before_dodge, "TEST 17: Dodge does not consume stamina")

	# Advance into dodge i-frame window
	await create_timer(0.08).timeout
	assert_true(p.is_in_dodge_iframe(), "TEST 18: In active dodge i-frame window")

	# Perfect Dodge test: incoming dodgeable attack during i-frame
	var hp_before_pd: float = hc.current_health
	var stamina_before_pd: float = sc.current_stamina
	var payload: AttackPayload = AttackPayload.new(30.0, attacker_pos, 15.0, true, true, 25.0)
	p.take_damage(payload)

	assert_true(hc.current_health == hp_before_pd, "TEST 19: Damage negated by Perfect Dodge i-frame")
	assert_true(sc.current_stamina == stamina_before_pd + 25.0, "TEST 20: Perfect Dodge awarded +25 stamina")
	assert_true(p.is_counter_window_active(), "TEST 21: Counter Window opened by Perfect Dodge")
	assert_true(Engine.time_scale < 1.0, "TEST 22: Combat slow motion triggered")

	# Wait for time dilation to expire
	await create_timer(0.40, true, false, true).timeout
	assert_true(Engine.time_scale == 1.0, "TEST 23: Time scale restored to 1.0")

	# Wait for dodge to complete
	await create_timer(0.20, true, false, true).timeout

	# ----------------------------------------------------
	# SECTION 4: ABILITIES & ULTIMATE INTEGRATION
	# ----------------------------------------------------
	sc.current_stamina = 50.0
	asys.reset_cooldowns()

	# Cast Skill 1
	var cast_s1: bool = p._try_cast_ability("skill_1")
	assert_true(cast_s1, "TEST 24: Skill 1 executed")
	assert_true(asys.get_cooldown_remaining("skill_1") > 0.0, "TEST 25: Skill 1 cooldown running")
	assert_true(asys.get_cooldown_remaining("skill_2") == 0.0, "TEST 26: Skill 2 cooldown independent (0.0)")

	# Another ability cannot interrupt Z, even at full stamina.
	sc.current_stamina = 100.0
	assert_true(not p._try_cast_ability("ultimate") and sc.current_stamina == 100.0, "Active Z rejects V without spending")
	if not await _wait_ability_finished(p):
		quit(1)
		return
	assert_true(p.active_ability_action == null and not p.is_shield_enlarged, "Z recovery naturally releases action and giant shield")

	# Ultimate test at full stamina
	sc.current_stamina = 100.0
	var cast_ult: bool = p._try_cast_ability("ultimate")
	assert_true(cast_ult, "TEST 27: Ultimate executed at 100 stamina")
	assert_true(sc.current_stamina == 0.0, "TEST 28: Ultimate consumed 100 stamina")

	assert_true(p.giant_sword_ultimate.aiming, "V enters ground targeting after Z completes")
	await _step(35)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = p.giant_sword_ultimate.cinematic_camera.unproject_position(p.global_position)
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await _step()
	click.pressed = false
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	assert_true(not p.giant_sword_ultimate.aiming and not p.is_attacking and p._combo_step == 0, "LMB confirms V without starting a basic attack")
	if not await _wait_ability_finished(p):
		quit(1)
		return
	assert_true(p.camera.current and not p.combat.giant_sword_vfx.visible and p._is_mouse_captured, "V naturally restores gameplay camera, cursor and input")

	# ----------------------------------------------------
	# SECTION 5: PERSPECTIVE TOGGLE (FPS / TPS)
	# ----------------------------------------------------
	assert_true(p.is_third_person, "TEST 29: Starts in Third-Person mode")
	p.toggle_camera_perspective()
	assert_true(not p.is_third_person, "TEST 30: Toggled to First-Person mode (B key)")
	assert_true(p.spring_arm.spring_length == 0.0, "TEST 31: FPS spring length is 0.0")

	# Combat action in FPS mode
	sc.current_stamina = 50.0
	asys.reset_cooldowns()
	var fps_attack_start: bool = p.transition_to(PlayerController.CombatState.ATTACK)
	assert_true(fps_attack_start, "TEST 32: Attack works in FPS mode")
	p.reset_combo()

	# Toggle back to TPS
	p.toggle_camera_perspective()
	assert_true(p.is_third_person, "TEST 33: Toggled back to TPS mode")

	# ----------------------------------------------------
	# SECTION 6: DEATH & RESPAWN INTEGRATION
	# ----------------------------------------------------
	CombatTimeManager.apply_slow_motion(0.5, 5.0)
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(p.combat_state == PlayerController.CombatState.DEAD, "TEST 34: Entered DEAD state")
	assert_true(Engine.time_scale == 1.0, "TEST 35: Time scale safely reset on death")
	assert_true(sc.current_stamina == 0.0, "TEST 36: Stamina reset on death")

	# Actions rejected while dead
	assert_true(not p.transition_to(PlayerController.CombatState.ATTACK), "TEST 37: Attack rejected while dead")
	assert_true(not p.transition_to(PlayerController.CombatState.BLOCK), "TEST 38: Block rejected while dead")
	assert_true(not p.transition_to(PlayerController.CombatState.DODGE), "TEST 39: Dodge rejected while dead")
	assert_true(not p._try_cast_ability("skill_1"), "TEST 40: Skills rejected while dead")

	# Respawn
	p.respawn()
	assert_true(p.combat_state == PlayerController.CombatState.IDLE, "TEST 41: State returned to IDLE on respawn")
	assert_true(hc.current_health == hc.max_health, "TEST 42: Health restored on respawn")
	assert_true(p.shield_durability == p.shield_max_durability, "TEST 43: Shield restored on respawn")
	assert_true(sc.current_stamina == 0.0, "TEST 44: Stamina clean on respawn")

	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)
