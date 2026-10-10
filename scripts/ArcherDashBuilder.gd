extends RefCounted

## Builds stylized agile hunter dash animations for the Elf Archer rig.
## Skeleton bones:
## hips, spine, chest, neck, head, crest,
## upper_arm.L, forearm.L, hand.L (holds bow)
## upper_arm.R, forearm.R, hand.R
## thigh.L, shin.L, foot.L
## thigh.R, shin.R, foot.R

static func build_library() -> Dictionary:
	var dict := {}
	dict[&"dash_forward"] = _build_dash_forward()
	dict[&"dash_back"] = _build_dash_back()
	dict[&"dash_left"] = _build_dash_left()
	dict[&"dash_right"] = _build_dash_right()
	dict[&"dodge"] = dict[&"dash_forward"]
	return dict

static func _q_arm_l(pitch: float, yaw: float, roll: float) -> Quaternion:
	var base := Quaternion(1, 0, 0, 0)
	var delta := Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))
	return (base * delta).normalized()

static func _q_arm_r(pitch: float, yaw: float, roll: float) -> Quaternion:
	var base := Quaternion(1, 0, 0, 0)
	var delta := Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))
	return (base * delta).normalized()

static func _q_leg_l(pitch: float, yaw: float, roll: float) -> Quaternion:
	var base := Quaternion(1, 0, 0, 0)
	var delta := Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))
	return (base * delta).normalized()

static func _q_leg_r(pitch: float, yaw: float, roll: float) -> Quaternion:
	var base := Quaternion(1, 0, 0, 0)
	var delta := Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll)))
	return (base * delta).normalized()

static func _q_euler(pitch: float, yaw: float, roll: float) -> Quaternion:
	return Quaternion.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), deg_to_rad(roll))).normalized()

static func _add_pos_track(anim: Animation, path: String, times: Array, values: Array) -> void:
	var t = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(t, path)
	for i in range(times.size()):
		anim.track_insert_key(t, times[i], values[i])

static func _add_rot_track(anim: Animation, path: String, times: Array, values: Array) -> void:
	var t = anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(t, path)
	for i in range(times.size()):
		anim.track_insert_key(t, times[i], values[i])

# --- 1. DASH FORWARD: Agile low hunter dive/prowl slide ---
# Deep forward torso bend (cúi người gập về trước), low center of gravity, aerodynamic bow glide.
static func _build_dash_forward() -> Animation:
	var anim := Animation.new()
	anim.length = 0.40
	anim.loop_mode = Animation.LOOP_NONE
	var P := "Gladiator_Armature/Skeleton3D:"

	# Hips position: crouch down low and lunge forward (y: 0.94 -> 0.60, z forward: 0 -> 0.15)
	_add_pos_track(anim, P + "hips", [0.0, 0.10, 0.22, 0.34, 0.40], [
		Vector3(0, 0.94, 0),
		Vector3(0, 0.60, 0.14),
		Vector3(0, 0.66, 0.10),
		Vector3(0, 0.84, 0.03),
		Vector3(0, 0.94, 0)
	])

	# Hips & Torso: positive pitch rotates toward +Z (deep forward lean)
	_add_rot_track(anim, P + "hips", [0.0, 0.12, 0.25, 0.35, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(26, 0, 0),
		_q_euler(20, 0, 0),
		_q_euler(8, 0, 0),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "spine", [0.0, 0.12, 0.25, 0.35, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(34, 0, 0),
		_q_euler(26, 0, 0),
		_q_euler(10, 0, 0),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "chest", [0.0, 0.12, 0.25, 0.35, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(24, 0, 0),
		_q_euler(18, 0, 0),
		_q_euler(6, 0, 0),
		Quaternion.IDENTITY
	])

	# Head: tilted up relative to bent torso (-pitch) so eyes look forward
	_add_rot_track(anim, P + "head", [0.0, 0.12, 0.25, 0.35, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(-42, 0, 0),
		_q_euler(-32, 0, 0),
		_q_euler(-12, 0, 0),
		Quaternion.IDENTITY
	])

	# Left Arm (holding bow): streams naturally along the lowered flank
	_add_rot_track(anim, P + "upper_arm.L", [0.0, 0.12, 0.25, 0.40], [
		_q_arm_l(0, 0, 0),
		_q_arm_l(-22, 10, 8),
		_q_arm_l(-15, 6, 4),
		_q_arm_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "forearm.L", [0.0, 0.12, 0.25, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(25, 5, 0),
		_q_euler(12, 2, 0),
		Quaternion.IDENTITY
	])

	# Right Arm: trailed backward for balance like an agile sprinter
	_add_rot_track(anim, P + "upper_arm.R", [0.0, 0.12, 0.25, 0.40], [
		_q_arm_r(0, 0, 0),
		_q_arm_r(25, -12, -8),
		_q_arm_r(15, -6, -4),
		_q_arm_r(0, 0, 0)
	])
	_add_rot_track(anim, P + "forearm.R", [0.0, 0.12, 0.25, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(25, 0, 0),
		_q_euler(12, 0, 0),
		Quaternion.IDENTITY
	])

	# Legs: Left leg lunges forward (+pitch), right leg reaches back (-pitch)
	_add_rot_track(anim, P + "thigh.L", [0.0, 0.12, 0.25, 0.40], [
		_q_leg_l(0, 0, 0),
		_q_leg_l(35, 4, 4),
		_q_leg_l(20, 2, 2),
		_q_leg_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.L", [0.0, 0.12, 0.25, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(55, 0, 0),
		_q_euler(25, 0, 0),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "thigh.R", [0.0, 0.12, 0.25, 0.40], [
		_q_leg_r(0, 0, 0),
		_q_leg_r(-35, -4, -4),
		_q_leg_r(-18, -2, -2),
		_q_leg_r(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.R", [0.0, 0.12, 0.25, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(30, 0, 0),
		_q_euler(15, 0, 0),
		Quaternion.IDENTITY
	])

	return anim

# --- 2. DASH BACK: Acrobatic hunter evasive backflip somersault (Lộn nhào lùi) ---
# High aerial backflip vault with majestic height (~1.75m apex), airy 360-degree somersault,
# tight bow discipline, and deep athletic hunter touchdown crouch.
static func _build_dash_back() -> Animation:
	var anim := Animation.new()
	anim.length = 0.70
	anim.loop_mode = Animation.LOOP_NONE
	var P := "Gladiator_Armature/Skeleton3D:"

	# Hips Position:
	# 0.00s: 0.94 (standing)
	# 0.06s: 0.70, z=0.06 (deep spring compression crouch)
	# 0.14s: 1.25, z=-0.08 (launching upward & backward)
	# 0.22s: 1.58, z=-0.14 (rising into aerial tuck)
	# 0.30s: 1.75, z=-0.04 (APEX OF BACKFLIP: 180° upside-down float at 1.75m height!)
	# 0.40s: 1.48, z=0.08 (descending arc)
	# 0.48s: 1.05, z=0.06 (unfolding legs toward floor)
	# 0.54s: 0.62, z=0.04 (touchdown! deep athletic landing crouch)
	# 0.62s: 0.72, z=0.02 (absorbing impact, low hunter guard)
	# 0.70s: 0.94, z=0.00 (settles back to rest)
	_add_pos_track(anim, P + "hips", [
		0.00, 0.06, 0.14, 0.22, 0.30, 0.40, 0.48, 0.54, 0.62, 0.70
	], [
		Vector3(0, 0.94, 0),
		Vector3(0, 0.70, 0.06),
		Vector3(0, 1.25, -0.08),
		Vector3(0, 1.58, -0.14),
		Vector3(0, 1.75, -0.04),
		Vector3(0, 1.48, 0.08),
		Vector3(0, 1.05, 0.06),
		Vector3(0, 0.62, 0.04),
		Vector3(0, 0.72, 0.02),
		Vector3(0, 0.94, 0.00)
	])

	# Hips Rotation: Smooth monotonic 360-degree BACKFLIP around -X axis (Vector3.LEFT)
	# 0° -> 35° -> 80° -> 135° -> 180° (apex inverted at 0.30s) -> 225° -> 280° -> 335° -> 360° (forward landing lean)
	# Rotating backward around Vector3.LEFT tilts the head toward local -Z (world +Z = BACKWARD)
	var q_x_rot = func(deg: float) -> Quaternion:
		if deg <= 180.0:
			return Quaternion(Vector3.LEFT, deg_to_rad(deg)).normalized()
		else:
			return Quaternion(Vector3.LEFT, -deg_to_rad(360.0 - deg)).normalized()

	_add_rot_track(anim, P + "hips", [
		0.00, 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.42, 0.48, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(12, 0, 0),        # forward coil before launch
		q_x_rot.call(35.0),        # backward launch begins
		q_x_rot.call(80.0),        # rising backward rotation
		q_x_rot.call(135.0),       # upside-down approach
		q_x_rot.call(180.0),       # 180° upside-down at apex t=0.30s
		q_x_rot.call(225.0),       # descending rotation
		q_x_rot.call(280.0),       # feet preparing contact
		q_x_rot.call(335.0),       # almost full 360°
		_q_euler(20, 0, 0),        # 360° completes into aggressive forward landing crouch
		_q_euler(8, 0, 0),         # steadying in ready stance
		Quaternion.IDENTITY
	])

	# Spine: Coil -> mid-air aerodynamic tuck -> impact absorption crouch -> recovery
	_add_rot_track(anim, P + "spine", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(16, 0, 0),        # forward coil
		_q_euler(22, 0, 0),        # tight tuck
		_q_euler(28, 0, 0),        # apex inversion tuck
		_q_euler(12, 0, 0),        # unfolding
		_q_euler(26, 0, 0),        # touchdown crouch
		_q_euler(12, 0, 0),
		Quaternion.IDENTITY
	])

	# Chest: Compliments spine for aerodynamic somersault profile
	_add_rot_track(anim, P + "chest", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(12, 0, 0),
		_q_euler(18, 0, 0),
		_q_euler(22, 0, 0),
		_q_euler(8, 0, 0),
		_q_euler(20, 0, 0),
		_q_euler(8, 0, 0),
		Quaternion.IDENTITY
	])

	# Head: Chin tucked in somersault, eyes snap up to target downfield before touchdown!
	_add_rot_track(anim, P + "head", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(-14, 0, 0),       # eyes level during coil
		_q_euler(16, 0, 0),        # chin tucked in flight
		_q_euler(18, 0, 0),
		_q_euler(-22, 0, 0),       # early target lock-on before feet touch ground!
		_q_euler(-36, 0, 0),       # eyes fixed forward compensating for crouched torso
		_q_euler(-16, 0, 0),
		Quaternion.IDENTITY
	])

	# Left Arm: Holds bow securely across chest during roll; drives forward into guard on touchdown
	_add_rot_track(anim, P + "upper_arm.L", [
		0.00, 0.06, 0.18, 0.30, 0.44, 0.54, 0.62, 0.70
	], [
		_q_arm_l(0, 0, 0),
		_q_arm_l(-20, 15, 10),
		_q_arm_l(-35, 25, 20),     # bow tucked diagonally across chest
		_q_arm_l(-35, 25, 20),
		_q_arm_l(-10, 15, 10),
		_q_arm_l(18, 6, 6),        # pushes forward into low hunter bow guard
		_q_arm_l(8, 3, 2),
		_q_arm_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "forearm.L", [
		0.00, 0.06, 0.18, 0.30, 0.44, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(45, 10, 0),
		_q_euler(70, 15, 0),       # compact arm tuck
		_q_euler(70, 15, 0),
		_q_euler(45, 10, 0),
		_q_euler(36, 8, 0),        # ready aim
		_q_euler(18, 4, 0),
		Quaternion.IDENTITY
	])

	# Right Arm: Drawing hand tucked near chest in flight; poised near quiver at hip on landing
	_add_rot_track(anim, P + "upper_arm.R", [
		0.00, 0.06, 0.18, 0.30, 0.44, 0.54, 0.62, 0.70
	], [
		_q_arm_r(0, 0, 0),
		_q_arm_r(-22, -15, -10),
		_q_arm_r(-36, -20, -15),   # compact tuck to prevent flailing
		_q_arm_r(-36, -20, -15),
		_q_arm_r(-20, -12, -8),
		_q_arm_r(-18, -12, -8),    # hand poised near quiver hip for fast draw
		_q_arm_r(-8, -6, -4),
		_q_arm_r(0, 0, 0)
	])
	_add_rot_track(anim, P + "forearm.R", [
		0.00, 0.06, 0.18, 0.30, 0.44, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(50, -10, 0),
		_q_euler(75, -12, 0),
		_q_euler(75, -12, 0),
		_q_euler(45, -10, 0),
		_q_euler(36, -8, 0),
		_q_euler(18, -4, 0),
		Quaternion.IDENTITY
	])

	# Legs: Deep coil -> Knees tucked high in aerial somersault -> Staggered hunter landing
	_add_rot_track(anim, P + "thigh.L", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		_q_leg_l(0, 0, 0),
		_q_leg_l(38, 4, 4),
		_q_leg_l(75, 6, 4),        # aerial somersault knee tuck forward
		_q_leg_l(88, 8, 4),        # apex maximum tuck
		_q_leg_l(22, 4, 2),        # opening tuck to catch the ground
		_q_leg_l(52, 6, 4),        # landing crouch (left leg forward)
		_q_leg_l(24, 3, 2),
		_q_leg_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.L", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(55, 0, 0),
		_q_euler(95, 0, 0),        # high shin flex behind thigh
		_q_euler(115, 0, 0),
		_q_euler(30, 0, 0),
		_q_euler(72, 0, 0),        # landing knee flexion
		_q_euler(35, 0, 0),
		Quaternion.IDENTITY
	])

	_add_rot_track(anim, P + "thigh.R", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		_q_leg_r(0, 0, 0),
		_q_leg_r(40, -4, -4),
		_q_leg_r(68, -6, -4),       # slightly staggered tuck
		_q_leg_r(80, -8, -4),
		_q_leg_r(18, -4, -2),
		_q_leg_r(40, -6, -4),       # right leg back in hunter landing
		_q_leg_r(18, -3, -2),
		_q_leg_r(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.R", [
		0.00, 0.06, 0.18, 0.30, 0.42, 0.54, 0.62, 0.70
	], [
		Quaternion.IDENTITY,
		_q_euler(60, 0, 0),
		_q_euler(90, 0, 0),
		_q_euler(108, 0, 0),
		_q_euler(25, 0, 0),
		_q_euler(62, 0, 0),
		_q_euler(28, 0, 0),
		Quaternion.IDENTITY
	])

	return anim

# --- 3. DASH LEFT: Nimble sidestep weave & evasive roll hop (Leans LEFT) ---
static func _build_dash_left() -> Animation:
	var anim := Animation.new()
	anim.length = 0.40
	anim.loop_mode = Animation.LOOP_NONE
	var P := "Gladiator_Armature/Skeleton3D:"

	# Local +X is World -X (LEFT). Move hips left: +0.07m
	_add_pos_track(anim, P + "hips", [0.0, 0.12, 0.24, 0.40], [
		Vector3(0, 0.94, 0),
		Vector3(0.07, 0.78, 0),
		Vector3(0.03, 0.86, 0),
		Vector3(0, 0.94, 0)
	])
	# Leans LEFT (negative roll in local space tilts to local +X = world -X left)
	_add_rot_track(anim, P + "hips", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(-8, -12, -18),
		_q_euler(-4, -6, -9),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "spine", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(-6, -8, -14),
		_q_euler(-2, -4, -6),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "chest", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(0, -6, -10),
		_q_euler(0, -3, -4),
		Quaternion.IDENTITY
	])

	# Bow held steady on left flank, right arm balances outward
	_add_rot_track(anim, P + "upper_arm.L", [0.0, 0.12, 0.24, 0.40], [
		_q_arm_l(0, 0, 0),
		_q_arm_l(-20, 18, 20),
		_q_arm_l(-10, 10, 10),
		_q_arm_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "upper_arm.R", [0.0, 0.12, 0.24, 0.40], [
		_q_arm_r(0, 0, 0),
		_q_arm_r(15, -20, -15),
		_q_arm_r(8, -10, -8),
		_q_arm_r(0, 0, 0)
	])

	# Left leg steps out to the left (lead leg), right leg follows
	_add_rot_track(anim, P + "thigh.L", [0.0, 0.12, 0.24, 0.40], [
		_q_leg_l(0, 0, 0),
		_q_leg_l(-25, 15, 20),
		_q_leg_l(-12, 8, 10),
		_q_leg_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.L", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(35, 0, 0),
		_q_euler(18, 0, 0),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "thigh.R", [0.0, 0.12, 0.24, 0.40], [
		_q_leg_r(0, 0, 0),
		_q_leg_r(15, -10, -15),
		_q_leg_r(8, -5, -8),
		_q_leg_r(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.R", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(28, 0, 0),
		_q_euler(12, 0, 0),
		Quaternion.IDENTITY
	])

	return anim

# --- 4. DASH RIGHT: Nimble sidestep weave & evasive roll hop (Leans RIGHT) ---
static func _build_dash_right() -> Animation:
	var anim := Animation.new()
	anim.length = 0.40
	anim.loop_mode = Animation.LOOP_NONE
	var P := "Gladiator_Armature/Skeleton3D:"

	# Local -X is World +X (RIGHT). Move hips right: -0.07m
	_add_pos_track(anim, P + "hips", [0.0, 0.12, 0.24, 0.40], [
		Vector3(0, 0.94, 0),
		Vector3(-0.07, 0.78, 0),
		Vector3(-0.03, 0.86, 0),
		Vector3(0, 0.94, 0)
	])
	# Leans RIGHT (positive roll in local space tilts to local -X = world +X right)
	_add_rot_track(anim, P + "hips", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(-8, 12, 18),
		_q_euler(-4, 6, 9),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "spine", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(-6, 8, 14),
		_q_euler(-2, 4, 6),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "chest", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(0, 6, 10),
		_q_euler(0, 3, 4),
		Quaternion.IDENTITY
	])

	# Bow held steady on flank, left arm counter-balances
	_add_rot_track(anim, P + "upper_arm.L", [0.0, 0.12, 0.24, 0.40], [
		_q_arm_l(0, 0, 0),
		_q_arm_l(-15, 20, 15),
		_q_arm_l(-8, 10, 8),
		_q_arm_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "upper_arm.R", [0.0, 0.12, 0.24, 0.40], [
		_q_arm_r(0, 0, 0),
		_q_arm_r(20, -18, -20),
		_q_arm_r(10, -10, -10),
		_q_arm_r(0, 0, 0)
	])

	# Right leg steps out to the right (lead leg), left leg follows
	_add_rot_track(anim, P + "thigh.R", [0.0, 0.12, 0.24, 0.40], [
		_q_leg_r(0, 0, 0),
		_q_leg_r(-25, -15, -20),
		_q_leg_r(-12, -8, -10),
		_q_leg_r(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.R", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(35, 0, 0),
		_q_euler(18, 0, 0),
		Quaternion.IDENTITY
	])
	_add_rot_track(anim, P + "thigh.L", [0.0, 0.12, 0.24, 0.40], [
		_q_leg_l(0, 0, 0),
		_q_leg_l(15, 10, 15),
		_q_leg_l(8, 5, 8),
		_q_leg_l(0, 0, 0)
	])
	_add_rot_track(anim, P + "shin.L", [0.0, 0.12, 0.24, 0.40], [
		Quaternion.IDENTITY,
		_q_euler(28, 0, 0),
		_q_euler(12, 0, 0),
		Quaternion.IDENTITY
	])

	return anim
