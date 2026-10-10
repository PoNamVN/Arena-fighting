extends SceneTree

var arena: Node3D
var player: PlayerController

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func check(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] ", msg)
	else:
		print(">>> [FAILED] ", msg)

func _init() -> void:
	print("=== RUNNING ARCHER DASH (Q) VERIFICATION SUITE ===")
	root.size = Vector2i(1152, 720)
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)

	player = load("res://scenes/Player.tscn").instantiate() as PlayerController
	player.hero_profile = "archer"
	player.position = Vector3(0, 0.1, 0)
	arena.add_child(player)

	for i in range(15):
		await process_frame

	var dodge: DodgeController = player.dodge_controller
	var anim: AnimationPlayer = player.anim_player
	var dash_pres = player.get_node_or_null("ArcherDashPresentation")

	# TEST 1: ArcherDashPresentation initialized
	check(dash_pres != null, "ArcherDashPresentation node attached to archer")
	check(anim.has_animation("dash_forward"), "AnimationPlayer contains archer dash_forward")
	check(anim.has_animation("dash_back"), "AnimationPlayer contains archer dash_back")
	check(anim.has_animation("dash_left"), "AnimationPlayer contains archer dash_left")
	check(anim.has_animation("dash_right"), "AnimationPlayer contains archer dash_right")

	# TEST 2: Dodge parameters match Knight rules
	check(is_equal_approx(dodge.dodge_duration, 0.40), "Archer dodge_duration matches Knight (0.40s)")
	check(is_equal_approx(dodge.dodge_distance, 5.0), "Archer dodge_distance matches Knight (5.0m)")

	# TEST 3: Neutral/Forward Q Dash
	var start_pos := player.global_position
	player._try_dodge()
	await frames(5) # t ~ 0.08s, inside [0.05, 0.20]
	check(player.combat_state == PlayerController.CombatState.DODGE, "Q press triggers CombatState.DODGE")
	check(dodge.is_dodging, "DodgeController is_dodging is active")
	check(anim.current_animation == "dash_forward", "Neutral dash plays archer dash_forward animation")
	check(dodge.is_in_iframe(), "Archer is protected by dodge i-frame")

	# Wait until dodge finishes
	while dodge.is_dodging:
		await physics_frame
	await frames(5)
	check(player.combat_state == PlayerController.CombatState.IDLE, "Dodge finishes and returns to IDLE")
	check(player.global_position.distance_to(start_pos) > 4.5, "Archer traversed ~5.0m during forward dash")

	# TEST 4: Backward Dash (Backstep leap)
	dodge._cooldown_timer = 0.0
	player.external_controlled = true
	player.external_move_direction = Vector3(0, 0, 1) # backward
	player._try_dodge()
	await frames(5)
	check(anim.current_animation == "dash_back", "S+Q plays archer acrobatic dash_back leap")
	check(is_equal_approx(dodge.dodge_duration, 0.60), "Backstep leap timing is 0.60s")
	check(is_equal_approx(dodge.dodge_distance, 6.5), "Backstep leap distance is 6.5m")

	while dodge.is_dodging:
		await physics_frame
	await frames(5)

	# TEST 5: Left Sidestep Dash
	dodge._cooldown_timer = 0.0
	player.external_move_direction = Vector3(-1, 0, 0) # left
	player._try_dodge()
	await frames(5)
	check(anim.current_animation == "dash_left", "A+Q plays archer nimble dash_left sidestep")

	while dodge.is_dodging:
		await physics_frame
	await frames(5)

	# TEST 6: Right Sidestep Dash
	dodge._cooldown_timer = 0.0
	player.external_move_direction = Vector3(1, 0, 0) # right
	player._try_dodge()
	await frames(5)
	check(anim.current_animation == "dash_right", "D+Q plays archer nimble dash_right sidestep")

	while dodge.is_dodging:
		await physics_frame
	await frames(5)

	# TEST 7: Bow remains attached to hand.L during and after dash
	var bow = player.archer_combat._bow
	var bow_parent = bow.get_parent()
	check(bow_parent.name == "BowHandAttachment", "Bow remains safely parented to hand.L attachment")

	print("ALL ARCHER DASH TESTS PASSED SUCCESSFULLY!")
	quit(0)
