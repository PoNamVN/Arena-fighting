extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("[PASS] ", label)
	else: failed += 1; push_error("[FAIL] " + label)
func step() -> void:
	await physics_frame; await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	var arena: PracticeArena = load("res://scenes/PracticeArena.tscn").instantiate()
	root.add_child(arena)
	var manager: Node = root.get_node("VFXManager")
	while not manager.warmup_complete: await process_frame
	for i in 10: await step()
	arena._begin_fight(); arena.brain.enabled = false
	var p: PlayerController = arena.player
	arena.opponent.position = Vector3(0, .1, -5)
	arena.opponent.health_component.current_health = 50
	p.stamina_component.current_stamina = 100
	await step()
	p._try_cast_ability("ultimate")
	var u: GiantSwordUltimate = p.giant_sword_ultimate
	u.target_position = Vector3(0, 0, -5); u.target_valid = true; u._confirm_target()
	check(u._coronation_active and arena._victory_frame == null, "Direct finisher begins without a stale victory image")
	var finishes: Array[int] = [0]
	p.active_ability_action.action_finished.connect(func(): finishes[0] += 1)
	var deadline: int = Time.get_ticks_msec() + 15000
	var orbit_start := Vector3.ZERO
	var settled := Transform3D.IDENTITY
	var stayed_on_tableau: bool = true
	var no_column_obstruction: bool = true
	while arena._victory_frame == null and Time.get_ticks_msec() < deadline:
		await step()
		for visual in u._column_visual_layers:
			no_column_obstruction = no_column_obstruction and (visual.layers & u.cinematic_camera.cull_mask) == 0
		if u._coronation.elapsed >= 6.0 and orbit_start == Vector3.ZERO: orbit_start = u.cinematic_camera.global_position - u.target_position
		if u._coronation.elapsed >= 8.81 and settled == Transform3D.IDENTITY: settled = u.cinematic_camera.global_transform
		if u._coronation.elapsed >= 8.55:
			var focus: Vector3 = (u.target_position + Vector3.UP * 14.0 - u.cinematic_camera.global_position).normalized()
			stayed_on_tableau = stayed_on_tableau and u.cinematic_camera.current and (-u.cinematic_camera.global_basis.z).dot(focus) > .999
	var orbit_end: Vector3 = u.cinematic_camera.global_position - u.target_position
	check(absf(Vector2(orbit_start.x, orbit_start.z).angle_to(Vector2(orbit_end.x, orbit_end.z))) > .4, "Camera makes a visible slow orbit around the stone before Victory")
	check(settled != Transform3D.IDENTITY and settled.origin.distance_to(u.cinematic_camera.global_position) < .01, "Camera eases to a stop before the result frame is captured")
	check(stayed_on_tableau, "Every final transition frame keeps looking at the sword rather than the player")
	check(no_column_obstruction, "Columns stay excluded throughout the orbit and captured victory composition")
	check(arena._victory_frame != null, "Actual final cinematic frame is captured from the GPU")
	check(arena.round_state == PracticeArena.RoundState.ENDING and arena.result_buttons.is_visible_in_tree() and arena.center_label.is_visible_in_tree() and paused and u.cinematic_camera.current, "Victory appears inside the stopped cutscene before its lease is released")
	check(u._coronation.elapsed > 8.0 and u._coronation._revealed and u._coronation.garden.growth > .95 and u._coronation.sunlight.light_energy > 2.0, "Captured tableau retains the revealed sword, garden and celestial light")
	if arena._victory_frame:
		check(arena._victory_frame.get_width() == 1280 and arena._victory_frame.get_height() == 720, "Victory image uses the current viewport resolution")
	var stored: Texture2D = arena._victory_frame
	while arena.round_state != PracticeArena.RoundState.FINISHED and Time.get_ticks_msec() < deadline: await step()
	check(finishes[0] == 1 and not paused and u.cinematic_camera.current and not p.camera.current, "Action completes without switching to the player camera on Victory")
	check(arena.result_buttons.visible and arena.center_label.text == "BẠN THẮNG!" and arena._victory_background.visible, "Victory title and buttons appear over the final cutscene image")
	check(arena._victory_background.texture == stored and not u._coronation.visible, "Static result frame survives cleanup of live cinematic effects")
	var hud_hidden: bool = true
	for control in arena._combat_hud: hud_hidden = hud_hidden and not control.visible
	check(hud_hidden and arena._victory_background.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Combat HUD is hidden and background does not intercept result buttons")
	for i in 30: await step()
	check(arena._victory_background.texture == stored and arena.result_buttons.visible, "Victory background stays fixed while result controls remain available")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/knight_victory_screen.png")
	arena._prepare_scene_exit()
	check(arena._victory_frame == null and arena._victory_background.texture == null and not arena._victory_background.visible and not paused, "Replay/navigation cleanup releases the screenshot and world pause")
	check(not u._victory_camera_held and p.camera.current, "Replay/navigation releases the held cinematic camera")
	print("RESULTS: %d/%d PASSED" % [passed, passed + failed])
	quit(1 if failed else 0)
