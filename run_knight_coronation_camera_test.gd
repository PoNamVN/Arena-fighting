extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void:
	AudioServer.set_bus_mute(0, true); call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("[PASS] ", label)
	else: failed += 1; push_error("[FAIL] " + label)
func run() -> void:
	var arena: Node3D = load("res://scenes/EmptyArena.tscn").instantiate(); root.add_child(arena)
	var p: PlayerController = load("res://scenes/Player.tscn").instantiate(); p.external_controlled = true; arena.add_child(p)
	for i in 10: await physics_frame; await process_frame
	p.set_physics_process(false)
	var u: GiantSwordUltimate = p.giant_sword_ultimate
	for target in [Vector3.ZERO, Vector3(0,0,-5), Vector3(18,0,0), Vector3(0,0,18), Vector3(-18,0,0), Vector3(12,0,12)]:
		for yaw in [0.0, PI/2, PI]:
			p._camera_yaw = yaw; u.target_position = target; u._select_camera_shot(); u._select_coronation_shot()
			check(u._coronation_path_ready, "Orbit preflight finds a route target=%s yaw=%.2f" % [target,yaw])
			var previous: Vector3 = target + u._shot_back * 22*u._shot_distance_scale + Vector3.UP*u._coronation_shot_height
			var clear: bool = true
			for frame in 181:
				var at: Vector3 = target + u._shot_back.rotated(Vector3.UP,u._coronation_orbit_angle*frame/180.0)*22*u._shot_distance_scale + Vector3.UP*u._coronation_shot_height
				clear = clear and u._point_clear(at,1.0) and u._coronation_view_clear(at) and u._safe_camera_motion(previous,at,1.0).distance_to(at)<.025
				previous = at
			check(clear, "Dense orbit sampling never stalls against walls/columns and keeps the sword visible")
	var original: Dictionary = {}
	for visual: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if u._is_coronation_column(visual): original[visual] = visual.layers
	u._exclude_coronation_columns()
	var excluded: bool = not original.is_empty()
	for visual in original:
		excluded = excluded and (visual.layers & u.cinematic_camera.cull_mask) == 0 and (visual.layers & p.camera.cull_mask) != 0
	check(excluded, "Column meshes are absent from the cinematic camera and remain visible to gameplay")
	u._restore_coronation_columns()
	var restored: bool = true
	for visual in original: restored = restored and visual.layers == original[visual]
	check(restored and u._column_visual_layers.is_empty(), "Stopping restores every column's original render layers")
	print("RESULTS: %d/%d PASSED" % [passed, passed+failed]); quit(1 if failed else 0)
