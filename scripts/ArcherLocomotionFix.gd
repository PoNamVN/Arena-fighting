extends RefCounted
class_name ArcherLocomotionFix

## Corrects bone track rotations in Archer animations (e.g. inverted elbow bend in run).
## Duplicates the animation in-memory so shared resources and .glb files on disk are never altered.

static func apply(player: AnimationPlayer) -> void:
	if not player or not player.has_animation_library(""):
		return
	var library: AnimationLibrary = player.get_animation_library("")
	if library.has_meta("archer_locomotion_fixed"):
		return
	library.set_meta("archer_locomotion_fixed", true)

	if library.has_animation("run"):
		var orig_run: Animation = library.get_animation("run")
		var fixed_run: Animation = _fix_arm_animation(orig_run, true)
		library.remove_animation("run")
		library.add_animation("run", fixed_run)

	if library.has_animation("idle"):
		var orig_idle: Animation = library.get_animation("idle")
		var fixed_idle: Animation = _fix_arm_animation(orig_idle, false)
		library.remove_animation("idle")
		library.add_animation("idle", fixed_idle)

static func _fix_arm_animation(source: Animation, is_run: bool = false) -> Animation:
	var anim: Animation = source.duplicate()
	for t in anim.get_track_count():
		var path_str: String = str(anim.track_get_path(t))
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			# Target forearm tracks where positive X rotation bent elbows backwards
			if path_str.ends_with("forearm.L") or path_str.ends_with("forearm.R"):
				for k in anim.track_get_key_count(t):
					var q: Quaternion = anim.track_get_key_value(t, k)
					# Invert X rotation component so elbows bend forward naturally
					var fixed_q := Quaternion(-q.x, q.y, q.z, q.w)
					anim.track_set_key_value(t, k, fixed_q)
			# In run animation, stabilize left upper arm so bow-carrying hand stays forward and clear of cape
			elif is_run and path_str.ends_with("upper_arm.L"):
				for k in anim.track_get_key_count(t):
					var q: Quaternion = anim.track_get_key_value(t, k)
					var euler: Vector3 = q.get_euler()
					if euler.x > -0.15:
						euler.x = -0.15
						var fixed_q := Quaternion.from_euler(euler)
						anim.track_set_key_value(t, k, fixed_q)
	return anim
