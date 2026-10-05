@tool
extends EditorScenePostImport

## Bake the new dash clips at 60 fps while preserving the existing K3 tracks.
func _post_import(scene: Node) -> Object:
	var previous: PackedScene = load("res://assets/models/knight_k3.glb")
	if not previous:
		push_error("Knight dash import requires the preserved knight_k3.glb")
		return scene
	var old_model := previous.instantiate()
	var old_player: AnimationPlayer = old_model.get_node("AnimationPlayer")
	var new_player: AnimationPlayer = scene.get_node("AnimationPlayer")
	var library := new_player.get_animation_library("")
	for clip in old_player.get_animation_list():
		if library.has_animation(clip):
			library.remove_animation(clip)
		library.add_animation(clip, old_player.get_animation(clip).duplicate(true))
	old_model.free()
	return scene
