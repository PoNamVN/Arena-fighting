class_name WizardPresentation
extends Node

# Visual poses only: no movement, hit timing, energy or collision changes.
const BLEND_SPEED: float = 12.0
const RELEASE_DURATION: float = 0.35
var kit: WizardCombat
var mode: String = "idle"
var release_remaining: float = 0.0
var release_color: Color = Color(1, 0.35, 0.06)
var palm_ring: MeshInstance3D
var ground_ring: MeshInstance3D
var staff_glow: MeshInstance3D
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _rests: Dictionary = {}
var _time: float = 0.0
var _left_weight: float = 0.0
var _right_hand: Vector3 = Vector3(0.38, 1.05, 0.12)
var _right_elbow: Vector3 = Vector3(0.42, 1.18, -0.02)
var _left_hand: Vector3 = Vector3(-0.22, 1.32, 0.42)
var _left_elbow: Vector3 = Vector3(-0.35, 1.15, 0.12)
var _staff_tilt: float = -0.12
var _staff_pitch: float = 0.0
var _palm_material: ShaderMaterial
var _ground_material: ShaderMaterial
var _glow_material: StandardMaterial3D
var _model: Node3D
var _model_rest: Transform3D
var _body_lean: float = 0
var _lift: float = 0

func _ready() -> void:
	_model = kit.actor.visuals.get_node("CharacterModel") as Node3D
	_model_rest = _model.transform
	_skeleton = kit.actor._skeleton
	if _skeleton:
		for name: String in ["upper_arm.R", "forearm.R", "hand.R", "upper_arm.L", "forearm.L", "hand.L"]:
			var index: int = _skeleton.find_bone(name)
			if index >= 0:
				_bones[name] = index
				_rests[name] = _skeleton.get_bone_global_rest(index)
	var ring_mesh: PlaneMesh = PlaneMesh.new()
	ring_mesh.size = Vector2(0.62, 0.62)
	palm_ring = _visual(ring_mesh, kit.actor)
	ground_ring = _visual(ring_mesh, kit.actor)
	_palm_material = preload("res://scripts/CombatSpectacle.gd").sigil_material(Color(0.3, 0.75, 1))
	_ground_material = preload("res://scripts/CombatSpectacle.gd").sigil_material(Color(0.3, 0.75, 1))
	_ground_material.set_shader_parameter("opacity", 0.4)
	palm_ring.material_override = _palm_material
	ground_ring.material_override = _ground_material
	var glow_mesh: SphereMesh = SphereMesh.new()
	glow_mesh.radius = 0.10
	glow_mesh.height = 0.20
	glow_mesh.radial_segments = 8
	glow_mesh.rings = 4
	staff_glow = _visual(glow_mesh, kit._staff)
	staff_glow.top_level = false
	staff_glow.position = Vector3(0.04, 1.2, 0)
	_glow_material = staff_glow.material_override as StandardMaterial3D

func _visual(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = kit._material(Color(0.3, 0.75, 1, 0.65))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	node.top_level = true
	node.hide()
	return node

func released(color: Color) -> void:
	release_color = color
	release_remaining = RELEASE_DURATION

func update(delta: float) -> void:
	var actor: PlayerController = kit.actor
	if actor.is_dead or not actor.controls_enabled or actor.is_control_impaired():
		reset()
		return
	_time += delta
	release_remaining = maxf(0, release_remaining - delta)
	mode = "idle"
	var right_hand: Vector3 = Vector3(0.38, 1.05, 0.12)
	var right_elbow: Vector3 = Vector3(0.42, 1.18, -0.02)
	var left_hand: Vector3 = Vector3(-0.22, 1.32, 0.42)
	var left_elbow: Vector3 = Vector3(-0.35, 1.15, 0.12)
	var tilt: float = -0.12
	var pitch: float = 0.0
	var color: Color = Color(0.3, 0.75, 1)
	var left_active: bool = true
	if kit.storm.channeling():
		mode = "storm"
		right_hand = Vector3(0.42, 1.72, 0.04)
		right_elbow = Vector3(0.52, 1.48, -0.02)
		left_hand = Vector3(-0.42, 1.78, 0.12)
		left_hand.y += sin(_time * 3.0) * 0.035
		right_hand.y += cos(_time * 3.0) * 0.035
		left_elbow = Vector3(-0.55, 1.48, 0.02)
		tilt = -0.24
	elif kit.ice.active:
		mode = "ice"
		right_hand = Vector3(0.40, 0.88, 0.38)
		right_elbow = Vector3(0.48, 1.02, 0.16)
		left_hand = Vector3(-0.40, 1.05, -0.12)
		left_elbow = Vector3(-0.48, 1.16, -0.18)
		pitch = -0.5
	elif kit.staff_strike.active:
		mode = "staff"
		var drop: float = smoothstep(WizardStaffStrike.WARNING, WizardStaffStrike.WARNING + WizardStaffStrike.FALL, kit.staff_strike.elapsed)
		right_hand = Vector3(0.35, 1.65, 0.05).lerp(Vector3(0.35, 1.03, 0.48), drop)
		right_elbow = Vector3(0.52, 1.42, 0.02).lerp(Vector3(0.48, 1.12, 0.22), drop)
		left_hand = Vector3(-0.22, 1.50, 0.28).lerp(Vector3(-0.25, 1.18, 0.46), drop)
		pitch = -0.6 * drop
		color = Color(0.9, 0.65, 0.25)
	elif kit.spell == "X":
		mode = "hex"
		left_hand = Vector3(-0.20, 1.48, 0.52)
		left_elbow = Vector3(-0.38, 1.25, 0.20)
		pitch = -0.25
		color = Color(0.8, 0.3, 1)
	elif kit.counter_active or release_remaining > 0:
		mode = "release"
		left_hand = Vector3(-0.18, 1.36, 0.60)
		left_elbow = Vector3(-0.34, 1.16, 0.30)
		pitch = -0.3
		color = release_color
	elif actor.is_blocking:
		mode = "guard"
		left_hand = Vector3(-0.20, 1.42, 0.43)
		left_elbow = Vector3(-0.38, 1.18, 0.14)
		tilt = 0.08
	elif kit.charging:
		mode = "charge"
		var charge: float = kit.charge_time / WizardCombat.MAX_CHARGE
		left_hand = Vector3(-0.25, 1.24, 0.30).lerp(Vector3(-0.18, 1.46, 0.52), charge)
		left_hand.y += sin(_time * 5) * 0.025
		left_elbow = Vector3(-0.38, 1.15, 0.12)
		tilt = -0.18
		color = Color(1, 0.35, 0.06)
	else:
		left_active = false
	var blend: float = 1 - exp(-BLEND_SPEED * delta)
	_body_lean = lerpf(_body_lean, -0.12 if mode == "ice" else 0.09 if mode == "release" else -0.04 if mode == "charge" else 0.0, blend)
	_lift = lerpf(_lift, 0.12 + sin(_time * 2.5) * 0.025 if mode == "storm" else 0.0, blend)
	_model.transform = _model_rest * Transform3D(Basis(Vector3.RIGHT, _body_lean), Vector3.UP * _lift)
	_right_hand = _right_hand.lerp(right_hand, blend)
	_right_elbow = _right_elbow.lerp(right_elbow, blend)
	_left_hand = _left_hand.lerp(left_hand, blend)
	_left_elbow = _left_elbow.lerp(left_elbow, blend)
	_left_weight = lerpf(_left_weight, 1 if left_active else 0, blend)
	_staff_tilt = lerpf(_staff_tilt, tilt, blend)
	_staff_pitch = lerpf(_staff_pitch, pitch, blend)
	var grip: Vector3 = _arm("R", _right_hand, _right_elbow, 1)
	_arm("L", _left_hand, _left_elbow, _left_weight)
	kit._staff.global_position = _skeleton.to_global(grip) if _skeleton else actor.visuals.to_global(Vector3(0.38, 1.05, -0.12))
	kit._staff.rotation = Vector3(_staff_pitch, 0, _staff_tilt)
	var casting: bool = mode in ["charge", "hex", "release", "staff", "storm", "ice"]
	staff_glow.visible = casting
	_glow_material.albedo_color = Color(color, 0.7)
	staff_glow.scale = Vector3.ONE * (1 + sin(_time * 7) * 0.12)
	palm_ring.visible = mode in ["charge", "hex", "release"]
	if palm_ring.visible:
		palm_ring.global_position = actor.global_position + Vector3.UP * 1.35 - actor.visuals.global_basis.z * 0.65
		palm_ring.global_rotation = Vector3(PI / 2, actor.visuals.global_rotation.y, _time * 1.5)
		palm_ring.scale = Vector3.ONE * (1 + kit.charge_time / WizardCombat.MAX_CHARGE * 0.6)
		_palm_material.set_shader_parameter("tint", Color(color, 0.75))
	ground_ring.visible = mode in ["storm", "ice"]
	if ground_ring.visible:
		ground_ring.global_position = actor.global_position + Vector3.UP * 0.08
		ground_ring.global_rotation = Vector3(0, _time * 0.6, 0)
		ground_ring.scale = Vector3.ONE * (3.8 if mode == "storm" else 2.4)
		_ground_material.set_shader_parameter("tint", Color(color, 0.85))

func _arm(side: String, hand: Vector3, elbow: Vector3, weight: float) -> Vector3:
	# Author poses with right/forward positive; the imported rig uses -X for R and -Z forward.
	hand = Vector3(-hand.x, hand.y, -hand.z)
	elbow = Vector3(-elbow.x, elbow.y, -elbow.z)
	var upper_name: String = "upper_arm." + side
	var forearm_name: String = "forearm." + side
	var hand_name: String = "hand." + side
	if not _bones.has(hand_name):
		return hand
	var upper_rest: Transform3D = _rests[upper_name]
	var forearm_rest: Transform3D = _rests[forearm_name]
	var hand_rest: Transform3D = _rests[hand_name]
	var upper_direction: Vector3 = (elbow - upper_rest.origin).normalized()
	var actual_elbow: Vector3 = upper_rest.origin + upper_direction * upper_rest.origin.distance_to(forearm_rest.origin)
	var forearm_direction: Vector3 = (hand - actual_elbow).normalized()
	var upper_basis: Basis = Basis(Quaternion(upper_rest.basis.y.normalized(), upper_direction)) * upper_rest.basis
	var forearm_basis: Basis = Basis(Quaternion(forearm_rest.basis.y.normalized(), forearm_direction)) * forearm_rest.basis
	_skeleton.set_bone_global_pose_override(_bones[upper_name], Transform3D(upper_basis, upper_rest.origin), weight, true)
	_skeleton.set_bone_global_pose_override(_bones[forearm_name], Transform3D(forearm_basis, actual_elbow), weight, true)
	return actual_elbow + forearm_direction * forearm_rest.origin.distance_to(hand_rest.origin)

func reset() -> void:
	mode = "idle"
	release_remaining = 0
	_left_weight = 0
	_body_lean = 0
	_lift = 0
	if is_instance_valid(_model):
		_model.transform = _model_rest
	if _skeleton:
		for name: String in ["upper_arm.R", "forearm.R", "upper_arm.L", "forearm.L"]:
			if _bones.has(name):
				_skeleton.set_bone_global_pose_override(_bones[name], Transform3D.IDENTITY, 0, false)
	for node: MeshInstance3D in [palm_ring, ground_ring, staff_glow]:
		if is_instance_valid(node):
			node.hide()
