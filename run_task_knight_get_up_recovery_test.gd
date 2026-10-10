extends SceneTree

## Acceptance Test for Knight Get-Up Recovery:
## 1. Natural get-up animation with proper anatomical joint articulation (replaces wooden tilt).
## 2. Invulnerability: No damage taken during get-up recovery.
## 3. Stun immunity: No impact stun or knockback interruption while getting up.
## 4. Smooth transition into idle combat stance upon recovery completion.

const PlayerScene = preload("res://scenes/Player.tscn")
const KnightAbilities = preload("res://scripts/KnightAbilities.gd")

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("\n" + "=".repeat(60))
	print("RUNNING KNIGHT GET-UP ANIMATION & IMMUNITY TESTS")
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
	arena.name = "RecoveryArena"
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
	var def_anim: AnimationPlayer = def.anim_player

	# -------------------------------------------------------------
	# TEST 1: Get-up animation asset registered & verified
	# -------------------------------------------------------------
	var has_get_up: bool = def_anim != null and def_anim.has_animation("get_up")
	var get_up_tracks: int = 0
	if has_get_up:
		var gu_anim: Animation = def_anim.get_animation("get_up")
		get_up_tracks = gu_anim.get_track_count()
	var t1_pass: bool = has_get_up and get_up_tracks >= 15
	_record("TEST 1: Knight get-up animation registered with full joint tracks", t1_pass,
		"Has get_up=%s, Joint Tracks=%d (>=15)" % [has_get_up, get_up_tracks])

	# -------------------------------------------------------------
	# TEST 2: Launch defender and reach RECOVERING state
	# -------------------------------------------------------------
	var action: AbilityAction = AbilityAction.new()
	action.init_action(atk, "skill_1", KnightAbilities.create_shield_charge())
	action.current_phase = AbilityAction.Phase.ACTIVE
	atk.active_ability_action = action

	atk._apply_shield_charge_impact(def, Vector3.FORWARD)

	# Wait until Defender lands on floor and enters SETTLING (State 2)
	var wait_flight: int = 0
	while def_ragdoll.call("get_state") != 2 and wait_flight < 150:
		await process_frame
		wait_flight += 1

	# Wait until SETTLING finishes and RECOVERING begins (State 3)
	var wait_settle: int = 0
	while def_ragdoll.call("get_state") != 3 and wait_settle < 200:
		await process_frame
		wait_settle += 1

	var is_recovering: bool = def_ragdoll.call("is_recovering")
	var current_anim: String = def_anim.current_animation if def_anim else ""
	var visuals_tilt_x: float = def.visuals.rotation.x if def.visuals else 0.0

	# Ensure get_up animation is playing and no rigid wooden tilt is applied
	var t2_pass: bool = is_recovering and current_anim == "get_up" and absf(visuals_tilt_x) < 0.05
	_record("TEST 2: Natural get-up animation plays during recovery without wooden tilt", t2_pass,
		"Is Recovering=%s, Current Anim='%s', Visuals Pitch=%.2f rad" % [is_recovering, current_anim, visuals_tilt_x])

	# -------------------------------------------------------------
	# TEST 3: Invulnerability: No damage taken during get-up
	# -------------------------------------------------------------
	var hp_before: float = def.health_component.current_health
	# Attacker tries to deal 30 damage while defender is getting up
	def.take_damage(30.0, atk.global_position)
	await process_frame

	var hp_after: float = def.health_component.current_health
	var t3_pass: bool = (hp_after == hp_before) and is_recovering
	_record("TEST 3: Complete damage invulnerability during get-up recovery", t3_pass,
		"HP before=%.1f, HP after=%.1f (Expected unchanged)" % [hp_before, hp_after])

	# -------------------------------------------------------------
	# TEST 4: Stun & Knockback Immunity during get-up
	# -------------------------------------------------------------
	var pos_before: Vector3 = def.global_position
	# Attacker attempts to apply 1.0s stun and 3.0m knockback
	var stun_applied: bool = def.apply_impact_stun(1.0)
	def.apply_knockback(Vector3.FORWARD, 3.0, 0.3)
	await process_frame

	var pos_after: Vector3 = def.global_position
	var stun_timer: float = def.get("_impact_stun_timer")
	var disp: float = (pos_after - pos_before).length()

	var t4_pass: bool = (not stun_applied) and (stun_timer == 0.0) and (disp < 0.05)
	_record("TEST 4: Complete immunity to stun & knockback interruption during get-up", t4_pass,
		"Stun applied=%s (Expected false), Stun timer=%.2f (Expected 0.0), Displacement=%.3fm" % [
			stun_applied, stun_timer, disp
		])

	# -------------------------------------------------------------
	# TEST 5: Stand-up finishes seamlessly and transitions into IDLE
	# -------------------------------------------------------------
	var wait_finish: int = 0
	while def_ragdoll.call("is_active") and wait_finish < 150:
		await process_frame
		wait_finish += 1

	var final_state: int = def.combat_state
	var final_anim: String = def_anim.current_animation if def_anim else ""
	var final_active: bool = def_ragdoll.call("is_active")
	var cc_grace: bool = def_ragdoll.call("is_cc_grace_active")

	var t5_pass: bool = (not final_active) and final_state == PlayerController.CombatState.IDLE and final_anim == "idle" and cc_grace
	_record("TEST 5: Clean transition into IDLE stance with post-recovery CC grace", t5_pass,
		"Ragdoll active=%s, CombatState=%d (Expected IDLE=0), Anim='%s', CC Grace=%s" % [
			final_active, final_state, final_anim, cc_grace
		])

	print("\n" + "=".repeat(60))
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_pass_count, _pass_count + _fail_count, _fail_count])
	print("=".repeat(60))

	quit(0 if _fail_count == 0 else 1)
