class_name KnightRagdoll
extends Node

## Knight Ragdoll Manager (Godot 4.3 PhysicalBoneSimulator3D Architecture)
## Manages 11 physical bone bodies, simulation start/stop lifecycle, joints,
## landing detection, prone/supine pose resolution, bounds clamping, and get-up recovery.

signal ragdoll_started
signal ragdoll_stopped
signal recovery_started(is_supine: bool)
signal recovery_completed

enum RagdollState {
	INACTIVE,
	LAUNCHED,
	SETTLING,
	RECOVERING,
}

# Bone definitions for Knight rig (11 core bodies)
const BONE_CONFIGS: Array[Dictionary] = [
	{
		"bone": "hips",
		"shape": "box",
		"size": Vector3(0.28, 0.22, 0.22),
		"offset": Vector3(0, 0, 0),
		"mass": 18.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_NONE,
	},
	{
		"bone": "chest",
		"shape": "box",
		"size": Vector3(0.32, 0.28, 0.24),
		"offset": Vector3(0, 0.05, 0),
		"mass": 22.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
		"swing_span": 35.0,
		"twist_span": 25.0,
	},
	{
		"bone": "head",
		"shape": "sphere",
		"radius": 0.14,
		"offset": Vector3(0, 0.08, 0),
		"mass": 5.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
		"swing_span": 30.0,
		"twist_span": 40.0,
	},
	{
		"bone": "upper_arm.L",
		"shape": "capsule",
		"radius": 0.065,
		"height": 0.25,
		"offset": Vector3(0, -0.12, 0),
		"mass": 4.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
		"swing_span": 70.0,
		"twist_span": 60.0,
	},
	{
		"bone": "forearm.L",
		"shape": "capsule",
		"radius": 0.055,
		"height": 0.22,
		"offset": Vector3(0, -0.10, 0),
		"mass": 3.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
		"hinge_lower": -120.0,
		"hinge_upper": 0.0,
	},
	{
		"bone": "upper_arm.R",
		"shape": "capsule",
		"radius": 0.065,
		"height": 0.25,
		"offset": Vector3(0, -0.12, 0),
		"mass": 4.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
		"swing_span": 70.0,
		"twist_span": 60.0,
	},
	{
		"bone": "forearm.R",
		"shape": "capsule",
		"radius": 0.055,
		"height": 0.22,
		"offset": Vector3(0, -0.10, 0),
		"mass": 3.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
		"hinge_lower": -120.0,
		"hinge_upper": 0.0,
	},
	{
		"bone": "thigh.L",
		"shape": "capsule",
		"radius": 0.08,
		"height": 0.38,
		"offset": Vector3(0, -0.18, 0),
		"mass": 9.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
		"swing_span": 65.0,
		"twist_span": 30.0,
	},
	{
		"bone": "shin.L",
		"shape": "capsule",
		"radius": 0.07,
		"height": 0.36,
		"offset": Vector3(0, -0.18, 0),
		"mass": 6.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
		"hinge_lower": 0.0,
		"hinge_upper": 130.0,
	},
	{
		"bone": "thigh.R",
		"shape": "capsule",
		"radius": 0.08,
		"height": 0.38,
		"offset": Vector3(0, -0.18, 0),
		"mass": 9.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_CONE,
		"swing_span": 65.0,
		"twist_span": 30.0,
	},
	{
		"bone": "shin.R",
		"shape": "capsule",
		"radius": 0.07,
		"height": 0.36,
		"offset": Vector3(0, -0.18, 0),
		"mass": 6.0,
		"joint_type": PhysicalBone3D.JOINT_TYPE_HINGE,
		"hinge_lower": 0.0,
		"hinge_upper": 130.0,
	},
]

# Physical bone collision layer (layer 5: ragdoll) and mask (layer 1: world environment)
const RAGDOLL_COLLISION_LAYER: int = 16
const RAGDOLL_COLLISION_MASK: int = 1

# Recovery tuning parameters
@export var settle_duration: float = 1.1 # Time to settle on floor before stand-up (>=0.8s)
@export var flight_timeout: float = 2.2 # Maximum in-air watchdog before forced landing
@export var recovery_blend_duration: float = 0.85 # Procedural blend / get-up duration matches knight_get_up.tres
@export var cc_grace_window: float = 0.30 # Post-recovery CC immunity window

var actor: CharacterBody3D = null
var skeleton: Skeleton3D = null
var simulator: PhysicalBoneSimulator3D = null
var physical_bones: Dictionary = {} # bone_name -> PhysicalBone3D

var state: RagdollState = RagdollState.INACTIVE
var _flight_timer: float = 0.0
var _skid_timer: float = 0.0
var _settle_timer: float = 0.0
var _recovery_timer: float = 0.0
var _prev_pelvis_pos: Vector3 = Vector3.ZERO
var _cc_grace_timer: float = 0.0
var _forced_get_up := false
var _camera_rest := Vector3(0, 1.62, 0)
var _hawk_pins: Dictionary = {}
var _hawk_ankles: Dictionary = {}


func _ready() -> void:
	set_physics_process(true)


func setup(target_actor: CharacterBody3D, target_skeleton: Skeleton3D) -> void:
	actor = target_actor
	skeleton = target_skeleton
	if not skeleton:
		push_error("[KnightRagdoll] Skeleton3D is null!")
		return

	# Locate or create PhysicalBoneSimulator3D under Skeleton3D (Godot 4.3 pattern)
	simulator = skeleton.get_node_or_null("PhysicalBoneSimulator3D") as PhysicalBoneSimulator3D
	if not simulator:
		simulator = PhysicalBoneSimulator3D.new()
		simulator.name = "PhysicalBoneSimulator3D"
		skeleton.add_child(simulator)

	# Build all 11 physical bones
	for cfg in BONE_CONFIGS:
		var bname: String = cfg["bone"]
		var b_idx: int = skeleton.find_bone(bname)
		if b_idx < 0:
			push_warning("[KnightRagdoll] Bone not found in skeleton: " + bname)
			continue

		var pb_node_name: String = "PhysicalBone_" + bname.replace(".", "_")
		var pb: PhysicalBone3D = simulator.get_node_or_null(pb_node_name) as PhysicalBone3D
		if not pb:
			pb = preload("res://scripts/HawkGripBone.gd").new() if bname.begins_with("shin.") else PhysicalBone3D.new()
			pb.name = pb_node_name
			pb.bone_name = bname
			simulator.add_child(pb)

		# Configure body physics: kinetic momentum slide with heavy armor friction
		pb.mass = cfg["mass"]
		pb.gravity_scale = 1.35 # Natural buoyant arc with hang-time
		pb.linear_damp = 0.20 # Balanced linear damping
		pb.angular_damp = 0.65 # Natural limb rotation without freezing
		pb.bounce = 0.08 # Solid thud on ground followed by sliding
		pb.friction = 0.38 # Heavy knight metal friction sliding 2-3m across floor
		pb.collision_layer = RAGDOLL_COLLISION_LAYER
		pb.collision_mask = RAGDOLL_COLLISION_MASK

		# Configure Joint limits
		var joint_t: int = cfg["joint_type"]
		pb.joint_type = joint_t
		if joint_t == PhysicalBone3D.JOINT_TYPE_CONE:
			if cfg.has("swing_span"):
				pb.set("joint_constraints/swing_span", cfg["swing_span"])
			if cfg.has("twist_span"):
				pb.set("joint_constraints/twist_span", cfg["twist_span"])
			pb.set("joint_constraints/bias", 0.3)
			pb.set("joint_constraints/softness", 0.8)
		elif joint_t == PhysicalBone3D.JOINT_TYPE_HINGE:
			pb.set("joint_constraints/angular_limit_enabled", true)
			if cfg.has("hinge_lower"):
				pb.set("joint_constraints/angular_limit_lower", cfg["hinge_lower"])
			if cfg.has("hinge_upper"):
				pb.set("joint_constraints/angular_limit_upper", cfg["hinge_upper"])
			pb.set("joint_constraints/angular_limit_bias", 0.3)
			pb.set("joint_constraints/angular_limit_softness", 0.9)

		# Setup Collision Shape
		var col_shape: CollisionShape3D = pb.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if not col_shape:
			col_shape = CollisionShape3D.new()
			col_shape.name = "CollisionShape3D"
			pb.add_child(col_shape)

		if cfg["shape"] == "box":
			var box: BoxShape3D = col_shape.shape as BoxShape3D
			if not box:
				box = BoxShape3D.new()
				col_shape.shape = box
			box.size = cfg["size"]
		elif cfg["shape"] == "sphere":
			var sph: SphereShape3D = col_shape.shape as SphereShape3D
			if not sph:
				sph = SphereShape3D.new()
				col_shape.shape = sph
			sph.radius = cfg["radius"]
		elif cfg["shape"] == "capsule":
			var cap: CapsuleShape3D = col_shape.shape as CapsuleShape3D
			if not cap:
				cap = CapsuleShape3D.new()
				col_shape.shape = cap
			cap.radius = cfg["radius"]
			cap.height = cfg["height"]

		if cfg.has("offset"):
			col_shape.position = cfg["offset"]

		physical_bones[bname] = pb

	# Add collision exceptions between character proxy capsule and all physical bones
	if actor:
		for bname in physical_bones:
			var pb: PhysicalBone3D = physical_bones[bname]
			actor.add_collision_exception_with(pb)
			pb.add_collision_exception_with(actor)

	# Ensure simulator is initially dormant
	simulator.physical_bones_stop_simulation()
	state = RagdollState.INACTIVE


func start_ragdoll(initial_impulse: Vector3 = Vector3.ZERO, forced_get_up: bool = false) -> bool:
	if is_recovering(): return false
	if not simulator or not is_instance_valid(simulator):
		return false
	if actor and (actor.get("is_dead") or actor.get("combat_state") == 8): # 8 = CombatState.DEAD
		return false

	_forced_get_up = _forced_get_up or forced_get_up
	if state == RagdollState.INACTIVE and actor and actor.get_node_or_null("CameraPivot"):
		_camera_rest = actor.get_node("CameraPivot").position
	state = RagdollState.LAUNCHED
	_flight_timer = 0.0
	_skid_timer = 0.0
	_settle_timer = 0.0
	_recovery_timer = 0.0
	_prev_pelvis_pos = get_pelvis_global_position()

	if actor:
		if actor.has_method("reset_combo"):
			actor.call("reset_combo", false)
		if actor.get("combat_state") == 2: # CombatState.ATTACK
			actor.set("combat_state", 0) # IDLE
		if actor.get("active_ability_action") != null:
			var act = actor.get("active_ability_action")
			if act and act.has_method("cancel"):
				act.call("cancel")
			actor.set("active_ability_action", null)
		actor.velocity = Vector3.ZERO
		var anim_player: AnimationPlayer = actor.get_node_or_null("Visuals/CharacterModel/AnimationPlayer") as AnimationPlayer
		if anim_player:
			anim_player.stop()

	simulator.physical_bones_start_simulation()
	for bname in physical_bones:
		var pb: PhysicalBone3D = physical_bones[bname]
		if is_instance_valid(pb):
			pb.linear_velocity = Vector3.ZERO
			pb.angular_velocity = Vector3.ZERO

	if initial_impulse.length_squared() > 0.0001:
		apply_impulse(initial_impulse)

	ragdoll_started.emit()
	return true


func begin_hawk_grip() -> bool:
	if not start_ragdoll(Vector3.ZERO, true): return false
	for name: String in ["shin.L", "shin.R"]:
		var bone: PhysicalBone3D = physical_bones.get(name)
		if not bone: continue
		_hawk_pins[name] = actor.global_transform.affine_inverse() * bone.global_transform
		var foot := skeleton.find_bone(name.replace("shin", "foot"))
		_hawk_ankles[name] = bone.global_transform.affine_inverse() * skeleton.to_global(skeleton.get_bone_global_pose(foot).origin)
		bone.set("hawk_pin", bone.global_transform)
		bone.set("hawk_pinned", true)
	return true

func hawk_grip_position() -> Vector3:
	var midpoint := Vector3.ZERO
	for name: String in _hawk_ankles:
		midpoint += physical_bones[name].global_transform * _hawk_ankles[name]
	return midpoint / maxf(1, _hawk_ankles.size())

func move_hawk_grip(displacement: Vector3) -> void:
	# Transport the whole ragdoll with the bird while the joints retain their simulated sway.
	for name: String in physical_bones:
		var bone: PhysicalBone3D = physical_bones[name]
		var pose := bone.global_transform
		pose.origin += displacement
		if _hawk_pins.has(name):
			pose = actor.global_transform * _hawk_pins[name]
			bone.set("hawk_pin", pose)
		bone.global_transform = pose
		PhysicsServer3D.body_set_state(bone.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, pose)

func release_hawk_grip(velocity: Vector3) -> void:
	for name: String in _hawk_pins:
		var bone: PhysicalBone3D = physical_bones[name]
		bone.set("hawk_pinned", false)
	_hawk_pins.clear()
	_hawk_ankles.clear()
	for name: String in physical_bones:
		var bone: PhysicalBone3D = physical_bones[name]
		bone.linear_velocity = velocity

func stop_ragdoll() -> bool:
	if not simulator or not is_instance_valid(simulator):
		return false

	release_hawk_grip(Vector3.ZERO)
	simulator.physical_bones_stop_simulation()
	for bname in physical_bones:
		var pb: PhysicalBone3D = physical_bones[bname]
		if is_instance_valid(pb):
			pb.linear_velocity = Vector3.ZERO
			pb.angular_velocity = Vector3.ZERO
	state = RagdollState.INACTIVE
	_forced_get_up = false
	_restore_camera()

	if actor and not actor.get("is_dead") and actor.get("combat_state") != 8:
		var anim_player: AnimationPlayer = actor.get_node_or_null("Visuals/CharacterModel/AnimationPlayer") as AnimationPlayer
		if anim_player and not anim_player.is_playing():
			anim_player.play("idle", 0.15)

	ragdoll_stopped.emit()
	return true


func is_active() -> bool:
	return state != RagdollState.INACTIVE


func is_simulating() -> bool:
	return simulator != null and is_instance_valid(simulator) and simulator.is_simulating_physics()


func is_recovering() -> bool:
	return state == RagdollState.RECOVERING


func can_wake_up_block() -> bool:
	return not _forced_get_up and (state == RagdollState.SETTLING or state == RagdollState.RECOVERING)


func is_cc_grace_active() -> bool:
	return _cc_grace_timer > 0.0


func apply_impulse(impulse: Vector3) -> void:
	if is_recovering(): return
	if physical_bones.has("hips"):
		var hips_pb: PhysicalBone3D = physical_bones["hips"]
		hips_pb.apply_central_impulse(impulse * hips_pb.mass * 0.45)
	if physical_bones.has("chest"):
		var chest_pb: PhysicalBone3D = physical_bones["chest"]
		chest_pb.apply_central_impulse((impulse + Vector3.UP * 1.5) * chest_pb.mass * 0.40)
	if physical_bones.has("head"):
		var head_pb: PhysicalBone3D = physical_bones["head"]
		head_pb.apply_central_impulse((impulse + Vector3.UP * 2.0) * head_pb.mass * 0.30)
	if physical_bones.has("thigh.L"):
		physical_bones["thigh.L"].apply_central_impulse((impulse + Vector3.LEFT * 1.2) * 2.0)
	if physical_bones.has("thigh.R"):
		physical_bones["thigh.R"].apply_central_impulse((impulse + Vector3.RIGHT * 1.2) * 2.0)
	if physical_bones.has("upper_arm.L"):
		physical_bones["upper_arm.L"].apply_central_impulse((impulse + Vector3.LEFT * 1.5 + Vector3.UP * 1.0) * 1.5)
	if physical_bones.has("upper_arm.R"):
		physical_bones["upper_arm.R"].apply_central_impulse((impulse + Vector3.RIGHT * 1.5 + Vector3.UP * 1.0) * 1.5)


func apply_bone_impulse(bone_name: String, impulse: Vector3) -> void:
	if is_recovering(): return
	if physical_bones.has(bone_name):
		var pb: PhysicalBone3D = physical_bones[bone_name]
		pb.apply_central_impulse(impulse)


func get_pelvis_global_position() -> Vector3:
	if physical_bones.has("hips") and is_instance_valid(physical_bones["hips"]):
		return physical_bones["hips"].global_position
	if skeleton:
		var hips_idx: int = skeleton.find_bone("hips")
		if hips_idx >= 0:
			return skeleton.global_transform * skeleton.get_bone_global_pose(hips_idx).origin
	return actor.global_position if actor else Vector3.ZERO


func get_bone_count() -> int:
	return physical_bones.size()


func get_state() -> int:
	return state


## Returns true if lying on back (supine / ngửa), false if lying on chest/belly (prone / úp).
func is_supine() -> bool:
	if physical_bones.has("hips") and is_instance_valid(physical_bones["hips"]):
		var hips_pb: PhysicalBone3D = physical_bones["hips"]
		# Pelvic forward axis: if positive dot with UP, front faces upward -> Supine
		return hips_pb.global_transform.basis.z.dot(Vector3.UP) > 0.0
	return false


## Returns the ground-projected heading of the body (direction from hips toward head)
func get_lying_heading() -> Vector3:
	if physical_bones.has("hips") and is_instance_valid(physical_bones["hips"]):
		var hips_pb: PhysicalBone3D = physical_bones["hips"]
		var spine_axis: Vector3 = hips_pb.global_transform.basis.y
		spine_axis.y = 0.0
		if spine_axis.length_squared() > 0.01:
			return spine_axis.normalized()
	if actor and actor.get_node_or_null("Visuals"):
		return -actor.get_node("Visuals").global_basis.z
	return Vector3.FORWARD


func _physics_process(delta: float) -> void:
	if _cc_grace_timer > 0.0:
		_cc_grace_timer = maxf(0.0, _cc_grace_timer - delta)

	if state == RagdollState.INACTIVE:
		return
	# Carry owns the proxy/camera; never run the landing watchdog while aloft.
	if actor and actor.get("hawk_carry") and actor.hawk_carry.active(): return

	if actor and (actor.get("is_dead") or actor.get("combat_state") == 8):
		return

	var pelvis_pos: Vector3 = get_pelvis_global_position()
	var pelvis_speed: float = (pelvis_pos - _prev_pelvis_pos).length() / maxf(delta, 0.0001)
	_prev_pelvis_pos = pelvis_pos

	# Camera follow: smoothly track pelvis during ragdoll flight/tumble
	if actor and actor.get_node_or_null("CameraPivot"):
		var pivot: Node3D = actor.get_node("CameraPivot") as Node3D
		if pivot:
			var target_pivot_y: float = pelvis_pos.y + 1.2
			pivot.global_position.y = lerpf(pivot.global_position.y, target_pivot_y, 8.0 * delta)

	match state:
		RagdollState.LAUNCHED:
			_flight_timer += delta
			var near_floor: bool = pelvis_pos.y <= 0.45
			if near_floor and _flight_timer >= 0.25:
				_skid_timer += delta
			var low_speed: bool = pelvis_speed < 1.8
			var skid_settled: bool = (_skid_timer >= 0.25 and low_speed) or _skid_timer >= 0.55
			var timed_out: bool = _flight_timer >= flight_timeout

			# Must slide along the floor to bleed kinetic momentum before settling
			if skid_settled or timed_out:
				state = RagdollState.SETTLING
				_settle_timer = 0.0

		RagdollState.SETTLING:
			_settle_timer += delta
			if _settle_timer >= settle_duration:
				start_recovery()

		RagdollState.RECOVERING:
			_recovery_timer += delta
			if _recovery_timer >= recovery_blend_duration:
				finish_recovery()


func start_recovery() -> void:
	if state == RagdollState.RECOVERING:
		return
	if actor and (actor.get("is_dead") or actor.get("combat_state") == 8):
		return

	state = RagdollState.RECOVERING
	_recovery_timer = 0.0

	var pelvis_pos: Vector3 = get_pelvis_global_position()
	var ground_pos: Vector3 = _resolve_ground_position(pelvis_pos)

	# Constrain within arena bounds if available
	ground_pos = _clamp_to_bounds(ground_pos)

	var supine: bool = is_supine()
	var heading: Vector3 = get_lying_heading()

	# Snap character proxy to ground position beneath pelvis
	if actor:
		actor.global_position = ground_pos
		actor.velocity = Vector3.ZERO
		# Orient actor visuals towards lying heading
		if actor.get_node_or_null("Visuals"):
			var vis: Node3D = actor.get_node("Visuals") as Node3D
			var target_yaw: float = atan2(-heading.x, -heading.z)
			vis.rotation.y = target_yaw
			actor.set("_camera_yaw", target_yaw)

	# Terminate physical bone simulation so Skeleton3D follows animation
	if simulator and simulator.is_simulating_physics():
		simulator.physical_bones_stop_simulation()

	# Play natural stand-up animation with proper joint articulation
	if actor:
		if actor.get_node_or_null("Visuals"):
			var vis_node: Node3D = actor.get_node("Visuals") as Node3D
			vis_node.rotation.x = 0.0
		var anim_player: AnimationPlayer = actor.get_node_or_null("Visuals/CharacterModel/AnimationPlayer") as AnimationPlayer
		if anim_player:
			if anim_player.has_animation("get_up"):
				anim_player.speed_scale = 1.0
				recovery_blend_duration = anim_player.get_animation("get_up").length
				anim_player.play("get_up", 0.15)
			elif anim_player.has_animation("idle"):
				anim_player.play("idle", 0.25)

	recovery_started.emit(supine)


func finish_recovery() -> void:
	state = RagdollState.INACTIVE
	_cc_grace_timer = cc_grace_window
	_forced_get_up = false
	_restore_camera()

	if actor and not actor.get("is_dead") and actor.get("combat_state") != 8:
		actor.velocity = Vector3.ZERO
		if actor.has_method("transition_to"):
			actor.call("transition_to", 0) # CombatState.IDLE
		var anim_player: AnimationPlayer = actor.get_node_or_null("Visuals/CharacterModel/AnimationPlayer") as AnimationPlayer
		if anim_player and anim_player.has_animation("idle"):
			anim_player.play("idle", 0.15)

	recovery_completed.emit()


func _restore_camera() -> void:
	if actor and actor.get_node_or_null("CameraPivot"):
		actor.get_node("CameraPivot").position = _camera_rest


func _resolve_ground_position(pos: Vector3) -> Vector3:
	if not actor:
		return pos
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	if not space:
		return Vector3(pos.x, maxf(0.0, pos.y), pos.z)

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 0.5,
		pos + Vector3.DOWN * 3.0,
		RAGDOLL_COLLISION_MASK
	)
	var result: Dictionary = space.intersect_ray(query)
	if not result.is_empty():
		return result.position
	return Vector3(pos.x, maxf(0.0, pos.y), pos.z)


func _clamp_to_bounds(pos: Vector3) -> Vector3:
	# Keep within a safe radius from arena center (e.g. 18m if not clamped by play bounds)
	var horiz: Vector2 = Vector2(pos.x, pos.z)
	if horiz.length() > 22.0:
		horiz = horiz.normalized() * 22.0
		return Vector3(horiz.x, pos.y, horiz.y)
	return pos
