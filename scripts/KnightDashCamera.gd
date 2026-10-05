extends Node

## Dash and Knight skill rendering camera. Player.camera remains the authoritative look/aim camera.
@export var enabled := true
@export var follow_rotation := true
@export_range(0.0, 1.0, 0.05) var head_motion_strength := 1.0
@export_range(0.01, 0.2, 0.01) var return_duration := 0.12
const ENTRY_DURATION := 0.025

var player: PlayerController
var presentation: Node
var source: Camera3D
var render_camera: Camera3D
var skeleton: Skeleton3D
var owns_camera := false
var returning := false
var _entry_time := 0.0
var _return_time := 0.0
var _return_offset := Transform3D.IDENTITY
var _chain: Array[int] = []
var _head_rest := Transform3D.IDENTITY
var _hips_rest := Transform3D.IDENTITY
var _hips_world := Transform3D.IDENTITY
var _skeleton_reference := Transform3D.IDENTITY
var _head := -1
var _neck := -1
var _hips := -1

func _ready() -> void:
	# AnimationPlayer and the dash model update before this rendering-only observer.
	process_priority = 125
	call_deferred("_bind")

func _bind() -> void:
	presentation = get_parent()
	player = presentation.get_parent() as PlayerController
	if not player or player.hero_profile != "knight" or not player.camera or not player._skeleton:
		set_process(false)
		return
	source = player.camera
	skeleton = player._skeleton
	_head = skeleton.find_bone("head")
	_neck = skeleton.find_bone("neck")
	_hips = skeleton.find_bone("hips")
	if _head < 0 or _hips < 0:
		set_process(false)
		return
	var bone := _head
	while bone >= 0:
		_chain.push_front(bone)
		bone = skeleton.get_bone_parent(bone)
	_head_rest = skeleton.get_bone_global_rest(_head)
	_hips_rest = skeleton.get_bone_global_rest(_hips)
	_skeleton_reference = player.visuals.global_transform.affine_inverse() * skeleton.global_transform
	# Allocate once, inherit the original camera's rendering settings, and reuse it.
	render_camera = source.duplicate(0) as Camera3D
	render_camera.name = "FirstPersonDashCamera"
	render_camera.current = false
	render_camera.top_level = true
	add_child(render_camera)
	render_camera.global_transform = source.global_transform
	render_camera.tree_exiting.connect(_restore)
	player.state_changed.connect(_on_state_changed)
	player.ability_action_started.connect(_on_action_started)

func _head_world_transform() -> Transform3D:
	var pose := Transform3D.IDENTITY
	for i in _chain.size():
		var index := _chain[i]
		var scale := skeleton.get_bone_pose_scale(index)
		# FPS hides the helmet by collapsing neck/head scales. Ignore only those
		# display scales when reconstructing the virtual eye position/orientation.
		if index == _head or index == _neck:
			scale = Vector3.ONE
		var local := Transform3D(Basis(skeleton.get_bone_pose_rotation(index)).scaled(scale), skeleton.get_bone_pose_position(index))
		# Godot 4 stores the local bone pose in parent space, including its rest
		# transform. Multiplying by rest again would double the head offset/rotation.
		pose = pose * local
		if index == _hips:
			_hips_world = skeleton.global_transform * pose
	return skeleton.global_transform * pose

func _skill_following() -> bool:
	if not is_instance_valid(player) or not player.active_ability_action or not player.active_ability_action.is_active():
		return false
	var id: String = player.active_ability_action.data.id
	# Manual aerial aim uses the authoritative view. Reattach after the aimed dive starts.
	if id == "sky_dive" and player._sky_dive_sub_phase == 2:
		return false
	if id == "giant_sword_ultimate" and player.giant_sword_ultimate and player.giant_sword_ultimate.aiming:
		return false
	return id in ["shield_charge", "sky_dive", "whirling_blade", "giant_sword_ultimate"]

func _follow_transform() -> Transform3D:
	var base := source.global_transform
	var reference := player.visuals.global_transform * _skeleton_reference if _skill_following() else skeleton.global_transform
	var rest_world := reference * _head_rest
	var motion := _head_world_transform() * rest_world.affine_inverse()
	var target := motion * base
	target.origin = base.origin.lerp(target.origin, head_motion_strength)
	# Follow the body's complete spin, while head position still includes its lag.
	# This avoids amplifying the fast neck/chest counter-motion at the push frame.
	var hips_rest_world := reference * _hips_rest
	var body_rotation := _hips_world.basis.orthonormalized() * hips_rest_world.basis.orthonormalized().inverse()
	target.basis = (body_rotation * base.basis.orthonormalized()) if follow_rotation else base.basis
	# In the straight sword-first pose the head's rest-facing axis is perpendicular
	# to the spine. Look down the actual spear axis rather than into the chest/sky.
	if follow_rotation and _skill_following() and player.active_ability_action.data.id == "sky_dive" and player._sky_dive_sub_phase >= 3 and player.anim_player.assigned_animation == "Knight_X_SkyDive":
		var frame: float = player.anim_player.current_animation_position * 60.0
		var weight: float = smoothstep(75.0, 84.0, frame) * (1.0 - smoothstep(120.0, 132.0, frame))
		var forward: Vector3 = player._sky_dive_direction.normalized()
		if weight > 0.0 and forward.length_squared() > 0.99:
			var up: Vector3 = player.visuals.global_basis.z if absf(forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
			target.basis = Basis(target.basis.get_rotation_quaternion().slerp(Basis.looking_at(forward, up).get_rotation_quaternion(), weight))
	return target

func _process(delta: float) -> void:
	if not is_instance_valid(render_camera) or not is_instance_valid(source) or not is_instance_valid(player):
		return
	# A cinematic can cache the current camera and reactivate it after the dash
	# already ended. Redirect that stale rendering-camera reference safely.
	if render_camera.current and not owns_camera:
		owns_camera = true
		_restore()
		return
	var interrupted: bool = player.combat_state == PlayerController.CombatState.DEAD or not player.controls_enabled or player.is_control_impaired()
	if owns_camera and (not render_camera.current or not enabled or player.is_third_person or interrupted):
		_restore()
		return
	var should_follow: bool = enabled and not player.is_third_person and not interrupted and (presentation.active or _skill_following())
	if should_follow:
		if not owns_camera:
			# Never steal a viewport from another player, spectator or cutscene.
			if not source.current:
				return
			owns_camera = true
			_entry_time = 0.0
			render_camera.global_transform = source.global_transform
			render_camera.make_current()
		returning = false
		_entry_time += delta
		var weight := clampf(_entry_time / ENTRY_DURATION, 0.0, 1.0)
		weight = weight * weight * (3.0 - 2.0 * weight)
		render_camera.global_transform = source.global_transform.interpolate_with(_follow_transform(), weight)
	elif owns_camera:
		if not returning:
			returning = true
			_return_time = 0.0
			_return_offset = source.global_transform.affine_inverse() * render_camera.global_transform
		_return_time += delta
		var weight := clampf(_return_time / maxf(return_duration, 0.001), 0.0, 1.0)
		weight = weight * weight * (3.0 - 2.0 * weight)
		render_camera.global_transform = source.global_transform * _return_offset.interpolate_with(Transform3D.IDENTITY, weight)
		if _return_time >= return_duration:
			_restore()
	if owns_camera:
		# Keep existing FOV feedback and clipping settings while this camera renders.
		render_camera.fov = source.fov
		render_camera.near = source.near
		render_camera.far = source.far
		render_camera.cull_mask = source.cull_mask
		render_camera.h_offset = source.h_offset
		render_camera.v_offset = source.v_offset

func _on_state_changed(_old: int, next: int) -> void:
	if next not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN, PlayerController.CombatState.DODGE]:
		_restore()

func _on_action_started(_slot: String, _ability: AbilityData) -> void:
	_restore()

func _restore() -> void:
	if not owns_camera:
		return
	var was_current := is_instance_valid(render_camera) and render_camera.current
	owns_camera = false
	returning = false
	if was_current:
		render_camera.clear_current(false)
		if is_instance_valid(source) and source.is_inside_tree() and is_instance_valid(player) and not player.is_queued_for_deletion():
			source.make_current()

func _exit_tree() -> void:
	_restore()
