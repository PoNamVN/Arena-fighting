class_name ShieldBreakVFX
extends Node3D

## Configuration
@export_range(0.25, 0.40, 0.01) var duration: float = 0.32
@export var burst_radius: float = 0.65
@export var shard_count: int = 12
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0) # Radiant core burst
@export var energy_color: Color = Color(0.2, 0.55, 1.0, 0.95) # Saturated electric sapphire
@export var fracture_color: Color = Color(0.7, 0.25, 1.0, 0.85) # High-energy violet fracture fringe

## Internal State
var _tween: Tween
var _flash_instance: MeshInstance3D
var _shards_instance: MeshInstance3D
var _ring_instance: MeshInstance3D
var _flash_material: StandardMaterial3D
var _shards_material: StandardMaterial3D
var _ring_material: StandardMaterial3D


func _enter_tree() -> void:
	_setup_meshes_and_materials()


func _ready() -> void:
	visible = false
	_setup_meshes_and_materials()


func _setup_meshes_and_materials() -> void:
	if not _flash_instance:
		_flash_instance = get_node_or_null("FlashInstance") as MeshInstance3D
	if not _flash_instance:
		_flash_instance = MeshInstance3D.new()
		_flash_instance.name = "FlashInstance"
		add_child(_flash_instance)

	if not _shards_instance:
		_shards_instance = get_node_or_null("ShardsInstance") as MeshInstance3D
	if not _shards_instance:
		_shards_instance = MeshInstance3D.new()
		_shards_instance.name = "ShardsInstance"
		add_child(_shards_instance)

	if not _ring_instance:
		_ring_instance = get_node_or_null("RingInstance") as MeshInstance3D
	if not _ring_instance:
		_ring_instance = MeshInstance3D.new()
		_ring_instance.name = "RingInstance"
		add_child(_ring_instance)

	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flash_material.vertex_color_use_as_albedo = true
		_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	if _shards_material == null:
		_shards_material = StandardMaterial3D.new()
		_shards_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shards_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shards_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shards_material.vertex_color_use_as_albedo = true
		_shards_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	if _ring_material == null:
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring_material.vertex_color_use_as_albedo = true
		_ring_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	_flash_instance.material_override = _flash_material
	if _flash_instance.mesh == null:
		_flash_instance.mesh = _build_flash_mesh()

	_shards_instance.material_override = _shards_material
	if _shards_instance.mesh == null:
		_shards_instance.mesh = _build_shards_mesh()

	_ring_instance.material_override = _ring_material
	if _ring_instance.mesh == null:
		_ring_instance.mesh = _build_ring_mesh()


func _build_flash_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 8-pointed high-intensity crack burst flare
	var r_outer: float = burst_radius * 0.55
	var r_inner: float = burst_radius * 0.15

	st.set_color(core_color)
	st.set_normal(Vector3.BACK)
	st.add_vertex(Vector3.ZERO)

	for i in range(16):
		var angle: float = i * (PI / 8.0)
		var is_tip: bool = (i % 2 == 0)
		var r: float = r_outer if is_tip else r_inner
		var col: Color = Color(energy_color.r, energy_color.g, energy_color.b, 0.0) if is_tip else core_color
		st.set_color(col)
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(cos(angle) * r, sin(angle) * r, 0.0))

	for i in range(16):
		var next_idx: int = ((i + 1) % 16) + 1
		st.add_index(0)
		st.add_index(i + 1)
		st.add_index(next_idx)

	return st.commit()


func _build_shards_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 12 crystalline shield shards erupting outward in 3D
	for k in range(shard_count):
		var angle: float = k * (TAU / float(shard_count)) + 0.15 * sin(k * 3.1)
		var radial_dir: Vector2 = Vector2(cos(angle), sin(angle))
		var perp_dir: Vector2 = Vector2(-radial_dir.y, radial_dir.x)

		# Varying shard sizes and outward dispersion
		var r_dist: float = burst_radius * (0.65 + 0.35 * sin(k * 1.7))
		var z_burst: float = burst_radius * (0.35 * cos(k * 2.1))
		var shard_w: float = 0.045

		var v_origin: Vector3 = Vector3(radial_dir.x * 0.08, radial_dir.y * 0.08, 0.0)
		var v_mid_l: Vector3 = Vector3(radial_dir.x * (r_dist * 0.45) + perp_dir.x * shard_w, radial_dir.y * (r_dist * 0.45) + perp_dir.y * shard_w, z_burst * 0.4)
		var v_mid_r: Vector3 = Vector3(radial_dir.x * (r_dist * 0.45) - perp_dir.x * shard_w, radial_dir.y * (r_dist * 0.45) - perp_dir.y * shard_w, z_burst * 0.4)
		var v_tip: Vector3 = Vector3(radial_dir.x * r_dist, radial_dir.y * r_dist, z_burst)

		var base_vert: int = k * 4
		st.set_color(core_color)
		st.add_vertex(v_origin)

		st.set_color(Color(energy_color.r, energy_color.g, energy_color.b, 0.95))
		st.add_vertex(v_mid_l)

		st.set_color(Color(fracture_color.r, fracture_color.g, fracture_color.b, 0.9))
		st.add_vertex(v_mid_r)

		st.set_color(Color(fracture_color.r, fracture_color.g, fracture_color.b, 0.0))
		st.add_vertex(v_tip)

		st.add_index(base_vert + 0)
		st.add_index(base_vert + 1)
		st.add_index(base_vert + 2)

		st.add_index(base_vert + 1)
		st.add_index(base_vert + 3)
		st.add_index(base_vert + 2)

	return st.commit()


func _build_ring_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Expanding fractured shockwave ring
	var segments: int = 16
	var r_inner: float = burst_radius * 0.25
	var r_outer: float = burst_radius * 0.55

	for i in range(segments):
		var a1: float = i * (TAU / float(segments))
		var a2: float = (i + 1) * (TAU / float(segments))

		var p1_in: Vector3 = Vector3(cos(a1) * r_inner, sin(a1) * r_inner, 0.0)
		var p1_out: Vector3 = Vector3(cos(a1) * r_outer, sin(a1) * r_outer, 0.0)
		var p2_in: Vector3 = Vector3(cos(a2) * r_inner, sin(a2) * r_inner, 0.0)
		var p2_out: Vector3 = Vector3(cos(a2) * r_outer, sin(a2) * r_outer, 0.0)

		var vert_base: int = i * 4

		st.set_color(Color(energy_color.r, energy_color.g, energy_color.b, 0.85))
		st.add_vertex(p1_in)

		st.set_color(Color(fracture_color.r, fracture_color.g, fracture_color.b, 0.0))
		st.add_vertex(p1_out)

		st.set_color(Color(energy_color.r, energy_color.g, energy_color.b, 0.85))
		st.add_vertex(p2_in)

		st.set_color(Color(fracture_color.r, fracture_color.g, fracture_color.b, 0.0))
		st.add_vertex(p2_out)

		st.add_index(vert_base + 0)
		st.add_index(vert_base + 1)
		st.add_index(vert_base + 2)

		st.add_index(vert_base + 1)
		st.add_index(vert_base + 3)
		st.add_index(vert_base + 2)

	return st.commit()


func trigger(break_position: Vector3, normal: Vector3 = Vector3.UP) -> void:
	if not _flash_instance or not _shards_instance or not _ring_instance:
		_setup_meshes_and_materials()

	var dir: Vector3 = normal
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()

	global_position = break_position

	if abs(dir.dot(Vector3.UP)) > 0.95:
		global_basis = Basis.looking_at(dir, Vector3.FORWARD)
	else:
		global_basis = Basis.looking_at(dir, Vector3.UP)

	# Clean up any active previous tween to avoid stale accumulation
	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true

	# Reset initial transforms and visibilities
	_flash_instance.scale = Vector3(0.2, 0.2, 0.2)
	_flash_instance.transparency = 0.0
	_flash_instance.rotation_degrees.z = randf_range(0.0, 45.0)

	_ring_instance.scale = Vector3(0.25, 0.25, 0.25)
	_ring_instance.transparency = 0.0
	_ring_instance.rotation_degrees.z = randf_range(0.0, 30.0)

	_shards_instance.scale = Vector3(0.3, 0.3, 0.3)
	_shards_instance.transparency = 0.0
	_shards_instance.rotation_degrees.z = randf_range(0.0, 60.0)

	_tween = create_tween()
	_tween.set_parallel(true)

	# 1. Flash pop and rapid dissipation
	_tween.tween_property(_flash_instance, "scale", Vector3(1.3, 1.3, 1.3), 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_flash_instance, "transparency", 1.0, 0.10)\
		.set_delay(0.04)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 2. Expanding shockwave ring
	_tween.tween_property(_ring_instance, "scale", Vector3(1.7, 1.7, 1.7), 0.20)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_ring_instance, "transparency", 1.0, 0.14)\
		.set_delay(0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 3. Violent shard eruption: fragments fling outward and spin
	_tween.tween_property(_shards_instance, "scale", Vector3(1.65, 1.65, 1.65), duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_shards_instance, "transparency", 1.0, 0.16)\
		.set_delay(duration - 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.finished.connect(func() -> void:
		visible = false
	)


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	if _flash_instance:
		_flash_instance.transparency = 1.0
	if _ring_instance:
		_ring_instance.transparency = 1.0
	if _shards_instance:
		_shards_instance.transparency = 1.0
