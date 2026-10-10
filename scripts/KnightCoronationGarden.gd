extends Node3D
## Reusable vegetation, sampled from the actual Blender rock triangles.
var batches: Array[MultiMesh] = []
var materials: Array[ShaderMaterial] = []
var locations: Array[Array] = []
var surface_samples: Array[Vector3] = []
var growth: float = 0.0
var _triangles: Array[Array] = []
var _area: float = 0.0

func build(rock: Node3D) -> void:
	for mesh: MeshInstance3D in rock.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = rock.global_transform.affine_inverse() * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in vertices.size(): indices.append(i)
			for i in range(0, indices.size(), 3):
				var a: Vector3 = local * vertices[indices[i]]
				var b: Vector3 = local * vertices[indices[i + 1]]
				var c: Vector3 = local * vertices[indices[i + 2]]
				var cross: Vector3 = (b - a).cross(c - a)
				var normal: Vector3 = cross.normalized()
				if normal.dot((a + b + c) / 3.0 - Vector3.UP * 4.0) < 0: normal = -normal
				if normal.y < .18: continue
				_area += cross.length() * .5
				_triangles.append([a, b, c, normal, _area])
	var random := RandomNumberGenerator.new(); random.seed = 3841
	for kind in 2:
		var instance := MultiMeshInstance3D.new()
		var batch := MultiMesh.new(); batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true; batch.use_custom_data = true
		batch.mesh = _plant_mesh(kind == 1); batch.instance_count = 480 if kind == 0 else 96
		var material := ShaderMaterial.new(); material.shader = preload("res://assets/shaders/knight_coronation_flora.gdshader")
		instance.multimesh = batch; instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance); batches.append(batch); materials.append(material)
		var positions: Array = []
		for i in batch.instance_count:
			var point: Vector3
			var normal: Vector3 = Vector3.UP
			var on_rock: bool = i % 3 == 0 and not _triangles.is_empty()
			if on_rock:
				var choice: float = random.randf() * _area
				var triangle: Array = _triangles.back()
				for candidate in _triangles:
					if choice <= candidate[4]: triangle = candidate; break
				var u: float = sqrt(random.randf()); var v: float = random.randf()
				point = triangle[0] * (1.0 - u) + triangle[1] * u * (1.0 - v) + triangle[2] * u * v
				normal = triangle[3]
				surface_samples.append(point)
				point += Vector3.DOWN * .35 + normal * .025
			else:
				var angle: float = i * 2.3999632
				var radius: float = 1.08 + pow(random.randf(), .7) * .60
				point = Vector3(cos(angle) * 6.8 * radius, .035, sin(angle) * 5.7 * radius)
			var up: Vector3 = normal.lerp(Vector3.UP, .35).normalized()
			var tangent: Vector3 = up.cross(Vector3.FORWARD).normalized()
			var basis := Basis(tangent, up, tangent.cross(up)).rotated(up, random.randf() * TAU)
			var size: float = random.randf_range(.65, 1.35) if kind == 0 else random.randf_range(.85, 1.45)
			batch.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * size), point))
			batch.set_instance_color(i, Color.WHITE.darkened(random.randf_range(0, .18)))
			var delay: float = clampf(point.y / 12.0, 0.0, .55) + random.randf_range(0, .15)
			batch.set_instance_custom_data(i, Color(delay, random.randf(), 1, kind))
			positions.append([point, on_rock, delay])
		locations.append(positions)
	stop()

func begin(origin: Vector3, vfx: GiantSwordVFX) -> void:
	var manager := get_node_or_null("/root/VFXManager")
	var quality: int = manager.quality if manager else 1
	var minimum: Vector2 = vfx._crack_material.get_shader_parameter("arena_min")
	var maximum: Vector2 = vfx._crack_material.get_shader_parameter("arena_max")
	for kind in batches.size():
		batches[kind].visible_instance_count = ([160, 320, 480] if kind == 0 else [36, 64, 96])[quality]
		for i in batches[kind].instance_count:
			var world: Vector3 = origin + locations[kind][i][0]
			var inside: bool = locations[kind][i][1] or (world.x > minimum.x and world.x < maximum.x and world.z > minimum.y and world.z < maximum.y)
			if not locations[kind][i][1]:
				for plane in vfx._floor_planes:
					inside = inside and Vector3(plane.x, plane.y, plane.z).dot(world) < plane.w - .1
			var custom: Color = batches[kind].get_instance_custom_data(i)
			custom.b = 1.0 if inside else 0.0
			batches[kind].set_instance_custom_data(i, custom)
	show(); update_growth(0.0, 0.0)

func update_growth(value: float, time: float) -> void:
	growth = value
	for material in materials:
		material.set_shader_parameter("growth", value)
		material.set_shader_parameter("flow", time)

func stop() -> void:
	hide(); growth = 0.0
	for batch in batches: batch.visible_instance_count = 0
	for material in materials: material.set_shader_parameter("growth", 0.0)

func _plant_mesh(flower: bool) -> ArrayMesh:
	var vertices := PackedVector3Array(); var colors := PackedColorArray(); var normals := PackedVector3Array()
	if flower:
		for side in 2:
			var axis := Vector3.RIGHT if side == 0 else Vector3.BACK
			_face(vertices, colors, normals, -axis * .025, axis * .025, Vector3.UP * .9, Color(.12,.27,.07), Color(.2,.37,.10))
		for petal in 6:
			var angle: float = petal * TAU / 6.0
			var radial := Vector3(cos(angle), 0, sin(angle)); var side := Vector3(-sin(angle),0,cos(angle))
			var center := Vector3.UP * .9
			var tip: Vector3 = center + radial * .35 + Vector3.UP * .07
			_face(vertices, colors, normals, center, tip + side * .14, tip - side * .14, Color(.95,.69,.78), Color(1,.90,.94))
			_face(vertices, colors, normals, center, center + radial * .11 + side * .10, center + radial * .11 - side * .10, Color(1,.70,.15), Color(1,.80,.27))
	else:
		for blade in 7:
			var angle: float = blade * 2.39996
			var side := Vector3(cos(angle),0,sin(angle)) * .07
			var bend := Vector3(sin(angle),0,cos(angle)) * (.22 + (blade % 3) * .06)
			var mid: Vector3 = Vector3.UP * (.45 + (blade % 3) * .12) + bend * .3
			var tip: Vector3 = Vector3.UP * (.75 + (blade % 3) * .2) + bend
			_face(vertices, colors, normals, -side, side, mid + side * .6, Color(.09,.21,.04), Color(.23,.37,.08))
			_face(vertices, colors, normals, -side, mid + side * .6, mid - side * .6, Color(.09,.21,.04), Color(.23,.37,.08))
			_face(vertices, colors, normals, mid - side * .6, mid + side * .6, tip, Color(.23,.37,.08), Color(.38,.48,.16))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_COLOR] = colors; arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays); return mesh

func _face(vertices: PackedVector3Array, colors: PackedColorArray, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, base: Color, tip: Color) -> void:
	vertices.append_array(PackedVector3Array([a,b,c])); colors.append_array(PackedColorArray([base,base,tip]))
	var normal: Vector3 = (b-a).cross(c-a).normalized(); normals.append_array(PackedVector3Array([normal,normal,normal]))
