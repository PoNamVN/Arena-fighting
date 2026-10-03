extends SceneTree

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _assert(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("[PASS] " + label)
	else:
		failed += 1
		push_error("[FAIL] " + label)


func _arena_mesh_count(node: Node) -> int:
	var count: int = 1 if node is MeshInstance3D and str(node.name).begins_with("Arena_") else 0
	for child: Node in node.get_children():
		count += _arena_mesh_count(child)
	return count


func _run() -> void:
	var character: Node = load("res://assets/models/player_character.glb").instantiate()
	_assert(_arena_mesh_count(character) == 0, "Imported character contains no arena meshes")
	var skeleton: Skeleton3D = character.find_child("Skeleton3D", true, false) as Skeleton3D
	_assert(skeleton != null and skeleton.get_bone_count() == 18, "Character retains its 18-bone rig")
	var body: MeshInstance3D = character.find_child("Gladiator_Mesh", true, false) as MeshInstance3D
	_assert(body != null and body.mesh != null and body.skin != null and body.skin.get_bind_count() == 18, "Character mesh remains skinned to its 18 bones")
	var animation_player: AnimationPlayer = character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for animation: String in ["idle", "run", "attack", "block", "block_start", "block_hold", "block_release", "dead", "Knight_X_SkyDive"]:
		_assert(animation_player != null and animation_player.has_animation(animation), "Animation preserved: " + animation)
	character.free()
	var main_scene: PackedScene = load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var arena: Node3D = main_scene.instantiate() as Node3D
	root.add_child(arena)
	await physics_frame
	await process_frame
	var player: PlayerController = arena.get_node("Player") as PlayerController
	_assert(_arena_mesh_count(player) == 0, "Player hierarchy contains no duplicated arena")
	_assert(_arena_mesh_count(arena) == 42, "Main map has exactly one set of 42 arena meshes")
	var floor_mesh: MeshInstance3D = arena.get_node("ArenaVisualModel").find_child("Arena_Floor", true, false) as MeshInstance3D
	var floor_transform: Transform3D = floor_mesh.global_transform
	var start_position: Vector3 = player.global_position
	Input.action_press("move_right")
	for frame: int in range(12):
		await physics_frame
		await process_frame
	Input.action_release("move_right")
	_assert(player.global_position.distance_to(start_position) > 0.2, "Player genuinely moves through physics frames")
	player._camera_yaw = 0.8
	player._update_camera_rotation()
	await physics_frame
	await process_frame
	_assert(floor_mesh.global_transform.is_equal_approx(floor_transform), "Map stays fixed when player moves and turns")
	_assert(_arena_mesh_count(arena) == 42 and _arena_mesh_count(player) == 0, "Movement creates no extra arena copies")
	print("RESULTS: %d / %d PASSED (%d FAILED)" % [passed, passed + failed, failed])
	quit(1 if failed > 0 else 0)
