class_name ArcherCapePhysics
extends Node

## Procedural Floating Spring & Wind Physics for Archer Cape
## Simulates aerodynamic drag, inertia velocity tilt, and soft harmonic floating breeze.

var actor: PlayerController = null
var _skeleton: Skeleton3D = null
var _cape_bone_ids: Array[int] = []

var _time: float = 0.0
var _current_pitch: Array[float] = [0.0, 0.0, 0.0]
var _current_roll: Array[float] = [0.0, 0.0, 0.0]
var _current_yaw: Array[float] = [0.0, 0.0, 0.0]

func setup(player_actor: PlayerController) -> void:
	actor = player_actor
	_find_skeleton()

func _find_skeleton() -> void:
	if not actor or not actor.visuals:
		return
	_skeleton = actor.visuals.find_child("GeneralSkeleton", true, false) as Skeleton3D
	if not _skeleton:
		_skeleton = actor.visuals.find_child("*Skeleton*", true, false) as Skeleton3D
	if not _skeleton:
		for child: Node in actor.visuals.get_children():
			if child is Skeleton3D:
				_skeleton = child
				break
			for sub: Node in child.get_children():
				if sub is Skeleton3D:
					_skeleton = sub
					break

	if _skeleton:
		_cape_bone_ids.clear()
		for b_name: String in ["cape.01", "cape.02", "cape.03"]:
			var id: int = _skeleton.find_bone(b_name)
			if id != -1:
				_cape_bone_ids.append(id)

func apply_archer_look() -> void:
	if actor and actor.has_method("apply_archer_look"):
		actor.apply_archer_look()

func update_cape(delta: float) -> void:
	if actor and actor.has_method("update_cape"):
		actor.update_cape(delta)

func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	if not _skeleton or _cape_bone_ids.is_empty():
		_find_skeleton()
		if not _skeleton or _cape_bone_ids.is_empty():
			return

	_time += delta
	var velocity: Vector3 = actor.velocity
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var speed_ratio: float = clampf(speed / 8.0, 0.0, 1.0)

	# Local movement direction relative to character facing
	var local_vel: Vector3 = actor.visuals.global_transform.basis.inverse() * velocity
	var forward_ratio: float = clampf(local_vel.z / 7.0, -1.0, 1.0)
	var strafe_ratio: float = clampf(local_vel.x / 7.0, -1.0, 1.0)

	# Cape flap & soft float wave
	for i: int in range(_cape_bone_ids.size()):
		var bone_id: int = _cape_bone_ids[i]
		var depth_factor: float = float(i + 1) / float(_cape_bone_ids.size())

		# 1. Harmonic Idle Floating Breeze (Lơ lửng nhẹ khi đứng yên hoặc di chuyển)
		var idle_breeze: float = sin(_time * 3.2 + float(i) * 1.3) * deg_to_rad(6.0) * (1.0 + depth_factor * 0.8)
		var idle_sway: float = cos(_time * 2.4 + float(i) * 1.1) * deg_to_rad(3.5) * depth_factor

		# 2. Aerodynamic Movement Drag (Bay vểnh ra sau theo quán tính khi chạy tới)
		var target_pitch: float = idle_breeze + (forward_ratio * deg_to_rad(38.0) * depth_factor)
		var target_roll: float = idle_sway - (strafe_ratio * deg_to_rad(22.0) * depth_factor)
		var target_yaw: float = sin(_time * 4.5 + float(i)) * deg_to_rad(4.0) * speed_ratio

		# If falling or jumping, cape floats upwards
		if velocity.y < -1.0:
			target_pitch += deg_to_rad(28.0) * depth_factor
		elif velocity.y > 1.0:
			target_pitch -= deg_to_rad(15.0) * depth_factor

		# 3. Smooth Spring Damping
		_current_pitch[i] = lerpf(_current_pitch[i], target_pitch, minf(1.0, delta * 9.0))
		_current_roll[i] = lerpf(_current_roll[i], target_roll, minf(1.0, delta * 9.0))
		_current_yaw[i] = lerpf(_current_yaw[i], target_yaw, minf(1.0, delta * 9.0))

		var sway_rot: Basis = Basis.from_euler(Vector3(_current_pitch[i], _current_yaw[i], _current_roll[i]))
		var rest_pose: Transform3D = _skeleton.get_bone_rest(bone_id)
		var final_rot: Quaternion = (rest_pose.basis * sway_rot).get_rotation_quaternion()
		_skeleton.set_bone_pose_rotation(bone_id, final_rot)
