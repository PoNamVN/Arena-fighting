extends SceneTree

## Phase 5: Ragdoll Hit Reaction Handover Benchmarks & Telemetry
## Measures launch distance, peak height, recovery timing, wall collision, and dual ragdoll physics budget.

const PlayerScene = preload("res://scenes/Player.tscn")
const KnightRagdollScript = preload("res://scripts/KnightRagdoll.gd")

var _pass_count: int = 0
var _fail_count: int = 0
var _benchmark_data: Dictionary = {}

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("RUNNING PHASE 5: RAGDOLL BENCHMARKS & HANDOVER TELEMETRY")
	print("=".repeat(60))
	call_deferred("_run_benchmarks")

func _record(name: String, passed: bool, details: String) -> void:
	if passed:
		_pass_count += 1
		print("  [PASS] %s - %s" % [name, details])
	else:
		_fail_count += 1
		print("  [FAIL] %s - %s" % [name, details])

func _create_arena() -> Node3D:
	var arena_root: Node3D = Node3D.new()
	arena_root.name = "BenchmarkArena"
	root.add_child(arena_root)

	# Floor
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	arena_root.add_child(floor_body)

	# Pillar obstacle at (0, 3, 5)
	var pillar := StaticBody3D.new()
	var pillar_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 6.0
	cyl.radius = 1.0
	pillar_shape.shape = cyl
	pillar.add_child(pillar_shape)
	pillar.position = Vector3(0, 3, 5)
	arena_root.add_child(pillar)

	# Back wall behind pillar at Z = 9
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(20, 6, 1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 3, 9)
	arena_root.add_child(wall)

	return arena_root

func _run_benchmarks() -> void:
	var arena: Node3D = _create_arena()

	var p1: PlayerController = PlayerScene.instantiate()
	p1.name = "Knight_Alpha"
	p1.position = Vector3(0, 0.1, 0)
	arena.add_child(p1)

	var p2: PlayerController = PlayerScene.instantiate()
	p2.name = "Knight_Beta"
	p2.position = Vector3(0, 0.1, 2)
	arena.add_child(p2)

	await process_frame
	await process_frame

	var r1 = p1.ragdoll
	var r2 = p2.ragdoll

	# -------------------------------------------------------------
	# -------------------------------------------------------------
	# BENCHMARK 1: Direct Unblocked Z Launch Trajectory & Timings
	# -------------------------------------------------------------
	p1.global_position = Vector3(0, 0.1, 0)
	p2.global_position = Vector3(0, 0.1, -1.5)
	p2.combat_state = PlayerController.CombatState.IDLE
	p2._impact_stun_timer = 0.0
	p2._knockback_timer = 0.0
	p2.velocity = Vector3.ZERO
	await process_frame

	var start_pos: Vector3 = p2.global_position
	var fwd: Vector3 = (p2.global_position - p1.global_position).normalized()
	fwd.y = 0.0

	var action1: AbilityAction = AbilityAction.new()
	action1.init_action(p1, "skill_1", KnightAbilities.create_shield_charge())
	action1.current_phase = AbilityAction.Phase.ACTIVE
	p1.active_ability_action = action1

	p1._apply_shield_charge_impact(p2, fwd)

	var peak_y: float = 0.0
	var flight_frames: int = 0
	var settled: bool = false
	var settle_frame: int = 0
	var recovered: bool = false
	var recover_frame: int = 0

	for f in range(240): # up to 4 seconds
		await process_frame
		flight_frames += 1
		var cur_pos: Vector3 = r2.call("get_pelvis_global_position")
		if cur_pos.y > peak_y:
			peak_y = cur_pos.y

		var state = r2.call("get_state")
		if state == 2 and not settled: # SETTLING
			settled = true
			settle_frame = flight_frames
		elif state == 0 and settled and not recovered: # back to INACTIVE / recovered
			recovered = true
			recover_frame = flight_frames
			break

	var final_pelvis: Vector3 = r2.call("get_pelvis_global_position")
	var horiz_disp: float = (p2.global_position - start_pos).length()

	_benchmark_data["unblocked_peak_y"] = peak_y
	_benchmark_data["unblocked_horiz_disp"] = horiz_disp
	_benchmark_data["unblocked_settle_time_s"] = settle_frame / 60.0
	_benchmark_data["unblocked_total_recovery_s"] = recover_frame / 60.0

	var b1_pass: bool = recovered and peak_y >= 0.8
	_record("BENCHMARK 1: Unblocked Launch Metrics", b1_pass,
		"Peak Y=%.2fm, Actor Disp=%.2fm, Settle=%.2fs, Full Get-Up=%.2fs" % [
			peak_y, horiz_disp, _benchmark_data["unblocked_settle_time_s"], _benchmark_data["unblocked_total_recovery_s"]
		])

	# Wait CC grace to expire
	for f in range(20):
		await process_frame

	# -------------------------------------------------------------
	# BENCHMARK 2: Cleanly Blocked Hit Recoil & Protection
	# -------------------------------------------------------------
	p2.global_position = Vector3(0, 0.1, -1.5)
	p2.rotation = Vector3.ZERO
	p2._camera_yaw = PI
	p2.visuals.rotation.y = PI
	p2.combat_state = PlayerController.CombatState.IDLE
	p2._impact_stun_timer = 0.0
	p2._knockback_timer = 0.0
	p2.velocity = Vector3.ZERO
	p2.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var action2: AbilityAction = AbilityAction.new()
	action2.init_action(p1, "skill_1", KnightAbilities.create_shield_charge())
	action2.current_phase = AbilityAction.Phase.ACTIVE
	p1.active_ability_action = action2

	var pos_before_block: Vector3 = p2.global_position
	var shield_before: float = p2.shield_durability
	p1._apply_shield_charge_impact(p2, fwd)

	for f in range(15):
		await process_frame

	var block_disp: float = (p2.global_position - pos_before_block).length()
	var shield_after: float = p2.shield_durability
	var block_ragdoll_active: bool = r2.call("is_active")

	_benchmark_data["clean_block_recoil_m"] = block_disp
	_benchmark_data["shield_dmg_absorbed"] = shield_before - shield_after

	var b2_pass: bool = (not block_ragdoll_active) and block_disp <= 0.6 and shield_after < shield_before
	_record("BENCHMARK 2: Cleanly Blocked Hit Recoil", b2_pass,
		"Recoil Disp=%.3fm (<=0.6m), Shield Lost=%.1f pts, Ragdoll Active=%s" % [
			block_disp, shield_before - shield_after, block_ragdoll_active
		])

	p2._release_block()
	await process_frame

	# -------------------------------------------------------------
	# BENCHMARK 3: Shield-Break Transition to Ragdoll
	# -------------------------------------------------------------
	p2.global_position = Vector3(0, 0.1, -1.5)
	p2.rotation = Vector3.ZERO
	p2._camera_yaw = PI
	p2.visuals.rotation.y = PI
	p2.combat_state = PlayerController.CombatState.IDLE
	p2._impact_stun_timer = 0.0
	p2._knockback_timer = 0.0
	p2.velocity = Vector3.ZERO
	p2.shield_durability = 5.0 # Low durability so next hit breaks
	p2.transition_to(PlayerController.CombatState.BLOCK)
	await process_frame

	var action3: AbilityAction = AbilityAction.new()
	action3.init_action(p1, "skill_1", KnightAbilities.create_shield_charge())
	action3.current_phase = AbilityAction.Phase.ACTIVE
	p1.active_ability_action = action3

	p1._apply_shield_charge_impact(p2, fwd)

	for f in range(10):
		await process_frame

	var shield_broken: bool = p2.is_shield_broken
	var break_ragdoll_active: bool = r2.call("is_active")

	_benchmark_data["shield_break_launch"] = break_ragdoll_active
	var b3_pass: bool = shield_broken and break_ragdoll_active
	_record("BENCHMARK 3: Shield-Break Ragdoll Launch", b3_pass,
		"Shield Broken=%s, Launched into Ragdoll=%s" % [shield_broken, break_ragdoll_active])

	# Let p2 settle and recover, or stop cleanly
	if r2.call("is_active"):
		r2.call("stop_ragdoll")
	p2.combat_state = PlayerController.CombatState.IDLE
	p2._impact_stun_timer = 0.0
	p2._knockback_timer = 0.0
	p2.velocity = Vector3.ZERO
	await process_frame

	# -------------------------------------------------------------
	# BENCHMARK 4: Obstacle / Pillar Impact Safety
	# -------------------------------------------------------------
	# Position p2 at (0, 0.1, 2), pillar is at (0, 3, 5), launch toward pillar (Z+)
	p2.global_position = Vector3(0, 0.1, 2)
	p2.velocity = Vector3.ZERO
	await process_frame
	await process_frame

	r2.call("start_ragdoll", Vector3(0, 2.0, 6.0)) # Strong launch right at pillar

	var hit_pillar_frames: int = 0
	var penetrated_pillar: bool = false
	for f in range(100):
		await process_frame
		var pos = r2.call("get_pelvis_global_position")
		# Pillar center is at (0, 5), radius 1.0. Distance to center should stay >= 0.5m
		var dist_to_pillar_center = Vector2(pos.x, pos.z - 5.0).length()
		if dist_to_pillar_center < 0.4: # Penetrated deep inside pillar collision
			penetrated_pillar = true

	var final_obs_pos: Vector3 = r2.call("get_pelvis_global_position")
	var b4_pass: bool = not penetrated_pillar and final_obs_pos.y >= -0.1
	_record("BENCHMARK 4: Obstacle Collision Safety", b4_pass,
		"Penetrated Pillar=%s, Final Pelvis Pos=(%.2f, %.2f, %.2f)" % [
			penetrated_pillar, final_obs_pos.x, final_obs_pos.y, final_obs_pos.z
		])

	r2.call("stop_ragdoll")
	await process_frame

	# -------------------------------------------------------------
	# BENCHMARK 5: Dual Ragdoll Simulation Physics Frame Budget
	# -------------------------------------------------------------
	# Launch both Knights simultaneously: 22 PhysicalBones active
	p1.global_position = Vector3(-3, 0.1, 0)
	p2.global_position = Vector3(3, 0.1, 0)
	await process_frame

	r1.call("start_ragdoll", Vector3(-2, 4.0, 3))
	r2.call("start_ragdoll", Vector3(2, 4.0, 3))

	var active_bones_count: int = 22
	var total_physics_time_usec: float = 0.0
	var sample_frames: int = 60
	var max_physics_step_usec: float = 0.0

	for f in range(sample_frames):
		var t_start = Time.get_ticks_usec()
		await process_frame
		var delta_usec = Time.get_ticks_usec() - t_start
		total_physics_time_usec += delta_usec
		if delta_usec > max_physics_step_usec:
			max_physics_step_usec = delta_usec

	var avg_frame_time_ms: float = (total_physics_time_usec / sample_frames) / 1000.0
	var max_frame_time_ms: float = max_physics_step_usec / 1000.0

	_benchmark_data["dual_ragdoll_bones"] = active_bones_count
	_benchmark_data["dual_ragdoll_avg_ms"] = avg_frame_time_ms
	_benchmark_data["dual_ragdoll_max_ms"] = max_frame_time_ms

	# Frame budget is 16.67ms (60 FPS). Dual ragdoll simulation should comfortably stay well under 10ms.
	var b5_pass: bool = avg_frame_time_ms < 10.0 and r1.call("is_active") and r2.call("is_active")
	_record("BENCHMARK 5: Dual Ragdoll Physics Budget (22 Bones)", b5_pass,
		"Active Bones=%d, Avg Frame Time=%.3fms, Max Peak=%.3fms (Budget: 16.67ms)" % [
			active_bones_count, avg_frame_time_ms, max_frame_time_ms
		])

	# -------------------------------------------------------------
	# BENCHMARK 6: Zero Idle Overhead (Simulator Dormancy)
	# -------------------------------------------------------------
	r1.call("stop_ragdoll")
	r2.call("stop_ragdoll")
	await process_frame
	await process_frame

	var r1_sim: bool = r1.call("is_simulating")
	var r2_sim: bool = r2.call("is_simulating")
	var b6_pass: bool = (not r1_sim) and (not r2_sim)
	_record("BENCHMARK 6: Zero Idle Simulation Overhead", b6_pass,
		"R1 Simulating=%s, R2 Simulating=%s (Both completely dormant when resting)" % [r1_sim, r2_sim])

	print("\n" + "=".repeat(60))
	print("BENCHMARK SUMMARY & HANDOVER DATA:")
	print("  - Launch Peak Y:          %.2f m" % _benchmark_data["unblocked_peak_y"])
	print("  - Launch Horizontal Disp: %.2f m" % _benchmark_data["unblocked_horiz_disp"])
	print("  - Settle Time:            %.2f s" % _benchmark_data["unblocked_settle_time_s"])
	print("  - Full Recovery Time:     %.2f s" % _benchmark_data["unblocked_total_recovery_s"])
	print("  - Block Recoil:           %.3f m" % _benchmark_data["clean_block_recoil_m"])
	print("  - Shield Damage Absorbed: %.1f HP" % _benchmark_data["shield_dmg_absorbed"])
	print("  - Dual Ragdoll Frame Avg: %.3f ms" % _benchmark_data["dual_ragdoll_avg_ms"])
	print("  - Dual Ragdoll Frame Max: %.3f ms" % _benchmark_data["dual_ragdoll_max_ms"])
	print("=".repeat(60))
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_pass_count, _pass_count + _fail_count, _fail_count])
	print("=".repeat(60))

	quit(0 if _fail_count == 0 else 1)
