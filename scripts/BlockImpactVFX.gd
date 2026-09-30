class_name BlockImpactVFX
extends Node3D

## Configuration
@export_range(0.08, 0.25, 0.01) var duration: float = 0.14
@export var flash_size: float = 0.35
@export var spark_count: int = 6
@export var spark_radius: float = 0.40
@export var core_color: Color = Color(0.9, 0.95, 1.0, 1.0) # Crisp white-cyan core
@export var glow_color: Color = Color(0.25, 0.65, 1.0, 0.85) # Electric cyan shield energy

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
	
	# 6-pointed shield flare / hexagonal energy barrier flash
	var r_outer: float = flash_size
	var r_inner: float = flash_size * 0.28
	
	# Center vertex (0)
	st.set_color(core_color)
	st.set_normal(Vector3.BACK)
	st.add_vertex(Vector3.ZERO)
	
	# Perimeter vertices (1 to 12)
	for i in range(12):
		var angle: float = i * (PI / 6.0)
		var is_tip: bool = (i % 2 == 0)
		var r: float = r_outer if is_tip else r_inner
		var col: Color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0) if is_tip else core_color
		st.set_color(col)
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3(cos(angle) * r, sin(angle) * r, 0.0))
		
	for i in range(12):
		var next_idx: int = ((i + 1) % 12) + 1
		st.add_index(0)
		st.add_index(i + 1)
		st.add_index(next_idx)
		
	return st.commit()


func _build_sparks_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Low-poly deflection shards bursting outward toward +Z (toward attacker)
	for k in range(spark_count):
		# Spread in cone toward +Z
		var fan_angle: float = k * (TAU / float(spark_count)) + 0.12 * sin(k * 2.3)
		var radial_dir: Vector2 = Vector2(cos(fan_angle), sin(fan_angle))
		var perp_dir: Vector2 = Vector2(-radial_dir.y, radial_dir.x)
		
		# Spark geometry: diamond shard oriented toward attacker (+Z) with radial fan
		var z_burst: float = spark_radius * 0.75 # Deflection distance toward attacker
		var r_fan: float = spark_radius * 0.55   # Radial deflection spread
		var half_w: float = 0.022
		
		var v_base: Vector3 = Vector3(radial_dir.x * 0.05, radial_dir.y * 0.05, 0.0)
		var v_mid_l: Vector3 = Vector3(radial_dir.x * (r_fan * 0.4) + perp_dir.x * half_w, radial_dir.y * (r_fan * 0.4) + perp_dir.y * half_w, z_burst * 0.4)
		var v_mid_r: Vector3 = Vector3(radial_dir.x * (r_fan * 0.4) - perp_dir.x * half_w, radial_dir.y * (r_fan * 0.4) - perp_dir.y * half_w, z_burst * 0.4)
		var v_tip: Vector3 = Vector3(radial_dir.x * r_fan, radial_dir.y * r_fan, z_burst)
		
		var base_vert: int = k * 4
		st.set_color(Color(glow_color.r, glow_color.g, glow_color.b, 0.4))
		st.add_vertex(v_base)
		
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


func trigger(block_position: Vector3, incoming_direction: Vector3) -> void:
	if not _flash_instance or not _sparks_instance:
		_setup_meshes_and_materials()
		
	var dir: Vector3 = incoming_direction
	if dir.length_squared() < 0.0001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	
	global_position = block_position
	
	# In Godot Basis.looking_at(dir, up), local -Z points toward dir.
	# Since incoming_direction points from attacker to defender, local +Z points back toward attacker.
	# The flash lies on local XY (the shield barrier plane) and sparks burst toward local +Z (back to attacker).
	if abs(dir.dot(Vector3.UP)) > 0.95:
		global_basis = Basis.looking_at(dir, Vector3.FORWARD)
	else:
		global_basis = Basis.looking_at(dir, Vector3.UP)
		
	# Clean up any active previous tween to avoid stale accumulation
	if _tween and _tween.is_valid():
		_tween.kill()
		
	visible = true
	
	# Initial states
	_flash_instance.scale = Vector3(0.25, 0.25, 0.25)
	_flash_instance.transparency = 0.0
	_flash_instance.rotation_degrees.z = randf_range(0.0, 30.0)
	
	_sparks_instance.scale = Vector3(0.3, 0.3, 0.3)
	_sparks_instance.transparency = 0.0
	_sparks_instance.rotation_degrees.z = randf_range(0.0, 60.0)
	
	_tween = create_tween()
	_tween.set_parallel(true)
	
	# 1. Shield flash: rapid pop (0.04s) then crisp fade (0.07s)
	_tween.tween_property(_flash_instance, "scale", Vector3(1.15, 1.15, 1.15), 0.04)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_flash_instance, "transparency", 1.0, 0.07)\
		.set_delay(0.03)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# 2. Deflection sparks: burst back toward attacker (0.11s) and fade out
	_tween.tween_property(_sparks_instance, "scale", Vector3(1.2, 1.2, 1.25), 0.11)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_sparks_instance, "transparency", 1.0, 0.08)\
		.set_delay(0.04)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		
	# 3. Clean finish
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
