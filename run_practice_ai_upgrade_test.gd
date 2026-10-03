extends SceneTree
var passed: int = 0
var total: int = 0
var arena: PracticeArena

func _init() -> void:
	call_deferred("run")
func check(ok: bool, text: String) -> void:
	total += 1
	if ok:
		passed += 1
	print("[%s] TEST %d: %s" % ["PASS" if ok else "FAIL", total, text])
func frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame
func fresh(level: int, separation: float = 1.65) -> void:
	if is_instance_valid(arena):
		arena.queue_free()
		await frames(3)
	PracticeArena.selected_difficulty = level
	arena = load("res://scenes/PracticeArena.tscn").instantiate()
	root.add_child(arena)
	arena.set_process(false)
	arena.player.position = Vector3(0, 0.1, 10)
	arena.opponent.position = Vector3(0, 0.1, 10 - separation)
	await frames(5)
	arena._begin_fight()
	arena.brain.enabled = false
	arena.brain.attack_timer = 0
	# Prevent unrelated match-end and hit interruptions in decision fixtures.
	arena.player.health_component.max_health = 1000
	arena.player.health_component.reset_health()
	arena.opponent.health_component.max_health = 1000
	arena.opponent.health_component.reset_health()

func run() -> void:
	root.size = Vector2i(1152, 720)
	for level: int in range(3):
		await fresh(level)
		check(arena.brain.difficulty == level and arena.brain.combo_limit == level + 1, "Difficulty applies to actual spawned AI")
		check(arena.player.combat.attack_damage == 25 and arena.opponent.combat.attack_damage == 25, "Difficulty leaves base attack damage unchanged")
		arena.player.hit_knockback_distance = 0.0 # Keep the target in range for combo-cap coverage.
		arena.brain.enabled = true
		var highest_combo: int = 0
		for i: int in range(150):
			await frames(1)
			highest_combo = maxi(highest_combo, arena.opponent.combo_step)
		check(highest_combo == level + 1, "Real animation/combo window reaches intended combo cap (observed %d)" % highest_combo)
	await fresh(PracticeOpponent.Difficulty.NORMAL)
	var ai: PlayerController = arena.opponent
	var brain: PracticeOpponent = arena.brain
	brain.attack_timer = 10
	brain._threat_count = 1 # Second visible attack chooses dodge instead of block.
	check(arena.player._try_combat_attack(), "Human melee supplies a real visible threat")
	brain.enabled = true
	await frames(6)
	check(brain.dodges_started == 0 and not ai.is_blocking, "No defense before configured reaction delay")
	for i: int in range(30):
		await frames(1)
		if brain.dodges_started > 0:
			break
	check(brain.dodges_started == 1 and ai.combat_state == PlayerController.CombatState.DODGE, "AI reacts with real dodge after delay")
	check(ai.dodge_controller.world_direction.z < -0.9, "AI retreats away from human")
	await frames(35)
	check(brain.dodges_started == 1, "One threat cannot trigger repeated defense spam")
	await fresh(PracticeOpponent.Difficulty.HARD, 5)
	ai = arena.opponent
	ai.external_move_direction = Vector3.BACK
	Input.action_press("move_right")
	check(ai._try_dodge(), "External actor can request dodge")
	check(ai.dodge_controller.world_direction.dot(Vector3.BACK) > 0.99, "Human WASD cannot override AI dodge direction")
	Input.action_release("move_right")
	await frames(35)
	await fresh(PracticeOpponent.Difficulty.NORMAL, 2)
	ai = arena.opponent
	brain = arena.brain
	brain.attack_timer = 10
	brain.skill_timer = 0
	brain.enabled = true
	await frames(10)
	check(brain.skill_warning_remaining == 0 and brain.skills_started == 0, "No free skill with zero energy")
	brain.enabled = false
	ai.stamina_component.add_stamina(30)
	brain.enabled = true
	await frames(2)
	check(brain.skill_warning_remaining > 0 and brain.warning_ring.visible, "C starts an orange area warning")
	var hp_before: float = arena.player.health_component.current_health
	await frames(15)
	check(is_equal_approx(arena.player.health_component.current_health, hp_before) and is_equal_approx(ai.stamina_component.current_stamina, 30), "Warning deals no damage and does not spend energy early")
	await frames(30)
	check(brain.skills_started == 1 and is_equal_approx(ai.stamina_component.current_stamina, 0), "C spends exactly 30 real energy")
	check(is_equal_approx(hp_before - arena.player.health_component.current_health, 30), "AI C damages human by 30 through shared AOE (observed %.1f)" % (hp_before - arena.player.health_component.current_health))
	check(ai.ability_system.is_on_cooldown("skill_3") and not brain.warning_ring.visible, "Real cooldown begins and warning clears")
	await frames(50)
	brain.skill_timer = 0
	ai.stamina_component.add_stamina(100)
	await frames(8)
	check(brain.skills_started == 1 and brain.skill_warning_remaining == 0, "AI cannot bypass C cooldown despite energy")
	await fresh(PracticeOpponent.Difficulty.EASY, 2)
	brain = arena.brain
	brain.attack_timer = 10
	brain.skill_timer = 0
	arena.opponent.stamina_component.add_stamina(100)
	brain.enabled = true
	await frames(45)
	check(brain.skills_started == 0 and brain.skill_warning_remaining == 0, "Easy mode never uses C")
	await fresh(PracticeOpponent.Difficulty.NORMAL, 2)
	brain = arena.brain
	brain.attack_timer = 10
	brain.skill_timer = 0
	arena.opponent.stamina_component.add_stamina(30)
	brain.enabled = true
	await frames(3)
	check(brain.warning_ring.visible, "Cancellation fixture enters warning")
	arena.opponent.break_shield()
	await frames(3)
	check(not brain.warning_ring.visible and brain.skills_started == 0 and is_equal_approx(arena.opponent.stamina_component.current_stamina, 30), "Shield break interrupts warning without spending")
	await frames(140)
	brain.skill_timer = 0
	await frames(3)
	arena._finish_round()
	await frames(3)
	check(not brain.warning_ring.visible and not brain.enabled and not arena.opponent.controls_enabled, "Round completion clears AI warning and decisions")
	arena.queue_free()
	await frames(3)
	PracticeArena.selected_difficulty = PracticeOpponent.Difficulty.NORMAL
	print("RESULTS: %d / %d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
