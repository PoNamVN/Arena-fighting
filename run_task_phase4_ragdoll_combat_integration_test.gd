extends SceneTree

const TestScene: PackedScene = preload("res://test/knight_hit_reaction_test.tscn")
const PlayerScene: PackedScene = preload("res://scenes/Player.tscn")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _attacker: PlayerController = null
var _defender: PlayerController = null


func _init() -> void:
	print("==================================================")
	print("RUNNING PHASE 4: RAGDOLL COMBAT INTEGRATION TESTS")
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

	_arena = TestScene.instantiate() as Node3D
	root.add_child(_arena)

	_attacker = _arena.get_node("Player") as PlayerController
	_attacker.name = "Attacker"
	_attacker.hero_profile = "knight"
	_attacker.global_position = Vector3(0, 0.1, 2)
	_attacker.look_at(Vector3(0, 0.1, -2), Vector3.UP)

	_defender = PlayerScene.instantiate() as PlayerController
	_defender.name = "Defender"
	_defender.hero_profile = "knight"
	_arena.add_child(_defender)
	_defender.global_position = Vector3(0, 0.1, -1.5)
	_defender.look_at(Vector3(0, 0.1, 2), Vector3.UP)


func _run_tests() -> void:
	_setup_scene()
	for i in range(12):
		await process_frame

	var atk: PlayerController = _attacker
	var def: PlayerController = _defender
	var def_ragdoll: Node = def.get("ragdoll")

	# -----------------------------------------------------------------
	# TEST 1: Both combatants initialized with KnightRagdoll
	# -----------------------------------------------------------------
	var atk_ragdoll: Node = atk.get("ragdoll")
	var t1_pass: bool = atk_ragdoll != null and def_ragdoll != null and def_ragdoll.call("get_bone_count") == 11
	_record_result("TEST 1: Both combatants initialized with KnightRagdoll", t1_pass,
		"Attacker ragdoll=%s, Defender ragdoll=%s, Bones=%d" % [atk_ragdoll != null, def_ragdoll != null, def_ragdoll.call("get_bone_count") if def_ragdoll else 0])

	# -----------------------------------------------------------------
	# TEST 2: Unblocked Shield Charge (Z) triggers ragdoll launch
	# -----------------------------------------------------------------
	var def_hp_before: float = def.health_component.current_health
	var fwd: Vector3 = (def.global_position - atk.global_position).normalized()
	fwd.y = 0.0

	# Emulate Shield Charge impact on Defender
	var action: AbilityAction = AbilityAction.new()
	action.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action

	atk._apply_shield_charge_impact(def, fwd)

	for f in range(6):
		await process_frame

	var def_hp_after: float = def.health_component.current_health
	var damage_dealt: float = def_hp_before - def_hp_after
	var ragdoll_launched: bool = def_ragdoll.call("is_active") and (def_ragdoll.get("state") == 1) # LAUNCHED
	var control_impaired: bool = def.is_control_impaired()

	var t2_pass: bool = damage_dealt == 25.0 and ragdoll_launched and control_impaired
	_record_result("TEST 2: Unblocked Shield Charge launches Defender into ragdoll", t2_pass,
		"Damage=%.1f, Ragdoll active=%s, State=%d, Impaired=%s" % [damage_dealt, ragdoll_launched, def_ragdoll.get("state"), control_impaired])

	# -----------------------------------------------------------------
	# TEST 3: Defender lands stably and finishes stand-up recovery
	# -----------------------------------------------------------------
	var wait_frames: int = 0
	while def_ragdoll.call("is_active") and wait_frames < 480:
		await process_frame
		wait_frames += 1

	var recovered: bool = not def_ragdoll.call("is_active")
	var def_state_idle: bool = def.combat_state == PlayerController.CombatState.IDLE
	var t3_pass: bool = recovered and def_state_idle and def.global_position.y >= -0.1
	_record_result("TEST 3: Defender settles, stands up and restores IDLE", t3_pass,
		"Recovered=%s, CombatState=%d (Expected IDLE=0), Ground Y=%.3f, Frames=%d" % [recovered, def.combat_state, def.global_position.y, wait_frames])

	# -----------------------------------------------------------------
	# TEST 4: Post-recovery CC Grace window protects against immediate re-launch
	# -----------------------------------------------------------------
	var cc_grace_active: bool = def_ragdoll.call("is_cc_grace_active")
	var immediate_relaunch: bool = def.trigger_ragdoll(Vector3(0, 3, 3))
	var t4_pass: bool = cc_grace_active and (not immediate_relaunch) and (not def_ragdoll.call("is_active"))
	_record_result("TEST 4: CC Grace window protects Defender from stun-lock re-launch", t4_pass,
		"CC Grace active=%s, Re-launch allowed=%s (Expected false)" % [cc_grace_active, immediate_relaunch])

	# Wait for grace timer to expire
	while def_ragdoll.call("is_cc_grace_active"):
		await process_frame
	await process_frame

	# -----------------------------------------------------------------
	# -----------------------------------------------------------------
	# TEST 5: Cleanly blocked Shield Charge causes block recoil, NO ragdoll
	# -----------------------------------------------------------------
	def.global_position = Vector3(0, 0.1, -1.5)
	def.rotation = Vector3.ZERO
	def._camera_yaw = PI
	def.visuals.rotation.y = PI
	def.combat_state = PlayerController.CombatState.IDLE
	def._impact_stun_timer = 0.0
	def._knockback_timer = 0.0
	def.velocity = Vector3.ZERO
	def.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var action5: AbilityAction = AbilityAction.new()
	action5.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action5.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action5

	var block_hp_before: float = def.health_component.current_health
	var block_shield_before: float = def.shield_durability
	var def_pos_before: Vector3 = def.global_position

	atk._apply_shield_charge_impact(def, fwd)

	for f in range(10):
		await process_frame

	var block_hp_after: float = def.health_component.current_health
	var block_shield_after: float = def.shield_durability
	var block_disp: float = (def.global_position - def_pos_before).length()
	var block_ragdoll: bool = def_ragdoll.call("is_active")
	var block_stunned: bool = def.is_control_impaired()

	# Block absorbs 85% of damage, drains shield, causes small recoil (<= 0.6m), no ragdoll, no stun
	var t5_pass: bool = (not block_ragdoll) and (not block_stunned) and (block_shield_after < block_shield_before) and (block_disp <= 0.6)
	_record_result("TEST 5: Cleanly blocked Z causes recoil without ragdoll or stun", t5_pass,
		"Ragdoll active=%s, Stunned=%s, Shield: %.1f->%.1f, Displacement: %.3fm" % [block_ragdoll, block_stunned, block_shield_before, block_shield_after, block_disp])

	def._release_block()
	await process_frame

	# -----------------------------------------------------------------
	# TEST 6: Shield Break from Shield Charge triggers full ragdoll launch
	# -----------------------------------------------------------------
	def.global_position = Vector3(0, 0.1, -1.5)
	def.rotation = Vector3.ZERO
	def._camera_yaw = PI
	def.visuals.rotation.y = PI
	def.combat_state = PlayerController.CombatState.IDLE
	def._impact_stun_timer = 0.0
	def._knockback_timer = 0.0
	def.velocity = Vector3.ZERO
	def.shield_durability = 5.0 # Low shield so incoming damage breaks shield
	def.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var action6: AbilityAction = AbilityAction.new()
	action6.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action6.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action6

	atk._apply_shield_charge_impact(def, fwd)
	for f in range(6):
		await process_frame

	var shield_broken_ragdoll: bool = def_ragdoll.call("is_active")
	var shield_is_broken: bool = def.is_shield_broken
	var t6_pass: bool = shield_is_broken and shield_broken_ragdoll
	_record_result("TEST 6: Shield break from Z triggers full ragdoll launch", t6_pass,
		"Shield broken=%s, Ragdoll active=%s, State=%d" % [shield_is_broken, shield_broken_ragdoll, def_ragdoll.get("state")])

	# Let defender finish recovering
	wait_frames = 0
	while def_ragdoll.call("is_active") and wait_frames < 480:
		await process_frame
		wait_frames += 1

	# Wait for grace timer to expire
	while def_ragdoll.call("is_cc_grace_active"):
		await process_frame
	await process_frame

	# -----------------------------------------------------------------
	# TEST 7: Fatal hit transitions to DEAD and prevents get-up recovery
	# -----------------------------------------------------------------
	def.health_component.current_health = 10.0 # Will die from 25 damage
	var action7: AbilityAction = AbilityAction.new()
	action7.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action7.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action7

	atk._apply_shield_charge_impact(def, fwd)

	for f in range(15):
		await process_frame

	var is_dead_state: bool = def.combat_state == PlayerController.CombatState.DEAD
	var no_active_ragdoll: bool = not def_ragdoll.call("is_active")
	var is_dead_flag: bool = def.is_dead

	var t7_pass: bool = is_dead_state and is_dead_flag and no_active_ragdoll
	_record_result("TEST 7: Fatal hit firmly enforces DEAD state without get-up recovery", t7_pass,
		"CombatState=DEAD (%s), is_dead=%s, Ragdoll stopped=%s" % [is_dead_state, is_dead_flag, no_active_ragdoll])

	# -----------------------------------------------------------------
	# TEST 8: PracticeArena finishing presentation waits for active ragdoll
	# -----------------------------------------------------------------
	atk.active_ability_action = null
	def.active_ability_action = null
	atk.combat_state = PlayerController.CombatState.IDLE
	def.combat_state = PlayerController.CombatState.IDLE
	def.is_dead = false

	var arena_script = load("res://scripts/PracticeArena.gd")
	var mock_arena = arena_script.new()
	mock_arena.player = atk
	mock_arena.opponent = def
	def_ragdoll.call("start_ragdoll", Vector3(0, 2, 2))

	var busy_with_ragdoll: bool = mock_arena._finishing_presentation_busy()
	def_ragdoll.call("stop_ragdoll")
	var busy_after_stop: bool = mock_arena._finishing_presentation_busy()

	mock_arena.queue_free()

	var t8_pass: bool = busy_with_ragdoll and (not busy_after_stop)
	_record_result("TEST 8: PracticeArena waits for ragdoll presentation before round finish", t8_pass,
		"Busy during ragdoll=%s, Busy after stop=%s" % [busy_with_ragdoll, busy_after_stop])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	var all_passed: bool = true
	var pass_count: int = 0
	for res in _test_results:
		if res["passed"]:
			pass_count += 1
		else:
			all_passed = false

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [pass_count, _test_results.size(), _test_results.size() - pass_count])
	print("==================================================")

	quit(0 if all_passed else 1)
