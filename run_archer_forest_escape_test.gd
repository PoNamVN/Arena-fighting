extends "res://run_archer_volley_test.gd"

var showcase: Camera3D
func snapshot(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args(): return
	showcase.global_position = player.global_position + Vector3(3, 2, 4)
	showcase.look_at(player.global_position + Vector3.UP * .8)
	showcase.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/HP VICTUS/.codex/worktrees/71f7/Game_3D/scratch/forest_c_" + label + ".png")

func _run() -> void:
	arena = load("res://scenes/EmptyArena.tscn").instantiate() as Node3D
	root.add_child(arena)
	root.size = Vector2i(1152, 720)
	showcase = Camera3D.new()
	arena.add_child(showcase)
	var bow := await fresh_volley()
	check(bow.start_escape(), "C starts")
	check(is_equal_approx(bow.stealth_remaining, 10) and bow.is_hidden(), "Stealth lasts the full C cooldown")
	check(player.anim_player.current_animation == "forest_roll", "C opens with a dedicated roll animation")
	await frames(15)
	check(player.anim_player.current_animation == "forest_roll" and player.anim_player.current_animation_position > .1, "Roll animation advances through its full-turn keys")
	var hips := player._skeleton.find_bone("hips")
	check(absf(player._skeleton.get_bone_pose_rotation(hips).w) < .6, "Mid-roll actually rotates the torso upside down")
	await snapshot("roll")
	await frames(25)
	check(not bow.dash_active and player.anim_player.current_animation == "forest_sneak_idle", "Roll settles into crouched idle")
	player.external_controlled = true
	player.external_move_direction = Vector3.RIGHT
	var before: int = bow.forest_escape.steps_spawned
	await frames(60)
	check(player.anim_player.current_animation == "forest_sneak_walk", "Movement plays a crouched sneak loop")
	check(bow.forest_escape.steps_spawned > before + 2, "Footsteps grow repeated grass clusters")
	await snapshot("sneak_grass")
	player.external_move_direction = Vector3.ZERO
	await frames(20)
	check(bow.start_charge() and bow.is_hidden(), "Holding LMB preserves stealth and uses the shared aim mode")
	await frames(75)
	player.camera.look_at(player.camera.global_position + Vector3(3, 10, 0))
	bow.release_arrow()
	await frames(90)
	check(bow.is_hidden() and bow.hits_landed == 0 and not player.is_targetable(), "Releasing and missing does not reveal the hunter")
	check(bow.start_charge(), "Charge again while hidden")
	await frames(75)
	player.camera.look_at(enemy.global_position + Vector3.UP * .9)
	bow.release_arrow()
	await frames(45)
	check(bow.hits_landed == 1 and not bow.is_hidden() and player.is_targetable(), "A real bow hit ends stealth")
	bow = await fresh_volley()
	bow.start_escape()
	await frames(45)
	player.take_damage(5)
	check(bow.is_hidden(), "Incoming damage does not end stealth early")
	player.apply_hit_reaction(Vector3.FORWARD)
	check(bow.is_hidden(), "Melee hit reactions preserve stealth too")
	await frames(90)
	check(bow.is_hidden(), "Stealth persists across hit stun")
	await frames(500)
	check(not bow.is_hidden() and not player.ability_system.is_on_cooldown("skill_3"), "Without an arrow hit stealth ends at cooldown expiry")
	check(not player.anim_player.current_animation.begins_with("forest_"), "Normal locomotion returns after stealth")
	arena.queue_free()
	await frames(3)
	print("RESULTS: %d/%d PASSED" % [passed, total])
	quit(0 if passed == total else 1)
