extends SceneTree

var _passes: int = 0
var _failures: int = 0


func _init() -> void:
	print("==================================================")
	print("RUNNING TASK: KNIGHT Z — GIANT SHIELD CHARGE TEST")
	print("==================================================")
	call_deferred("_run_all_tests")


func assert_true(condition: bool, message: String) -> void:
	if condition:
		_passes += 1
		print("[PASS] %s" % message)
	else:
		_failures += 1
		print("[FAIL] %s" % message)


func _run_all_tests() -> void:
	var arena_scene: PackedScene = load("res://scenes/CombatTestArena.tscn")
	if not arena_scene:
		print("[FAIL] Failed to load CombatTestArena.tscn")
		quit(1)
		return

	var arena: Node3D = arena_scene.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame

	var p: PlayerController = arena.find_child("Player", true, false) as PlayerController
	var dummy: TrainingDummy = arena.find_child("TrainingDummy", true, false) as TrainingDummy
	assert_true(p != null and dummy != null, "TEST 1: Player and TrainingDummy initialized in test arena")

	p.hero_profile = "knight"
	p.equip_knight_loadout()
	await process_frame

	var asys: AbilitySystem = p.ability_system
	var sc: StaminaComponent = p.stamina_component
	var s1: AbilityData = asys.get_ability("skill_1")
	print("[Z_LOCKED] data=", [s1.damage, s1.stamina_cost, s1.cooldown, s1.startup_duration, s1.active_duration, s1.recovery_duration, s1.hit_radius, s1.has_front_protection])
	# Keep the movement measurement clear of the arena's nearby attack dummy.
	p.global_position = Vector3(0.0, 0.1, 10.0)
	p._camera_yaw = 0.0
	for frame: int in range(4):
		await physics_frame
		await process_frame

	# 1. Config & Activation test
	assert_true(s1 != null and s1.id == "shield_charge" and s1.damage == 25.0 and s1.stamina_cost == 20.0 and s1.cooldown == 4.0, "TEST 2: Skill 1 data matches Giant Shield Charge (25 dmg, 20 sta, 4s cd)")

	# 2. Stamina requirement: fail if stamina < 20
	sc.current_stamina = 15.0
	var low_sta_cast: bool = p._try_cast_ability("skill_1")
	assert_true(not low_sta_cast, "TEST 3: Shield Charge rejected when stamina < 20")

	# 3. Successful activation and stamina consumption
	sc.current_stamina = 50.0
	asys.reset_cooldowns()
	var cast_ok: bool = p._try_cast_ability("skill_1")
	assert_true(cast_ok, "TEST 4: Shield Charge cast successfully with sufficient stamina")
	assert_true(sc.current_stamina == 30.0, "TEST 5: Stamina correctly deducted by 20.0 (50 -> 30)")

	# 4. Cooldown active & re-cast lockout
	assert_true(asys.get_cooldown_remaining("skill_1") > 3.5, "TEST 6: Cooldown active (~4.0s)")
	var recast: bool = p._try_cast_ability("skill_1")
	assert_true(not recast, "TEST 7: Cannot re-trigger Z while active or on cooldown")

	# 5. Shield enlargement during startup
	assert_true(p.is_shield_enlarged, "TEST 8: Shield visibly enlarges during startup/active phase")
	assert_true(p.active_ability_action != null and p.active_ability_action.is_active(), "TEST 9: AbilityAction is active")

	# 6. Real charge movement & steering (advance through startup into active phase)
	p.active_ability_action.phase_timer = 0.001
	p.active_ability_action.update(0.01) # Transition to ACTIVE phase
	assert_true(p.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE, "TEST 10: Transitioned to ACTIVE charge phase")

	var pos_before: Vector3 = p.global_position
	p._camera_yaw = 0.0 # Facing forward (-Z)
	for i in range(15):
		await physics_frame
		await process_frame
	var pos_after: Vector3 = p.global_position
	var moved_dist: float = (pos_after - pos_before).length()
	assert_true(moved_dist > 0.5, "TEST 11: Real charge movement occurred via physics (moved %.2fm, no teleport)" % moved_dist)

	# 7. Steering turn rate limit (turn camera 90° / 1.57 rad; step should be limited)
	var prev_yaw: float = p.visuals.rotation.y
	p._camera_yaw = prev_yaw + 1.57
	p._process_shield_charge(0.02) # 20ms physics step
	var current_yaw: float = p.visuals.rotation.y
	var turn_diff: float = abs(wrapf(current_yaw - prev_yaw, -PI, PI))
	var max_allowed_turn: float = p.steering_turn_rate * 0.02 + 0.01 # ~0.15 rad
	assert_true(turn_diff <= max_allowed_turn and turn_diff > 0.01, "TEST 12: Steering respects turn rate limit (turned %.3f rad, max allowed %.3f rad, no instant snapping)" % [turn_diff, max_allowed_turn])

	# 8. Front protection: Frontal incoming attack deals 0 damage to HP and 0 damage to shield
	var attacker_front: Vector3 = p.global_position + (-p.visuals.global_basis.z) * 2.0
	var hp_before_front: float = p.health_component.current_health
	var shield_before_front: float = p.shield_durability
	p.take_damage(30.0, attacker_front, 15.0)
	assert_true(p.health_component.current_health == hp_before_front, "TEST 13: Frontal attack 100%% blocked by enlarged shield (HP unaffected)")
	assert_true(p.shield_durability == shield_before_front, "TEST 14: Frontal attack does NOT degrade shield durability during charge")

	# 9. Side/back vulnerability: Attack from behind hits player normally
	var attacker_behind: Vector3 = p.global_position - (-p.visuals.global_basis.z) * 2.0
	var hp_before_back: float = p.health_component.current_health
	p.take_damage(20.0, attacker_behind, 10.0)
	assert_true(p.health_component.current_health < hp_before_back, "TEST 15: Flank/rear attack bypasses shield charge protection and deals damage")

	print("[Z_LOCKED] incoming=", [hp_before_front-p.health_component.current_health+20.0, shield_before_front-p.shield_durability, hp_before_back-p.health_component.current_health])
	# 10. Collision, damage, and single hit per cast
	dummy.global_position = p.global_position + (-p.visuals.global_basis.z) * 1.8 # In charge range, away from the old snap distance
	var dummy_hp_before: float = dummy.health_component.current_health
	var position_before_impact: Vector3 = p.global_position
	p._check_shield_charge_hit(-p.visuals.global_basis.z)
	assert_true(dummy.health_component.current_health == dummy_hp_before - 25.0, "TEST 16: Collision dealt 25 damage to enemy dummy")
	assert_true(p.global_position.is_equal_approx(position_before_impact), "Impact preserves physics position without teleporting toward the recoiling target")

	# 11. Stagger verification: TrainingDummy flinched / registered hit reaction
	assert_true(dummy._hit_reaction_count > 0, "TEST 17: Enemy dummy received stagger/hit reaction on impact")

	# 12. No duplicate damage: Second collision check in same cast must not damage dummy again
	var dummy_hp_second: float = dummy.health_component.current_health
	p._check_shield_charge_hit(-p.visuals.global_basis.z)
	assert_true(dummy.health_component.current_health == dummy_hp_second, "TEST 18: Single hit per cast enforced (no duplicate damage on subsequent frames)")

	print("[Z_LOCKED] impact=", [dummy_hp_before-dummy.health_component.current_health, dummy_hp_second-dummy.health_component.current_health])
	# 13. Recovery phase & shield retraction
	p.active_ability_action.phase_timer = 0.001
	p.active_ability_action.update(0.01) # Transition to RECOVERY phase
	assert_true(p.active_ability_action.current_phase == AbilityAction.Phase.RECOVERY, "TEST 19: Transitioned to RECOVERY phase")
	assert_true(not p.is_shield_enlarged, "TEST 20: Shield retracted upon entering recovery")

	# 14. Completion of recovery & immediate LMB combo availability
	p.active_ability_action.phase_timer = 0.001
	p.active_ability_action.update(0.01) # Advance past recovery to FINISHED
	assert_true(p.active_ability_action == null, "TEST 21: AbilityAction finished and cleaned up")
	var lmb_combo_ok: bool = p._try_combat_attack()
	assert_true(lmb_combo_ok and p.combat_state == PlayerController.CombatState.ATTACK and p._combo_step == 1, "TEST 22: Existing LMB 3-hit combo immediately usable after recovery")
	p._attack_impact_applied = true
	p._on_animation_finished("attack")
	p._combo_finisher_recovery_timer = 0.0
	p.reset_combo()
	p.transition_to(PlayerController.CombatState.IDLE)

	# 15. Death cancellation: Dying during charge cancels action cleanly
	sc.current_stamina = 100.0
	asys.reset_cooldowns()
	var cast_before_death: bool = p._try_cast_ability("skill_1")
	assert_true(cast_before_death and p.is_shield_enlarged and p.active_ability_action != null, "TEST 23: Shield Charge active prior to death test")
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(not p.is_shield_enlarged, "TEST 24: Shield retracted immediately upon death")
	assert_true(p.active_ability_action == null, "TEST 25: Active ability action cancelled cleanly on death")
	assert_true(p.combat_state == PlayerController.CombatState.DEAD, "TEST 26: Character firmly in DEAD state")

	await _run_visual_acceptance(p, dummy)
	arena.queue_free()

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [_passes, _passes + _failures, _failures])
	print("==================================================")
	quit(0 if _failures == 0 else 1)


func _visual_pair_ok(p: PlayerController) -> bool:
	return p._z_shield_original.visible != p._z_shield_visual_root.visible


func _begin_visual_case(p: PlayerController, label: String) -> void:
	p.controls_enabled = true
	if p.combat_state != PlayerController.CombatState.DEAD:
		p.transition_to(PlayerController.CombatState.DEAD)
	p.respawn(Vector3(0, 0.1, 10), 0.0)
	p.stamina_component.current_stamina = 100.0
	p.ability_system.reset_cooldowns()
	assert_true(p._try_cast_ability("skill_1"), "VISUAL: " + label + " starts Z (state=%d, recovery=%.3f, stunned=%s, impaired=%s)" % [p.combat_state, p.combo_finisher_recovery_remaining, p.is_shield_stunned, p.is_control_impaired()])
	assert_true(not p._z_shield_original.visible and p._z_shield_visual_root.visible and _visual_pair_ok(p), "VISUAL: " + label + " atomically replaces original shield")


func _restored_ok(p: PlayerController) -> bool:
	return p._z_shield_original.visible and not p._z_shield_visual_root.visible and _visual_pair_ok(p)


func _observe_return_endpoint(p: PlayerController, result: Dictionary) -> void:
	if not p._z_shield_visual_root.visible and p._z_shield_returning:
		var distance: float = p._z_shield_visual_root.global_position.distance_to(p._z_shield_socket.global_position)
		var angle: float = p._z_shield_visual_root.global_basis.get_rotation_quaternion().angle_to(p._z_shield_socket.global_basis.get_rotation_quaternion())
		assert_true(distance < 0.001 and angle < 0.001, "VISUAL: return reaches socket at hide/swap (distance=%.6f, angle=%.6f)" % [distance, angle])
		result["checked"] = true


func _wood_face_normal(mesh: Mesh) -> Vector3:
	var axis: int = mesh.get_aabb().size.min_axis_index()
	var outside: float = -INF
	var answer := Vector3.ZERO
	for surface in range(mesh.get_surface_count()):
		var material := mesh.surface_get_material(surface)
		if not material or not material.resource_name.contains("Bronze"):
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[i]]
			var b: Vector3 = vertices[indices[i+1]]
			var c: Vector3 = vertices[indices[i+2]]
			var normal := (c-a).cross(b-a).normalized()
			var center := (a+b+c)/3.0
			if absf(normal[axis]) > 0.9 and -center[axis] > outside:
				outside = -center[axis]
				answer = normal
	return answer


func _run_visual_acceptance(p: PlayerController, dummy: TrainingDummy) -> void:
	dummy.global_position = Vector3(30, 0, 30)
	var root_id: int = p._z_shield_visual_root.get_instance_id()
	var wind_id: int = p._charge_vfx.wind.get_instance_id()
	assert_true(p._z_shield_mesh.material_overlay == null, "VISUAL: physical shield has no magical aura")
	var wood_normal := _wood_face_normal(p._z_shield_original.mesh)
	assert_true(wood_normal.length() > 0.99, "VISUAL: measured outer wood face normal from Bronze triangles")
	assert_true(p._z_shield_mesh.mesh == p._z_shield_original.mesh and p._z_shield_mesh.skeleton.is_empty() and p._z_shield_mesh.skin == null, "VISUAL: shared real mesh, empty skeleton and null skin")
	var centered: Vector3 = p._z_shield_mesh.transform * p._z_shield_mesh.mesh.get_aabb().get_center()
	assert_true(centered.length() < 0.00001, "VISUAL: AABB center is the copy pivot")
	print("[Z_SIZE] legacy=", p._z_shield_legacy_size, " source=", p._z_shield_mesh.mesh.get_aabb().size, " scale=", p._z_shield_scale)
	_begin_visual_case(p, "natural completion")
	var start_match: float = p._z_shield_visual_root.global_position.distance_to(p._z_shield_socket.global_position)
	assert_true(start_match < 0.00001 and p._z_shield_visual_root.scale.is_equal_approx(Vector3.ONE), "VISUAL: starts at socket with uniform scale one")
	var max_scale_checked := false
	var pair_ok := true
	var return_checked := false
	var return_endpoint := {"checked": false}
	p._z_shield_visual_root.visibility_changed.connect(_observe_return_endpoint.bind(p, return_endpoint))
	for frame in range(120):
		await physics_frame
		await process_frame
		pair_ok = pair_ok and _visual_pair_ok(p)
		if p._z_shield_visual_root.visible and not p._z_shield_returning and p.active_ability_action and p.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE:
			var scale: Vector3 = p._z_shield_visual_root.scale
			if absf(scale.y-p._z_shield_scale) < 0.001:
				max_scale_checked = scale.distance_to(Vector3.ONE*p._z_shield_scale) < 0.001
				var face := (p._z_shield_visual_root.global_basis * p._z_shield_mesh.basis * wood_normal).normalized()
				assert_true(face.dot(-p.visuals.global_basis.z.normalized()) > 0.999, "VISUAL: wooden face points in charge direction")
				break
	assert_true(max_scale_checked, "VISUAL: during active Z uniform scale equals measured S")
	for frame in range(120):
		await physics_frame
		await process_frame
		pair_ok = pair_ok and _visual_pair_ok(p)
		if p._z_shield_returning and not return_checked:
			var tween_id: int = p._shield_visual_tween.get_instance_id()
			p._restore_z_shield_visual(false)
			assert_true(p._shield_visual_tween.get_instance_id()==tween_id, "VISUAL: repeated restore does not restart return tween")
			return_checked = true
		if p.active_ability_action == null:
			break
	assert_true(return_checked and _restored_ok(p) and p._z_shield_visual_root.scale.is_equal_approx(Vector3.ONE), "VISUAL: natural Z returns and restores shield")
	assert_true(return_endpoint["checked"], "VISUAL: return completed within recovery phase")
	assert_true(pair_ok, "VISUAL: no frame shows both shields or hides both")
	_begin_visual_case(p, "cancel")
	p.active_ability_action.cancel()
	assert_true(_restored_ok(p), "VISUAL: cancellation restores in same frame")
	p._restore_z_shield_visual(true)
	p._restore_z_shield_visual(true)
	assert_true(_restored_ok(p), "VISUAL: immediate restore is idempotent")
	_begin_visual_case(p, "knockback")
	var action = p.active_ability_action
	p.apply_knockback(Vector3.BACK, 0.4, 0.1)
	assert_true(_restored_ok(p) and p.active_ability_action == action, "VISUAL: knockback restores without changing action")
	_begin_visual_case(p, "stun")
	p._shield_stun_timer = 0.2
	await process_frame
	await process_frame
	assert_true(_restored_ok(p), "VISUAL: stun restores")
	_begin_visual_case(p, "disabled controls")
	p.controls_enabled = false
	await process_frame
	await process_frame
	assert_true(_restored_ok(p), "VISUAL: interruption restores")
	_begin_visual_case(p, "death")
	p.transition_to(PlayerController.CombatState.DEAD)
	assert_true(_restored_ok(p), "VISUAL: death restores in same frame")
	_begin_visual_case(p, "scene exit")
	var parent := p.get_parent()
	parent.remove_child(p)
	assert_true(_restored_ok(p), "VISUAL: scene exit restores in same frame")
	assert_true(p._z_shield_visual_root.get_instance_id()==root_id and p._charge_vfx.wind.get_instance_id()==wind_id, "VISUAL: repeated casts reuse root, mesh and airflow")
	p.free()
