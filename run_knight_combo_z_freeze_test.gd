extends SceneTree

var passed := 0
var total := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	total += 1
	if ok: passed += 1
	print(("PASS " if ok else "FAIL ") + label)
func frames(count: int) -> void:
	for tick in range(count): await physics_frame
func run() -> void:
	var arena := load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	for hits in [1, 2, 3]:
		var player := load("res://scenes/Player.tscn").instantiate() as PlayerController
		player.external_controlled = true
		player.position = Vector3(0, .1, 0)
		arena.add_child(player)
		await frames(5)
		check(player._try_combat_attack(), "Start basic combo")
		for step in range(1, hits):
			for tick in range(90):
				await frames(1)
				if player.is_in_combo_window(): break
			check(player._try_combat_attack(), "Advance combo")
		for tick in range(90):
			await frames(1)
			if player._attack_impact_applied and player.anim_player.current_animation_position > PlayerController.ATTACK_IMPACT_TIMESTAMP: break
		check(player._combo_step == hits, "Reached requested hit %d" % hits)
		check(player._try_cast_ability("skill_1"), "Z casts after combo hit %d impact" % hits)
		await frames(150)
		check(player.active_ability_action == null, "Z finishes")
		check(player.combat_state != PlayerController.CombatState.ATTACK, "Z leaves no orphaned ATTACK state")
		player.external_move_direction = Vector3.RIGHT
		var before := player.global_position
		await frames(15)
		check(player.global_position.x > before.x + .2, "Movement resumes after Z")
		check(player._try_combat_attack(), "Basic attack resumes after Z")
		player.queue_free()
		await frames(3)
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
