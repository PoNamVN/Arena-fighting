extends SceneTree
var passed: int = 0
var failed: int = 0
func _initialize() -> void:
	AudioServer.set_bus_mute(0, true)
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok: passed += 1; print("[PASS] ", label)
	else: failed += 1; push_error("[FAIL] " + label)
func step(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func cast(p: PlayerController, point: Vector3) -> void:
	p.stamina_component.current_stamina = 100
	p._try_cast_ability("ultimate")
	p.giant_sword_ultimate.target_position = point
	p.giant_sword_ultimate.target_valid = true
	p.giant_sword_ultimate._confirm_target()
func wait_impact(p: PlayerController) -> void:
	for i in 240:
		if p.active_ability_action and p.active_ability_action.custom_data.get("radial_feedback", false): return
		await step(1)
	check(false, "Ultimate reaches impact")
func wait_coronation(p: PlayerController, time: float) -> void:
	for i in 1200:
		if p.giant_sword_ultimate._coronation_active and p.giant_sword_ultimate._coronation.elapsed >= time: return
		if not p.active_ability_action: break
		await step(1)
	check(false, "Finisher reaches timeline %.2f" % time)
func run() -> void:
	var arena: Node3D = load("res://scenes/EmptyArena.tscn").instantiate(); root.add_child(arena)
	var p: PlayerController = load("res://scenes/Player.tscn").instantiate(); p.external_controlled = true; arena.add_child(p); p.position = Vector3(0, .1, 8)
	var target: TrainingDummy = load("res://scenes/TrainingDummy.tscn").instantiate(); target.auto_reset_on_death = false; arena.add_child(target); target.position = Vector3(0, .1, 0)
	await step(10)
	var manager: Node = root.get_node("VFXManager")
	while not manager.warmup_complete: await process_frame
	p.camera.make_current()
	var u: GiantSwordUltimate = p.giant_sword_ultimate
	check(u._coronation.rock.get_child_count() > 0 and u._coronation.birds.size() == 9, "Blender rock and dove assets load in Godot")
	var cue: AudioStreamWAV = u._coronation.sound.stream as AudioStreamWAV
	check(cue != null and cue.stereo and cue.mix_rate == 44100 and cue.get_length() < u._coronation.DURATION - u._coronation.REVELATION, "Stereo celestial cue loads and its full tail fits inside the cutscene")
	cast(p, Vector3.ZERO); await wait_impact(p)
	check(target.current_hp > 0 and not u._coronation_active, "Nonlethal Ultimate keeps only its original cutscene")
	var ability: AbilityData = p.active_ability_action.data
	p.active_ability_action.cancel(); await step(2)
	target.health_component.reset_health(); target.current_hp = 50
	target.health_component.ability_invulnerable = true
	cast(p, Vector3.ZERO); await wait_impact(p)
	check(target.current_hp == 50 and not u._coronation_active, "Invulnerability cannot falsely trigger the finisher")
	p.active_ability_action.cancel(); await step(2)
	target.health_component.ability_invulnerable = false
	target.current_hp = ability.damage + 1
	check(not p.combat.radial_ability_can_finish(ability, Vector3.ZERO), "HP above Ultimate damage uses the normal cast")
	target.current_hp = ability.damage
	check(p.combat.radial_ability_can_finish(ability, Vector3.ZERO), "HP equal to Ultimate damage qualifies for the finisher")
	check(not p.combat.radial_ability_can_finish(ability, Vector3(20, 0, 0)), "Low HP outside the selected impact area cannot trigger a finisher")
	target.is_blocking = true; target.rotation.y = PI
	check(not p.combat.radial_ability_can_finish(ability, Vector3(0, 0, 1)), "Block damage reduction is included in the lethal threshold")
	target.is_blocking = false
	cast(p, Vector3.ZERO)
	check(paused and u._coronation_active and u._coronation.visible and u._cloud_reveal_remaining == 0 and not p.combat.giant_sword_vfx.sword.visible, "Lethal-range cast immediately starts the rock cutscene and skips normal V")
	check(not target.is_dead() and target.current_hp == ability.damage, "Choosing the finisher does not apply damage before sword contact")
	check(u.finish_presentation_timeout_seconds() > u._coronation.DURATION and u.cinematic_timeout_seconds() > u._coronation.DURATION, "World and round-end watchdogs cover the direct finisher")
	var action: AbilityAction = p.active_ability_action
	await wait_coronation(p, 1.6)
	check(u._coronation._rock_hit and not u._coronation._sword_hit, "Rock lands before the sword arrives")
	check(not u._coronation.garden.visible and u._coronation.garden.growth == 0, "Vegetation waits for the sword impact")
	check(not target.is_dead(), "Rock landing alone does not dispatch Ultimate damage")
	await wait_coronation(p, 4.0)
	check(target.is_dead() and action.custom_data.get("ultimate_kill_confirmed", false) and action.hit_targets.size() == 1, "Finisher sword contact dispatches the original lethal damage once")
	p.combat.execute_radial_ability_impact(action.data, action)
	check(action.hit_targets.size() == 1, "Repeated impact dispatch never damages the victim twice")
	check(u._coronation._sword_hit and p.combat.giant_sword_vfx.sword.visible, "Original sword strikes and remains embedded in the stone")
	var highest_dust: float = 0
	for puff in p.combat.giant_sword_vfx._impact_smoke:
		highest_dust = maxf(highest_dust, puff.position.y + puff.scale.y * 2.5)
	check(highest_dust < 4.0, "Sword-impact dust stays around the foot of the rock")
	check(u._coronation.garden.visible and u._coronation.garden.surface_samples.size() > 0 and u._coronation.garden.growth > 0, "Sword impact starts vegetation on the actual rock surface")
	await wait_coronation(p, 6.3)
	check(u._coronation._revealed and u._coronation.sunlight.light_energy > 0 and u._coronation.sound.playing, "Celestial light and the new aura cue reveal the sword together")
	check(u._coronation.garden.growth > .5 and u._coronation._stone_materials[0].get_shader_parameter("growth") > .5, "Grass, flowers and moss spread together during the revelation")
	var flying: int = 0
	var facing_flight: bool = true
	for bird in u._coronation.birds:
		if bird.visible:
			flying += 1
			var beak: Node3D = bird.find_child("DoveBeak", true, false)
			var body: Node3D = bird.find_child("DoveBody", true, false)
			facing_flight = facing_flight and (beak.global_position - body.global_position).normalized().dot(Vector3.RIGHT) > .85
	check(flying > 0, "Doves cross the revelation shot")
	check(flying > 0 and facing_flight, "Dove beaks face their forward flight direction")
	check(target.current_hp == 0, "Revelation adds no extra gameplay damage")
	for i in 900:
		if p.active_ability_action == null: break
		await step(1)
	check(not paused and p.active_ability_action == null and not u._coronation.visible and p.camera.current, "Natural finish restores gameplay camera and world")
	check(u._coronation.sunlight.light_energy == 0 and not u._coronation.sound.playing, "Finish clears presentation lights and audio")
	check(not u._coronation.garden.visible and u._coronation.garden.batches[0].visible_instance_count == 0 and u._coronation._stone_materials[0].get_shader_parameter("growth") == 0, "Finish clears vegetation and resets moss for the next cast")
	target.health_component.reset_health(); target.current_hp = 50
	cast(p, Vector3.ZERO); await wait_coronation(p, .2)
	p.active_ability_action.cancel()
	check(not paused and not u._coronation.visible and not p.combat.giant_sword_vfx.visible, "Cancellation during second cutscene clears all effects")
	target.health_component.reset_health(); target.current_hp = 50
	cast(p, Vector3.ZERO); await wait_coronation(p, .2)
	p.health_component.take_damage(1000)
	await step(2)
	check(not paused and not u._coronation.visible and not target.is_dead(), "Caster death cancels the direct finisher before damage safely")
	await create_timer(.3).timeout
	arena.queue_free(); await create_timer(.3).timeout
	print("RESULTS: %d/%d PASSED" % [passed, passed + failed]); quit(1 if failed else 0)
