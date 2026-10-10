extends SceneTree

## Acceptance Test for Tuned Ragdoll Mechanics:
## 1. Long-distance floaty Z launch (higher apex, generous flight distance, hang-time).
## 2. Realistic weighted knockdown timing (settle ~1.1s, stand-up ~0.75s).
## 3. Wake-up block (cancelling knockdown on ground into shield block to prevent stun-lock loops).
## 4. AnimationPlayer paused during ragdoll to ensure unhindered physics presentation.

const PlayerScene = preload("res://scenes/Player.tscn")
const KnightAbilities = preload("res://scripts/KnightAbilities.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("RUNNING TUNED KNIGHT RAGDOLL & WAKE-UP BLOCK TESTS")
	print("=".repeat(60))
	call_deferred("_run_tests")

func _record(name: String, ok: bool, info: String) -> void:
	if ok:
		_pass_count += 1
		print("  [PASS] %s - %s" % [name, info])
	else:
		_fail_count += 1
		print("  [FAIL] %s - %s" % [name, info])

func _create_arena() -> Node3D:
	var arena := Node3D.new()
	arena.name = "TuningArena"
	root.add_child(arena)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)
	return arena

func _run_tests() -> void:
	var arena: Node3D = _create_arena()

	var atk: PlayerController = PlayerScene.instantiate()
	atk.name = "Attacker"
	atk.position = Vector3(0, 0.1, 0)
	arena.add_child(atk)

	var def: PlayerController = PlayerScene.instantiate()
	def.name = "Defender"
	def.position = Vector3(0, 0.1, -2.0)
	arena.add_child(def)

	await process_frame
	await process_frame

	var def_ragdoll: Node = def.ragdoll
	var def_anim: AnimationPlayer = def.get_node_or_null("Visuals/CharacterModel/AnimationPlayer")

	# -------------------------------------------------------------
	# TEST 1: Unblocked Shield Charge Launches Far & Floaty
	# -------------------------------------------------------------
	var action: AbilityAction = AbilityAction.new()
	action.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action

	var fwd: Vector3 = Vector3.FORWARD # Towards -Z
	var def_start_pos: Vector3 = def.global_position

	atk._apply_shield_charge_impact(def, fwd)

	var peak_pelvis_y: float = 0.0
	var flight_frames: int = 0
	var anim_paused_during_flight: bool = false

	# Monitor launch & flight phase (State 1 = LAUNCHED)
	while def_ragdoll.call("get_state") == 1 and flight_frames < 120:
		await process_frame
		flight_frames += 1
		var p_pos: Vector3 = def_ragdoll.call("get_pelvis_global_position")
		if p_pos.y > peak_pelvis_y:
			peak_pelvis_y = p_pos.y
		if not def_anim.is_playing():
			anim_paused_during_flight = true

	var flight_time_s: float = flight_frames / 60.0
	var t1_pass: bool = peak_pelvis_y >= 1.0 and flight_time_s >= 0.25 and anim_paused_during_flight
	_record("TEST 1: High floaty launch arc & AnimationPlayer paused", t1_pass,
		"Peak Y=%.2fm (>=1.0m), Flight Time=%.2fs, Anim Paused=%s" % [peak_pelvis_y, flight_time_s, anim_paused_during_flight])

	# -------------------------------------------------------------
	# TEST 2: Weighted knockdown on floor (settle duration ~1.1s)
	# -------------------------------------------------------------
	var settle_frames: int = 0
	while def_ragdoll.call("get_state") == 2 and settle_frames < 200:
		await process_frame
		settle_frames += 1

	var settle_time_s: float = settle_frames / 60.0
	# Settle duration tuned to ~1.1s (>= 0.8s)
	var t2_pass: bool = settle_time_s >= 0.8 and def_ragdoll.call("get_state") == 3 # Progressed to RECOVERING
	_record("TEST 2: Weighted knockdown settle time on floor", t2_pass,
		"Lying on floor duration=%.2fs (>=0.8s, expected ~1.1s), Next state=RECOVERING" % settle_time_s)

	# Let defender finish recovery (State 3 = RECOVERING)
	var recover_frames: int = 0
	while def_ragdoll.call("get_state") == 3 and recover_frames < 160:
		await process_frame
		recover_frames += 1

	var recover_time_s: float = recover_frames / 60.0
	var t2b_pass: bool = recover_time_s >= 0.5 and def.combat_state == PlayerController.CombatState.IDLE
	_record("TEST 2b: Steady stand-up recovery duration", t2b_pass,
		"Stand-up duration=%.2fs (>=0.5s, expected ~0.75s), Final State=IDLE" % recover_time_s)

	# Wait until post-recovery CC grace window has fully expired
	while def_ragdoll.call("is_cc_grace_active"):
		await process_frame
	await process_frame

	# -------------------------------------------------------------
	# TEST 3: Wake-up Block cancels knockdown into shield defense
	# -------------------------------------------------------------
	# Re-launch defender into ragdoll
	def.global_position = Vector3(0, 0.1, -2.0)
	def.velocity = Vector3.ZERO
	await process_frame

	var action2: AbilityAction = AbilityAction.new()
	action2.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action2.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action2

	atk._apply_shield_charge_impact(def, fwd)

	# Wait until defender reaches floor (SETTLING state)
	var wait_to_settle: int = 0
	while def_ragdoll.call("get_state") != 2 and wait_to_settle < 140:
		await process_frame
		wait_to_settle += 1

	var can_block_on_floor: bool = def_ragdoll.call("can_wake_up_block")

	# Defender triggers Wake-up Block!
	var block_started: bool = def._start_block()
	await process_frame

	var state_is_block: bool = def.combat_state == PlayerController.CombatState.BLOCK
	var ragdoll_terminated: bool = not def_ragdoll.call("is_active")
	var impaired_cleared: bool = not def.is_control_impaired()

	var t3_pass: bool = can_block_on_floor and block_started and state_is_block and ragdoll_terminated and impaired_cleared
	_record("TEST 3: Wake-up Block cancels knockdown immediately", t3_pass,
		"Can Block=%s, Block Started=%s, CombatState=BLOCK (%s), Ragdoll Active=%s" % [
			can_block_on_floor, block_started, state_is_block, def_ragdoll.call("is_active")
		])

	# -------------------------------------------------------------
	# TEST 4: Immediate follow-up attack is safely blocked (no stun-lock loop)
	# -------------------------------------------------------------
	# Attacker immediately hits Defender again while Defender is holding wake-up block
	def.rotation = Vector3.ZERO
	def._camera_yaw = PI
	def.visuals.rotation.y = PI
	await process_frame

	var def_hp_before: float = def.health_component.current_health
	var def_shield_before: float = def.shield_durability

	var action3: AbilityAction = AbilityAction.new()
	action3.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action3.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action3

	atk._apply_shield_charge_impact(def, fwd)

	for f in range(10):
		await process_frame

	var def_shield_after: float = def.shield_durability
	var followed_ragdoll: bool = def_ragdoll.call("is_active")
	var followed_stunned: bool = def.is_control_impaired()

	# Wake-up block absorbed hit: shield depleted, NO ragdoll, NO stun lock!
	var t4_pass: bool = (not followed_ragdoll) and (not followed_stunned) and (def_shield_after < def_shield_before)
	_record("TEST 4: Wake-up Block protects against follow-up stun-lock loop", t4_pass,
		"Ragdoll re-launched=%s (Expected false), Stunned=%s (Expected false), Shield: %.1f->%.1f" % [
			followed_ragdoll, followed_stunned, def_shield_before, def_shield_after
		])

	print("\n" + "=".repeat(60))
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_pass_count, _pass_count + _fail_count, _fail_count])
	print("=".repeat(60))

	quit(0 if _fail_count == 0 else 1)
