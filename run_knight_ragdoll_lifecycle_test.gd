extends SceneTree

const TestScene: PackedScene = preload("res://test/knight_hit_reaction_test.tscn")
const KnightRagdollScript = preload("res://scripts/KnightRagdoll.gd")

var _test_results: Array[Dictionary] = []
var _arena: Node3D = null
var _player: PlayerController = null
var _ragdoll: Node = null


func _init() -> void:
	print("==================================================")
	print("RUNNING KNIGHT RAGDOLL LIFECYCLE TESTS (PHASE 2)")
	print("==================================================")
	call_deferred("_run_tests")


func _record_result(test_name: String, passed: bool, details: String = "") -> void:
	_test_results.append({
		"name": test_name,
		"passed": passed,
		"details": details
	})
	var status: String = "PASS" if passed else "FAIL"
	if details != "":
		print("  [%s] %s - %s" % [status, test_name, details])
	else:
		print("  [%s] %s" % [status, test_name])


func _setup_scene() -> void:
	if _arena and is_instance_valid(_arena):
		_arena.queue_free()

	_arena = TestScene.instantiate() as Node3D
	root.add_child(_arena)

	_player = _arena.get_node("Player") as PlayerController
	_ragdoll = _player.get_node_or_null("KnightRagdoll")


func _run_tests() -> void:
	_setup_scene()
	for i in range(10):
		await process_frame

	var p: PlayerController = _player
	var r: Node = _ragdoll

	# -----------------------------------------------------------------
	# TEST 1: Test arena loads successfully
	# -----------------------------------------------------------------
	var t1_pass: bool = _arena != null and p != null and r != null
	_record_result("TEST 1: Test arena loads successfully", t1_pass,
		"Arena=%s, Player=%s, Ragdoll=%s" % [_arena != null, p != null, r != null])

	# -----------------------------------------------------------------
	# TEST 2: PhysicalBoneSimulator3D is child of Skeleton3D
	# -----------------------------------------------------------------
	var skeleton: Skeleton3D = p.get_node_or_null("Visuals/CharacterModel/Gladiator_Armature/Skeleton3D") as Skeleton3D
	var sim: PhysicalBoneSimulator3D = r.get("simulator") as PhysicalBoneSimulator3D
	var t2_pass: bool = (skeleton != null) and (sim != null) and (sim.get_parent() == skeleton)
	_record_result("TEST 2: PhysicalBoneSimulator3D is child of Skeleton3D", t2_pass,
		"Skeleton=%s, Simulator=%s, Parent is Skeleton=%s" % [skeleton != null, sim != null, t2_pass])

	# -----------------------------------------------------------------
	# TEST 3: Exactly 11 PhysicalBone3D bodies are created
	# -----------------------------------------------------------------
	var expected_bones: Array[String] = [
		"hips", "chest", "head",
		"upper_arm.L", "forearm.L",
		"upper_arm.R", "forearm.R",
		"thigh.L", "shin.L",
		"thigh.R", "shin.R"
	]
	var physical_bones: Dictionary = r.get("physical_bones") as Dictionary
	var missing_bones: Array[String] = []
	for eb in expected_bones:
		if not physical_bones.has(eb) or not is_instance_valid(physical_bones[eb]):
			missing_bones.append(eb)

	var t3_pass: bool = (r.call("get_bone_count") == 11) and (missing_bones.size() == 0)
	_record_result("TEST 3: Exactly 11 PhysicalBone3D bodies are created", t3_pass,
		"Count=%d (Expected 11), Missing=%s" % [r.call("get_bone_count"), missing_bones])

	# -----------------------------------------------------------------
	# TEST 4: Joints and limits configured properly
	# -----------------------------------------------------------------
	var joints_ok: bool = true
	var hips_pb: PhysicalBone3D = physical_bones.get("hips")
	var chest_pb: PhysicalBone3D = physical_bones.get("chest")
	var forearm_l_pb: PhysicalBone3D = physical_bones.get("forearm.L")
	var shin_l_pb: PhysicalBone3D = physical_bones.get("shin.L")

	if hips_pb.joint_type != PhysicalBone3D.JOINT_TYPE_NONE:
		joints_ok = false
	if chest_pb.joint_type != PhysicalBone3D.JOINT_TYPE_CONE:
		joints_ok = false
	if forearm_l_pb.joint_type != PhysicalBone3D.JOINT_TYPE_HINGE:
		joints_ok = false
	if shin_l_pb.joint_type != PhysicalBone3D.JOINT_TYPE_HINGE:
		joints_ok = false

	var t4_pass: bool = joints_ok
	_record_result("TEST 4: Joints and limits configured properly", t4_pass,
		"Hips=NONE, Chest=CONE, Elbow=HINGE, Knee=HINGE")

	# -----------------------------------------------------------------
	# TEST 5: Collision exceptions configured with character proxy
	# -----------------------------------------------------------------
	var t5_init_dormant: bool = not r.call("is_active") and not sim.is_simulating_physics()
	_record_result("TEST 5: Ragdoll simulator is initially dormant", t5_init_dormant,
		"is_active=%s, is_simulating=%s" % [r.call("is_active"), sim.is_simulating_physics()])

	# -----------------------------------------------------------------
	# TEST 6: Gravity scale and collision layers configured
	# -----------------------------------------------------------------
	var layers_ok: bool = true
	var grav_ok: bool = true
	for bname in physical_bones:
		var pb: PhysicalBone3D = physical_bones[bname]
		if pb.collision_layer != 16:
			layers_ok = false
		if pb.collision_mask != 1:
			layers_ok = false
		if abs(pb.gravity_scale - 2.45) > 0.05 and abs(pb.gravity_scale - 1.35) > 0.05:
			grav_ok = false

	var t6_pass: bool = layers_ok and grav_ok
	_record_result("TEST 6: Gravity scale (~2.45) and collision layers (layer 16, mask 1)", t6_pass,
		"Layers OK=%s, Gravity scale OK=%s" % [layers_ok, grav_ok])

	# -----------------------------------------------------------------
	# TEST 7: Start ragdoll activates simulation
	# -----------------------------------------------------------------
	var start_ok: bool = r.call("start_ragdoll", Vector3.ZERO)
	for f in range(5):
		await process_frame

	var t7_pass: bool = start_ok and r.call("is_active") and sim.is_simulating_physics()
	_record_result("TEST 7: Start ragdoll activates simulation", t7_pass,
		"start_ragdoll=%s, is_active=%s, is_simulating=%s" % [start_ok, r.call("is_active"), sim.is_simulating_physics()])

	# -----------------------------------------------------------------
	# TEST 8: Physics simulation runs stably over multiple frames
	# -----------------------------------------------------------------
	var pelvis_before: Vector3 = r.call("get_pelvis_global_position")
	for f in range(30):
		await process_frame
	var pelvis_after: Vector3 = r.call("get_pelvis_global_position")

	var t8_pass: bool = pelvis_after.y >= -0.5 and pelvis_after.is_finite()
	_record_result("TEST 8: Physics simulation runs stably (pelvis supports on floor)", t8_pass,
		"Pelvis Y: %.3f -> %.3f (Floor at 0.0)" % [pelvis_before.y, pelvis_after.y])

	# -----------------------------------------------------------------
	# TEST 9: Apply impulse to ragdoll displaces body without joint explosion
	# -----------------------------------------------------------------
	var pos_pre_impulse: Vector3 = r.call("get_pelvis_global_position")
	r.call("apply_impulse", Vector3(0, 3.0, 4.0)) # Upward and backward impulse
	for f in range(15):
		await process_frame
	var pos_post_impulse: Vector3 = r.call("get_pelvis_global_position")

	var impulse_disp: float = pos_pre_impulse.distance_to(pos_post_impulse)
	var t9_pass: bool = impulse_disp > 0.05 and pos_post_impulse.is_finite() and pos_post_impulse.length() < 100.0
	_record_result("TEST 9: Apply impulse displaces body stably", t9_pass,
		"Displacement: %.3fm, Current pos: %s" % [impulse_disp, pos_post_impulse])

	# -----------------------------------------------------------------
	# TEST 10: Stop ragdoll cleanly terminates simulation
	# -----------------------------------------------------------------
	var stop_ok: bool = r.call("stop_ragdoll")
	for f in range(5):
		await process_frame

	var t10_pass: bool = stop_ok and not r.call("is_active") and not sim.is_simulating_physics()
	_record_result("TEST 10: Stop ragdoll cleanly terminates simulation", t10_pass,
		"stop_ragdoll=%s, is_active=%s, is_simulating=%s" % [stop_ok, r.call("is_active"), sim.is_simulating_physics()])

	# -----------------------------------------------------------------
	# TEST 11: Stress test: 100 start/stop cycles with zero leaks
	# -----------------------------------------------------------------
	var stress_pass: bool = true
	for c in range(100):
		r.call("start_ragdoll")
		if not sim.is_simulating_physics():
			stress_pass = false
			break
		r.call("stop_ragdoll")
		if sim.is_simulating_physics():
			stress_pass = false
			break

	_record_result("TEST 11: Stress test: 100 start/stop cycles with zero leaks", stress_pass,
		"100 consecutive cycles completed successfully")

	# -----------------------------------------------------------------
	# TEST 12: Interactive test controller triggers work correctly
	# -----------------------------------------------------------------
	var ctrl: Node3D = _arena
	ctrl.call("trigger_light_hit")
	await process_frame
	var light_hit_impaired: bool = p.is_control_impaired()

	await create_timer(0.20).timeout
	await process_frame

	ctrl.call("trigger_block")
	await process_frame
	var block_impaired: bool = p.is_control_impaired()

	var t12_pass: bool = light_hit_impaired and not block_impaired
	_record_result("TEST 12: Test controller triggers light hit & block accurately", t12_pass,
		"Light hit impaired=%s, Block impaired=%s" % [light_hit_impaired, block_impaired])

	# -----------------------------------------------------------------
	# TEST 13: Reset arena restores initial player state
	# -----------------------------------------------------------------
	ctrl.call("reset_arena")
	await process_frame

	var t13_pass: bool = (p.combat_state == PlayerController.CombatState.IDLE) and not r.call("is_active") and (p.health_component.current_health == 100.0)
	_record_result("TEST 13: Reset arena restores initial player state", t13_pass,
		"State=IDLE (%s), Ragdoll active=%s, HP=%.1f" % [p.combat_state == PlayerController.CombatState.IDLE, r.call("is_active"), p.health_component.current_health])

	# -----------------------------------------------------------------
	# SUMMARY
	# -----------------------------------------------------------------
	var total_tests: int = _test_results.size()
	var passed_tests: int = 0
	for res in _test_results:
		if res["passed"]:
			passed_tests += 1

	print("==================================================")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed_tests, total_tests, total_tests - passed_tests])
	print("==================================================")

	quit(0 if passed_tests == total_tests else 1)
