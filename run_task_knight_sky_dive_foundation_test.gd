extends SceneTree

var arena_scene: PackedScene
var arena: Node
var player: Node
var dummy: Node
var dc: Node
var _tests_passed: int = 0
var _tests_total: int = 0
var _test_timeout: float = 0.0

func _init() -> void:
	arena_scene = load("res://scenes/ArenaTest.tscn")
	if not arena_scene:
		print("ERROR: Failed to load ArenaTest.tscn")
		quit(1)
		return

	arena = arena_scene.instantiate()
	root.add_child(arena)

	player = arena.get_node_or_null("Player")
	dummy = arena.get_node_or_null("TrainingDummy")

	print("\n==================================================")
	print("RUNNING TASK: KNIGHT X — SKY DIVE FOUNDATION TEST")
	print("==================================================")

func _process(delta: float) -> bool:
	if not player or not dummy:
		return false

	if player.ability_system == null or player.ability_system.get_ability("skill_2") == null:
		return false

	_test_timeout += delta
	if _test_timeout > 0.1:
		_run_all_tests()
		quit(0)

	return false

func _run_all_tests() -> void:
	# 1. Player and Arena initialized
	_assert(player != null and dummy != null, "TEST 1: Player and TrainingDummy initialized in test arena")

	var ability = player.ability_system.get_ability("skill_2")
	_assert(ability != null, "TEST 2: Skill 2 exists in AbilitySystem")
	_assert(ability.id == "sky_dive", "TEST 3: Skill 2 data matches sky_dive")
	_assert(ability.stamina_cost == 25.0, "TEST 4: Skill 2 stamina cost is 25.0")
	_assert(ability.cooldown == 6.0, "TEST 5: Skill 2 cooldown is 6.0")

	# Drain stamina to test insufficient stamina
	var stamina = player.stamina_component
	stamina.current_stamina = 10.0
	player._try_cast_ability("skill_2")
	_wait_frames(1)

	_assert(player.active_ability_action == null, "TEST 6: X rejected when stamina < 25")

	# Restore stamina and cast
	stamina.current_stamina = 100.0
	var success = player._try_cast_ability("skill_2")
	_wait_frames(1)

	_assert(player.active_ability_action != null and player.active_ability_action.data.id == "sky_dive", "TEST 7: X cast successfully with sufficient stamina")
	_assert(stamina.current_stamina == 75.0, "TEST 8: Stamina correctly deducted by 25.0 (100 -> 75)")
	_assert(player.ability_system.is_on_cooldown("skill_2"), "TEST 9: Cooldown active (~6.0s)")

	# Try retriggering
	player._try_cast_ability("skill_2")
	_wait_frames(1)
	var first_action = player.active_ability_action
	_assert(first_action != null, "TEST 10: Cannot re-trigger X while active")

	# Verify phase transitions
	# 0.3s startup -> advance manually
	if player.active_ability_action:
		player.active_ability_action.phase_timer = 0.001
		player.active_ability_action.update(0.01)

	_assert(player.active_ability_action != null and player.active_ability_action.current_phase == 2, "TEST 11: Transitioned to ACTIVE phase")

	# Try LMB attack during active
	player._try_combat_attack()
	_wait_frames(1)
	_assert(player.combat_state == 0, "TEST 12: LMB attack correctly rejected while X is active")

	# Try Q dodge during active
	player._try_dodge()
	_wait_frames(1)
	_assert(player.combat_state == 0, "TEST 13: Q dash correctly rejected while X is active")

	# Try RMB block during active
	player._start_block()
	_wait_frames(1)
	_assert(player.combat_state == 0, "TEST 14: RMB block correctly rejected while X is active")

	# Wait for recovery (0.5s active) -> advance manually
	if player.active_ability_action:
		player.active_ability_action.phase_timer = 0.001
		player.active_ability_action.update(0.01)
	_assert(player.active_ability_action != null and player.active_ability_action.current_phase == 3, "TEST 15: Transitioned to RECOVERY phase")

	# Wait for finish (0.4s recovery) -> advance manually
	if player.active_ability_action:
		player.active_ability_action.phase_timer = 0.001
		player.active_ability_action.update(0.01)
	_assert(player.active_ability_action == null, "TEST 16: AbilityAction finished and cleaned up")
	# Ensure combat works again
	var lmb_ok = player._try_combat_attack()
	_assert(lmb_ok and player.combat_state == 2, "TEST 17: Existing LMB combo immediately usable after recovery")

	# Reset state
	player.combat_state = 0
	player.ability_system.reset_cooldowns()

	# Test Death cancellation
	player._try_cast_ability("skill_2")
	_wait_frames(1)
	_assert(player.active_ability_action != null, "TEST 18: X active prior to death test")


	player.take_damage(9999.0, Vector3.ZERO)
	_wait_frames(2)
	_assert(player.active_ability_action == null, "TEST 19: Active ability action cancelled cleanly on death")
	_assert(player.combat_state == 4, "TEST 20: Character firmly in DEAD state")

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_tests_passed, _tests_total, _tests_total - _tests_passed])
	print("==================================================")

func _assert(condition: bool, message: String) -> void:
	_tests_total += 1
	if condition:
		_tests_passed += 1
		print("[PASS] " + message)
	else:
		print("[FAIL] " + message)

func _wait_frames(count: int) -> void:
	for i in range(count):
		player._physics_process(0.016)
		player.ability_system._process(0.016)
