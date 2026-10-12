extends RefCounted

## The imported pants are rigid boxes with the same 60/40 leg weights at every
## vertex. Add knee rings and anatomical weights without altering the GLB.
static func apply(actor: PlayerController) -> void:
	for side: String in ["L", "R"]:
		var node := actor.visuals.find_child("Leg_" + side, true, false) as MeshInstance3D
		if not node or not node.mesh or not node.skin or node.has_meta("forest_leg_skin_fixed"): continue
		var thigh := -1
		var shin := -1
		for bind in range(node.skin.get_bind_count()):
			if node.skin.get_bind_name(bind) == "thigh." + side: thigh = bind
			if node.skin.get_bind_name(bind) == "shin." + side: shin = bind
		if thigh < 0 or shin < 0: continue
		var source := node.mesh
		var surface_override := node.get_surface_override_material(0)
		var bounds := source.get_aabb()
		var knee := actor._skeleton.get_bone_global_rest(actor._skeleton.find_bone("shin." + side)).origin.y
		var heights: Array[float] = [bounds.position.y, knee - .08, knee, knee + .08, bounds.end.y]
		var corners: Array[Vector2] = [Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.end.x, bounds.position.z), Vector2(bounds.end.x, bounds.end.z), Vector2(bounds.position.x, bounds.end.z)]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var bones := PackedInt32Array()
		var weights := PackedFloat32Array()
		var indices := PackedInt32Array()
		for face in range(4):
			var a := corners[face]
			var b := corners[(face + 1) % 4]
			var normal := Vector3(b.y - a.y, 0, a.x - b.x).normalized()
			var start := vertices.size()
			for height in heights:
				for point: Vector2 in [a, b]:
					append_vertex(Vector3(point.x, height, point.y), normal, Vector2(0 if point == a else 1, inverse_lerp(bounds.position.y, bounds.end.y, height)), knee, thigh, shin, vertices, normals, uvs, bones, weights)
			for row in range(heights.size() - 1):
				var base := start + row * 2
				indices.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3]))
		for top in [false, true]:
			var start := vertices.size()
			var height := bounds.end.y if top else bounds.position.y
			for point in corners:
				append_vertex(Vector3(point.x, height, point.y), Vector3.UP if top else Vector3.DOWN, Vector2.ZERO, knee, thigh, shin, vertices, normals, uvs, bones, weights)
			indices.append_array(PackedInt32Array([start, start + 2, start + 1, start, start + 3, start + 2]) if top else PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
		var arrays: Array = []
		# Godot renders clockwise front faces; keep winding aligned with normals.
		for triangle in range(0, indices.size(), 3):
			var second := indices[triangle + 1]
			indices[triangle + 1] = indices[triangle + 2]
			indices[triangle + 2] = second
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		# The original uses a flat material and has no UV channel.
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(0, source.surface_get_material(0))
		node.mesh = mesh
		# Mesh replacement can reset surface overrides; retain the actor's toon look.
		node.set_surface_override_material(0, surface_override)
		node.set_meta("forest_leg_skin_fixed", true)

static func append_vertex(point: Vector3, normal: Vector3, uv: Vector2, knee: float, thigh: int, shin: int, vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	vertices.append(point)
	normals.append(normal)
	uvs.append(uv)
	var upper := smoothstep(knee - .08, knee + .08, point.y)
	bones.append_array(PackedInt32Array([thigh, shin, 0, 0]))
	weights.append_array(PackedFloat32Array([upper, 1.0 - upper, 0, 0]))
