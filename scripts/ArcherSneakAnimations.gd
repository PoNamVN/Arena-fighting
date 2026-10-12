extends RefCounted

const CYCLE_SECONDS := 1.0
const STRIDE := .54
const STANCE := .56
const NOMINAL_SPEED := STRIDE / (CYCLE_SECONDS * STANCE)
const MAX_RATE := 2.4
const HIP_HEIGHT := .775
const HIP_BACK := -.11
const FOOT_LIFT := .05

static func build(skeleton: Skeleton3D, path: String, walking: bool) -> Animation:
	var clip := Animation.new()
	clip.length = CYCLE_SECONDS if walking else 4.0
	clip.loop_mode = Animation.LOOP_LINEAR
	var rotations: Dictionary = {}
	for index in range(skeleton.get_bone_count()):
		var name := skeleton.get_bone_name(index)
		if name == "root": continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(path + name))
		rotations[name] = track
	var position := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(position, NodePath(path + "hips"))
	for frame in range(65):
		var t := float(frame) / 64
		var poses := pose(skeleton, t, walking)
		for name: String in rotations:
			clip.track_insert_key(rotations[name], clip.length * t, (poses[name] as Basis).get_rotation_quaternion())
		clip.track_insert_key(position, clip.length * t, poses.hip_position)
	return clip

static func pose(skeleton: Skeleton3D, t: float, walking: bool) -> Dictionary:
	var result: Dictionary = {}
	for index in range(skeleton.get_bone_count()):
		result[skeleton.get_bone_name(index)] = skeleton.get_bone_rest(index).basis
	var sway := sin(t * TAU) if walking else 0.0
	var breathe := sin(t * TAU) * .004
	# Predator silhouette: one hand carries the bow behind the hip, the other
	# reaches ahead; the eyes stay level above a low, forward-leaning torso.
	var hip := Vector3(sway * -.030, HIP_HEIGHT + (cos(t * TAU * 2) * .010 if walking else breathe), HIP_BACK)
	var hip_basis := Basis.from_euler(Vector3(.14, .12 + sway * .035, sway * .020))
	result.hips = hip_basis
	result.hip_position = hip
	result.spine = Basis.from_euler(Vector3(.27, .06 - sway * .020, 0))
	result.chest = Basis.from_euler(Vector3(.33, .05 - sway * .015, 0))
	result.neck = Basis.from_euler(Vector3(-.42, -.10, 0))
	result.head = Basis.from_euler(Vector3(-.28, -.13 + (sin(t * TAU) * .10 if not walking else 0.0), 0))
	var chest := hip_basis * (result.spine as Basis) * (result.chest as Basis)
	for side: String in ["L", "R"]:
		var sign_side := 1.0 if side == "L" else -1.0
		var phase := fposmod(t + (0.0 if side == "L" else .5), 1.0)
		# Narrow foot lanes and a staggered ready stance avoid the old duck walk.
		var ankle := Vector3(sign_side * .14, .12, .03 if walking else (.18 if side == "L" else -.14))
		var toe_angle := 0.0
		if walking:
			if phase < STANCE:
				var contact := phase / STANCE
				ankle.z += STRIDE * (.5 - contact)
				toe_angle = -.035 * sin(contact * PI)
			else:
				var swing := (phase - STANCE) / (1.0 - STANCE)
				# Match horizontal velocity at toe-off and contact, avoiding a jerk
				# between the planted segment and the returning foot.
				var endpoint_speed := -(1.0 - STANCE) / STANCE
				var return_path := smoothstep(0, 1, swing) + endpoint_speed * swing * (1 - swing) * (1 - 2 * swing)
				ankle.z += STRIDE * (return_path - .5)
				ankle.y += FOOT_LIFT * pow(sin(swing * PI), 2)
				toe_angle = .055 * sin(swing * PI)
		var thigh_index := skeleton.find_bone("thigh." + side)
		var shin_index := skeleton.find_bone("shin." + side)
		var foot_index := skeleton.find_bone("foot." + side)
		var thigh_rest := skeleton.get_bone_rest(thigh_index)
		var shin_rest := skeleton.get_bone_rest(shin_index)
		var foot_rest := skeleton.get_bone_rest(foot_index)
		var socket := hip + hip_basis * thigh_rest.origin
		var upper_length := shin_rest.origin.length()
		var lower_length := foot_rest.origin.length()
		var reach := ankle - socket
		var distance := clampf(reach.length(), .05, upper_length + lower_length - .003)
		var axis := reach.normalized()
		var hint := Vector3(sign_side * .012, 0, 1)
		var bend := (hint - axis * hint.dot(axis)).normalized()
		var along := (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2 * distance)
		var knee := socket + axis * along + bend * sqrt(maxf(0, upper_length * upper_length - along * along))
		var upper_rest_global := skeleton.get_bone_global_rest(thigh_index).basis
		var lower_rest_global := skeleton.get_bone_global_rest(shin_index).basis
		var upper_global := Basis(Quaternion(upper_rest_global.y.normalized(), (knee - socket).normalized())) * upper_rest_global
		var lower_global := Basis(Quaternion(lower_rest_global.y.normalized(), (ankle - knee).normalized())) * lower_rest_global
		result["thigh." + side] = hip_basis.inverse() * upper_global
		result["shin." + side] = upper_global.inverse() * lower_global
		# Keep soles level instead of inheriting knee rotation into the ankle.
		result["foot." + side] = lower_global.inverse() * Basis(Vector3.RIGHT, toe_angle) * skeleton.get_bone_global_rest(foot_index).basis
		# Independently solve the trailing bow arm and the forward scouting arm.
		var spine_origin := hip + hip_basis * skeleton.get_bone_rest(skeleton.find_bone("spine")).origin
		var chest_origin := spine_origin + hip_basis * (result.spine as Basis) * skeleton.get_bone_rest(skeleton.find_bone("chest")).origin
		var upper_index := skeleton.find_bone("upper_arm." + side)
		var fore_index := skeleton.find_bone("forearm." + side)
		var hand_index := skeleton.find_bone("hand." + side)
		var shoulder := chest_origin + chest * skeleton.get_bone_rest(upper_index).origin
		var grip := hip + Vector3(.42, .31, -.22) if side == "L" else hip + Vector3(-.27, .30 + sway * .014, .57 + sway * .018)
		grip.y += breathe
		var reach_arm := grip - shoulder
		var upper_arm_length := skeleton.get_bone_rest(fore_index).origin.length()
		var forearm_length := skeleton.get_bone_rest(hand_index).origin.length()
		var arm_distance := clampf(reach_arm.length(), .05, upper_arm_length + forearm_length - .003)
		var arm_axis := reach_arm.normalized()
		var elbow_hint := Vector3(sign_side, -.8, -.45 if side == "L" else .05)
		var elbow_bend := (elbow_hint - arm_axis * elbow_hint.dot(arm_axis)).normalized()
		var arm_along := (upper_arm_length * upper_arm_length - forearm_length * forearm_length + arm_distance * arm_distance) / (2 * arm_distance)
		var elbow := shoulder + arm_axis * arm_along + elbow_bend * sqrt(maxf(0, upper_arm_length * upper_arm_length - arm_along * arm_along))
		var upper_arm_rest := skeleton.get_bone_global_rest(upper_index).basis
		var forearm_rest := skeleton.get_bone_global_rest(fore_index).basis
		var upper_arm_global := Basis(Quaternion(upper_arm_rest.y.normalized(), (elbow - shoulder).normalized())) * upper_arm_rest
		var forearm_global := Basis(Quaternion(forearm_rest.y.normalized(), (grip - elbow).normalized())) * forearm_rest
		result["upper_arm." + side] = chest.inverse() * upper_arm_global
		result["forearm." + side] = upper_arm_global.inverse() * forearm_global
		# Cant the bow behind the left flank, away from the cape. The free palm
		# faces down with a relaxed wrist, like a hunter feeling the way ahead.
		var grip_basis := Basis.from_euler(Vector3(-.45, .15, -.50)) * Basis.from_euler(Vector3(-.35, .05, 2.95)).inverse() if side == "L" else Basis.from_euler(Vector3(PI * .55, -.10, -.10))
		result["hand." + side] = forearm_global.inverse() * grip_basis
	return result
