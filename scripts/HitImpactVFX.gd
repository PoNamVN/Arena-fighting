class_name HitImpactVFX
extends Node3D

## Configuration
@export_range(0.08, 0.30, 0.01) var duration: float = 0.16
@export var flash_size: float = 0.38
@export var spark_count: int = 7
@export var spark_radius: float = 0.42
@export var core_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var glow_color: Color = Color(1.0, 0.88, 0.45, 0.9)

## Internal State
var _tween: Tween
var _flash_instance: MeshInstance3D
var _sparks_instance: MeshInstance3D
var _flash_material: StandardMaterial3D
var _sparks_material: StandardMaterial3D


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
		
	if not _sparks_instance:
		_sparks_instance = get_node_or_null("SparksInstance") as MeshInstance3D
	if not _sparks_instance:
		_sparks_instance = MeshInstance3D.new()
		_sparks_instance.name = "SparksInstance"
		add_child(_sparks_instance)
		
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flash_material.vertex_color_use_as_albedo = true
		_flash_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		
	if _sparks_material == null:
		_sparks_material = StandardMaterial3D.new()
		_sparks_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sparks_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sparks_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_sparks_material.vertex_color_use_as_albedo = true
		_sparks_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
		
	_flash_instance.material_override = _flash_material
	if _flash_instance.mesh == null:
		_flash_instance.mesh = _build_flash_mesh()
		
	_sparks_instance.material_override = _sparks_material
	if _sparks_instance.mesh == null:
		_sparks_instance.mesh = _build_sparks_mesh()


func _build_flash_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# 4-pointed stylized diamond/star flash
	var r_outer: float = flash_size
	var r_inner: float = flash_size * 0.22
	
	# Center vertex (0)
	st.set_color(core_color)
	st.set_normal(Vector3.BACK)
	st.add_vertex(Vector3.ZERO)
	
	# Outer perimeter vertices (1 to 8)
	for i in range(8):
		var angle: float = i * (PI / 4.0)
		var is_tip: bool = (i % 2 == 0)
		var r: float = r_outer if is_tip else r_inner
		var col: Color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0) if is_tip else core_color
		st.set_color(col)
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(cos(angle) * r, sin(angle) * r, 0.0))
		
	for i in range(8):
		var next_idx: int = ((i + 1) % 8) + 1
		st.add_index(0)
		st.add_index(i + 1)
		st.add_index(next_idx)
		
	return st.commit()


func _build_sparks_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for k in range(spark_count):
		var base_angle: float = k * (TAU / float(spark_count)) + 0.15 * sin(k * 2.5)
		var dir2d: Vector2 = Vector2(cos(base_angle), sin(base_angle))
		var perp2d: Vector2 = Vector2(-dir2d.y, dir2d.x)
		
		var r_start: float = spark_radius * 0.25
		var r_end: float = spark_radius
		var half_w: float = 0.024
		var z_spray: float = 0.06 * sin(k * 3.7) # subtle 3D dispersion
		
		var v_tail: Vector3 = Vector3(dir2d.x * r_start, dir2d.y * r_start, 0.0)
		var v_mid_l: Vector3 = Vector3(dir2d.x * (r_start + 0.14) + perp2d.x * half_w, dir2d.y * (r_start + 0.14) + perp2d.y * half_w, z_spray * 0.5)
		var v_mid_r: Vector3 = Vector3(dir2d.x * (r_start + 0.14) - perp2d.x * half_w, dir2d.y * (r_start + 0.14) - perp2d.y * half_w, z_spray * 0.5)
		var v_tip: Vector3 = Vector3(dir2d.x * r_end, dir2d.y * r_end, z_spray)
		
		var base_vert: int = k * 4
		st.set_color(Color(glow_color.r, glow_color.g, glow_color.b, 0.3))
		st.add_vertex(v_tail)
		
		st.set_color(core_color)
		st.add_vertex(v_mid_l)
		
		st.set_color(Color(glow_color.r, glow_color.g, glow_color.b, 0.9))
		st.add_vertex(v_mid_r)
		
		st.set_color(Color(core_color.r, core_color.g, core_color.b, 0.0))
		st.add_vertex(v_tip)
		
		st.add_index(base_vert + 0)
		st.add_index(base_vert + 1)
		st.add_index(base_vert + 2)
		
		st.add_index(base_vert + 1)
		st.add_index(base_vert + 3)
		st.add_index(base_vert + 2)
		
	return st.commit()


func trigger(hit_position: Vector3, hit_normal_or_direction: Vector3) -> void:
	if not _flash_instance or not _sparks_instance:
		_setup_meshes_and_materials()
		
	var dir: Vector3 = hit_normal_or_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	
	global_position = hit_position
	# Face the impact plane perpendicular to impact direction
	if abs(dir.dot(Vector3.UP)) > 0.95:
		global_basis = Basis.looking_at(dir, Vector3.FORWARD)
	else:
		global_basis = Basis.looking_at(dir, Vector3.UP)
		
	# Clean up any active previous tween to avoid stale accumulation
	if _tween and _tween.is_valid():
		_tween.kill()
		
	visible = true
	
	# Initial states
	_flash_instance.scale = Vector3(0.2, 0.2, 0.2)
	_flash_instance.transparency = 0.0
	_flash_instance.rotation_degrees.z = randf_range(0.0, 45.0)
	
	_sparks_instance.scale = Vector3(0.3, 0.3, 0.3)
	_sparks_instance.transparency = 0.0
	_sparks_instance.rotation_degrees.z = randf_range(0.0, 60.0)
	
	_tween = create_tween()
	_tween.set_parallel(true)
	
	# 1. Flash: rapid pop (0.04s) then quick fade (0.08s)
	_tween.tween_property(_flash_instance, "scale", Vector3(1.2, 1.2, 1.2), 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_flash_instance, "transparency", 1.0, 0.08)\
		.set_delay(0.03)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# 2. Sparks: radial burst expansion (0.13s) and fade out
	_tween.tween_property(_sparks_instance, "scale", Vector3(1.15, 1.15, 1.15), 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sparks_instance, "transparency", 1.0, 0.10)\
		.set_delay(0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# 3. Hide on completion
	_tween.finished.connect(func() -> void:
		visible = false
	)


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	if _flash_instance:
		_flash_instance.transparency = 1.0
	if _sparks_instance:
		_sparks_instance.transparency = 1.0
