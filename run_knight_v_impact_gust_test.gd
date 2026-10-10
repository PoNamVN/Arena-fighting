extends SceneTree
var failed: int = 0
var passed: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("[PASS] ", label)
	else: failed += 1; push_error("[FAIL] " + label)
func run() -> void:
	var arena := Node3D.new(); root.add_child(arena)
	var p: PlayerController = load("res://scenes/Player.tscn").instantiate()
	p.external_controlled = true; arena.add_child(p)
	for i in 10:
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw
	var manager: Node = root.get_node("VFXManager")
	while not manager.warmup_complete: await process_frame
	var v: GiantSwordVFX = p.combat.giant_sword_vfx
	var u: GiantSwordUltimate = p.giant_sword_ultimate
	v.begin(Vector3.ZERO, 4.5)
	v.update_startup(.56, 1.4)
	var incoming: float = Vector2(v._impact_smoke[0].position.x, v._impact_smoke[0].position.z).length()
	v.update_startup(.07, 1.4)
	check(v._impact_smoke[0].visible and Vector2(v._impact_smoke[0].position.x, v._impact_smoke[0].position.z).length() < incoming, "Pre-impact dust is drawn toward the sword")
	check(v._sand_transforms[0].origin.y > .1, "Loose grit lifts before the impact")
	v.stop()
	check(not v._impact_smoke[0].visible and v._sand_batch.visible_instance_count == 0, "Cancelling anticipation clears airborne dust and grit")
	v.begin(Vector3(0, 3, 0), 4.5); v.impact()
	check(is_equal_approx(v.sword.position.y, -2.4), "Blade bites 2.4m below selected surface")
	v.update_impact(.33)
	check(is_equal_approx(v.sword.position.y, -5.8), "Blade settles 5.8m below elevated surface")
	for quality in 3:
		v._quality_changed(quality); v._update_impact_smoke(.5)
		var count: int = 0
		for puff in v._impact_smoke:
			if puff.visible: count += 1
		check(count == [48, 96, 144][quality], "Quality %d scales rolling dust coverage" % quality)
	check(u._hud.get_node_or_null("ImpactLensGust") == null, "HUD contains no fullscreen dust overlay")
	v._update_floor_wave(.04)
	check(is_zero_approx(v._floor_lifts[0]), "Floor stays still during first impact beat")
	v._update_floor_wave(.4)
	check(v._floor_lifts[0] > .3 and is_zero_approx(v._floor_lifts[160]), "Floor uplift travels outward before reaching far slabs")
	v._update_floor_wave(.9)
	check(is_zero_approx(v._floor_lifts[0]) and v._floor_lifts[160] > .1, "Near slabs settle while outer floor is still lifting")
	v._floor_planes = PackedVector4Array([Vector4(1, 0, 0, 1.0)])
	v._update_floor_wave(.4)
	check(is_zero_approx(v._floor_lifts[0]), "Uplift slabs are clipped by the arena perimeter")
	v._floor_planes = PackedVector4Array()
	v._update_impact_smoke(4.4)
	check(not v._impact_smoke[0].visible, "World dust clears before camera handoff")
	v.begin(Vector3.ZERO, 4.5); v.impact(); v.update_impact(.7)
	check(is_equal_approx(float(v._pressure_materials[0].get_shader_parameter("radius")), v.shockwave.scale.x), "Pressure shell and ground wave share one travel radius")
	check(absf(Vector2(v._impact_smoke[0].position.x, v._impact_smoke[0].position.z).length() - v.shockwave.scale.x) < .01, "Leading dust is carried by the visible pressure wave")
	check(v._sand_batch.visible_instance_count > 0 and v._sand_transforms[0].origin.length() > 3, "Sand is thrown radially from impact")
	v._update_sand(.16)
	check(v._sand_transforms[15].basis.x.length() < .001 and v._sand_transforms[0].basis.x.length() > .01, "Wind picks up near floor sand before distant floor sand")
	v.update_recovery(4.1, 4.8)
	check(is_zero_approx(float(v._sword_materials[0].get_shader_parameter("dissolve"))), "Sword stays embedded while wind and dust travel outward")
	v._impact_elapsed = 3.2
	v.update_recovery(1.6, 4.8)
	check(is_zero_approx(float(v._sword_materials[0].get_shader_parameter("dissolve"))), "Sword silhouette survives the dense dust hold")
	var nodes: int = v.get_child_count()
	for i in 30: v.begin(Vector3.ZERO, 4.5); v.impact(); v.update_impact(.5); v.stop()
	var clean: bool = true
	for puff in v._impact_smoke: clean = clean and not puff.visible
	check(clean and v.get_child_count() == nodes, "Repeated casts reuse and clear all dust nodes")
	p.stamina_component.current_stamina = 100; p._try_cast_ability("ultimate")
	u.target_position = Vector3.ZERO; u.target_valid = true; u._confirm_target()
	v.impact(); v.update_impact(1.0)
	check(is_equal_approx(p.active_ability_action.data.recovery_duration, 4.8) and u.cinematic_timeout_seconds() > 8.0, "Longer aftermath has sufficient cinematic watchdog time")
	p.active_ability_action.cancel()
	check(not paused and not u._hud.visible, "Cancel during dust coverage restores world and clears cinematic HUD")
	check(v._floor_batch.visible_instance_count == 0 and v._sand_batch.visible_instance_count == 0 and not v._pressure_waves[0].visible, "Cancellation clears pressure shells and sand")
	p.stamina_component.current_stamina = 100; p._try_cast_ability("ultimate")
	u.target_position = Vector3.ZERO; u.target_valid = true; u._confirm_target()
	for i in 360: await physics_frame; await process_frame
	check(paused and p.active_ability_action != null and v._impact_elapsed > 2.5, "Extended cutscene holds impact shot through settling dust")
	for i in 150: await physics_frame; await process_frame
	check(not paused and p.active_ability_action == null and not v.visible, "Natural completion clears dust and restores gameplay after extended aftermath")
	# Let audio/render threads consume rapid stop requests before teardown.
	await create_timer(.2).timeout
	arena.queue_free()
	await create_timer(.2).timeout
	print("RESULTS: %d/%d PASSED" % [passed, passed + failed]); quit(1 if failed else 0)
