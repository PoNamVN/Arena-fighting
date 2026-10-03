extends SceneTree


func _initialize() -> void:
	var source: Node = load("res://assets/models/knight_v_giant_sword.glb").instantiate()
	var target: Node = load("res://assets/models/player_character.glb").instantiate()
	var source_skeleton: Skeleton3D = source.find_child("Skeleton3D", true, false) as Skeleton3D
	var target_skeleton: Skeleton3D = target.find_child("Skeleton3D", true, false) as Skeleton3D
	for index: int in range(target_skeleton.get_bone_count()):
		var source_index: int = source_skeleton.find_bone(target_skeleton.get_bone_name(index))
		if source_index < 0 or not target_skeleton.get_bone_rest(index).is_equal_approx(source_skeleton.get_bone_rest(source_index)):
			push_error("V source rig differs at bone " + target_skeleton.get_bone_name(index))
			quit(1)
			return
	var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var animation: Animation = player.get_animation("Animation").duplicate(true) as Animation
	animation.resource_name = "Knight_V_GiantSword"
	animation.loop_mode = Animation.LOOP_NONE
	# Retain authored rest-pose tracks to clear attack/block leftovers, while
	# allowing the existing FPS head/neck scale mask to keep ownership of scale.
	for track: int in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track)
	for track: int in range(animation.get_track_count()):
		var path: NodePath = animation.track_get_path(track)
		if target.get_node_or_null(NodePath(path.get_concatenated_names())) == null:
			push_error("Unresolved V animation track: " + str(path))
			quit(1)
			return
	DirAccess.make_dir_recursive_absolute("res://assets/animations")
	var result: Error = ResourceSaver.save(animation, "res://assets/animations/knight_v_giant_sword.tres")
	print("V animation extraction: error=%d, length=%.3f, tracks=%d" % [result, animation.length, animation.get_track_count()])
	source.free()
	target.free()
	quit(0 if result == OK else 1)
