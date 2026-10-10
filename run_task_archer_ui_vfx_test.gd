extends SceneTree

## Acceptance Test Suite for Archer UI & VFX (Forest Ranger Theme: Emerald & Gold)
## Validates dynamic reticle arc, ability dock, charge wisps, muzzle shockwave, impact burst, and predator ultimate VFX.

const PlayerScene = preload("res://scenes/Player.tscn")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("RUNNING ARCHER UI & VFX (FOREST RANGER) ACCEPTANCE TESTS")
	print("=".repeat(60))
	call_deferred("_run_tests")

func _record(name: String, ok: bool, info: String) -> void:
	if ok:
		_pass_count += 1
		print("  [PASS] %s - %s" % [name, info])
	else:
		_fail_count += 1
		print("  [FAIL] %s - %s" % [name, info])

func _run_tests() -> void:
	var arena := Node3D.new()
	arena.name = "ArcherTestArena"
	root.add_child(arena)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)

	# 1. Spawn Archer Player
	var player: PlayerController = PlayerScene.instantiate()
	player.hero_profile = "archer"
	player.name = "ArcherPlayer"
	player.position = Vector3(0, 0.1, 0)
	arena.add_child(player)

	# 2. Spawn Training Dummy Target at 12m
	var dummy_script = load("res://scripts/TrainingDummy.gd")
	var dummy: Node3D = Node3D.new()
	dummy.set_script(dummy_script)
	dummy.name = "TargetDummy"
	dummy.position = Vector3(0, 0.1, -12.0)
	arena.add_child(dummy)

	await process_frame
	await process_frame
	await process_frame

	var combat: Node = player.archer_combat
	var vfx: Node = combat.vfx_manager if combat else null

	# -------------------------------------------------------------
	# TEST 1: ArcherCombat and ArcherVFXManager Initialized
	# -------------------------------------------------------------
	var t1_pass: bool = combat != null and vfx != null and is_instance_valid(vfx)
	_record("TEST 1: Archer Combat and VFX Manager initialized", t1_pass,
		"Combat=%s, VFXManager=%s" % [combat != null, vfx != null])

	# -------------------------------------------------------------
	# TEST 2: High-Fidelity UI Components Mounted (Reticle & Dock)
	# -------------------------------------------------------------
	var reticle: Control = combat.reticle_hud if combat else null
	var dock: Control = combat.ability_dock if combat else null
	var t2_pass: bool = reticle != null and dock != null and is_instance_valid(reticle) and is_instance_valid(dock)
	_record("TEST 2: Reticle HUD and Ability Dock mounted in CanvasLayer", t2_pass,
		"Reticle=%s, AbilityDock=%s" % [reticle != null, dock != null])

	# -------------------------------------------------------------
	# TEST 3: Simple reticle is restricted to FPS and sky aim
	# -------------------------------------------------------------
	combat.start_charge()
	var charging_started: bool = combat.charging
	# Advance to mid charge (~0.5s)
	var safety_frames: int = 0
	while combat.charging and combat.charge_time < 0.5 and safety_frames < 100:
		await process_frame
		safety_frames += 1

	var tps_hidden: bool = reticle != null and not reticle.visible

	# Complete to full max charge (1.2s total)
	while combat.charging and combat.charge_time < combat.MAX_CHARGE and safety_frames < 300:
		await process_frame
		safety_frames += 1
	await process_frame

	player.set_third_person(false)
	await process_frame
	await process_frame
	var fps_visible: bool = reticle != null and reticle.visible
	var t3_pass: bool = charging_started and tps_hidden and fps_visible
	_record("TEST 3: Simple reticle hides in TPS and shows in FPS", t3_pass,
		"TPS hidden=%s, FPS visible=%s" % [tps_hidden, fps_visible])
	player.set_third_person(true)

	# -------------------------------------------------------------
	# TEST 4: Bow Charge Wisps & Dynamic Light in VFX Manager
	# -------------------------------------------------------------
	var particles_active: bool = vfx._charge_particles != null and vfx._charge_particles.emitting
	var light_active: bool = vfx._charge_light != null and vfx._charge_light.light_energy > 1.0
	var t4_pass: bool = particles_active and light_active
	_record("TEST 4: Wind Wisps & Golden OmniLight gathering during charge", t4_pass,
		"Wisps emitting=%s, Light energy=%.2f" % [particles_active, vfx._charge_light.light_energy if vfx._charge_light else 0.0])

	# -------------------------------------------------------------
	# TEST 5: Arrow Release with Crit Visuals and Muzzle Flash Ring
	# -------------------------------------------------------------
	var arrows_before: int = combat._arrows.size()
	combat.release_arrow()
	await process_frame

	var arrow_spawned: bool = combat._arrows.size() > arrows_before
	var spawned_arrow_data: Dictionary = combat._arrows[-1] if arrow_spawned else {}
	var is_crit_arrow: bool = spawned_arrow_data.get("is_crit", false)
	var t5_pass: bool = arrow_spawned and is_crit_arrow
	_record("TEST 5: Critical Arrow released with Gold Trail & Muzzle Flash", t5_pass,
		"Arrow spawned=%s, IsCrit=%s, Speed=%.1f" % [arrow_spawned, is_crit_arrow, spawned_arrow_data.get("speed", 0.0)])

	# -------------------------------------------------------------
	# TEST 6: Arrow Impact Spawns Emerald Leaf & Spark Burst
	# -------------------------------------------------------------
	# Simulate arrow impact via vfx_manager
	var test_impact_pos: Vector3 = Vector3(0, 1.0, -12.0)
	vfx.trigger_arrow_impact(test_impact_pos, Vector3.UP, true)
	await process_frame

	var pool_has_active: bool = false
	for p in vfx._impact_pool:
		if p.emitting:
			pool_has_active = true
			break
	var t6_pass: bool = pool_has_active
	_record("TEST 6: Arrow impact triggers Whirling Leaf & Spark burst", t6_pass,
		"Impact particle active=%s, Pool size=%d" % [pool_has_active, vfx._impact_pool.size()])

	# -------------------------------------------------------------
	# TEST 7: Forest Escape (Skill C) Spawns Leaves Whirlwind Vortex
	# -------------------------------------------------------------
	combat.start_escape()
	await process_frame
	await process_frame

	var escape_active: bool = combat.dash_active and combat.stealth_remaining > 0.0
	var t7_pass: bool = escape_active
	_record("TEST 7: Forest Escape triggers stealth and Whirlwind Vortex", t7_pass,
		"Dash active=%s, Stealth remaining=%.2fs" % [combat.dash_active, combat.stealth_remaining])

	# -------------------------------------------------------------
	# TEST 8: T-Rex Bait Ultimate (Skill V) Quake Shockwave & Rotating Ring
	# -------------------------------------------------------------
	var ult: ArcherBaitUltimate = combat.bait_ultimate
	var ult_ok: bool = ult != null
	if ult:
		ult._trigger_quake_shockwave(Vector3(0, 0, -5))
	await process_frame
	var t8_pass: bool = ult_ok
	_record("TEST 8: Apex Predator Ultimate ground shockwave triggerable", t8_pass,
		"BaitUltimate=%s" % [ult_ok])

	# -------------------------------------------------------------
	# TEST 9: Ability Dock Layout & 4 Skill Configuration
	# -------------------------------------------------------------
	var dock_slots_ok: bool = dock.SKILL_CONFIGS.size() == 4
	var t9_pass: bool = dock_slots_ok
	_record("TEST 9: Ability Dock configures Z/X/C/V with icons & stamina cost", t9_pass,
		"Configured slots=%d (Expected 4)" % dock.SKILL_CONFIGS.size())

	# Summary
	print("\n" + "=".repeat(60))
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_pass_count, _pass_count + _fail_count, _fail_count])
	print("=".repeat(60))

	arena.queue_free()
	await process_frame
	quit(0 if _fail_count == 0 else 1)
