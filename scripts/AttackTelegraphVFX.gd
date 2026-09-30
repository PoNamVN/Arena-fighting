class_name AttackTelegraphVFX
extends Node3D

## Configuration
@export var default_windup: float = 0.35
@export var attack_range: float = 2.2
@export var arc_angle_deg: float = 60.0
@export var base_color: Color = Color(1.0, 0.36, 0.12, 0.75) # Warm warning red-orange
@export var rim_color: Color = Color(1.0, 0.88, 0.30, 0.95)  # Bright amber-gold rim

## Node References
@onready var mesh_instance: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D

## Internal State
var is_active: bool = false
var last_direction: Vector3 = Vector3.FORWARD
var last_origin: Vector3 = Vector3.ZERO
var last_windup: float = 0.35
var source_node: Node3D = null

var _tween: Tween = null
var _material: StandardMaterial3D = null


func _enter_tree() -> void:
	_setup_mesh_and_material()


func _ready() -> void:
	visible = false
	_setup_mesh_and_material()


func _setup_mesh_and_material() -> void:
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		add_child(mesh_instance)

	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.vertex_color_use_as_albedo = true
		_material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	mesh_instance.material_override = _material
	_generate_telegraph_mesh()


func _generate_telegraph_mesh() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half_angle: float = deg_to_rad(arc_angle_deg * 0.5)
	var segments: int = 12
	var inner_color: Color = Color(base_color.r, base_color.g, base_color.b, 0.15)
	var outer_color: Color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	var border_inner_r: float = attack_range * 0.90
	var border_outer_r: float = attack_range

	# 1. Sector Fan Triangles
	for i in range(segments):
		var t0: float = float(i) / float(segments)
		var t1: float = float(i + 1) / float(segments)
		var a0: float = -half_angle + t0 * (half_angle * 2.0)
		var a1: float = -half_angle + t1 * (half_angle * 2.0)

		# Local forward is -Z
		var p0_inner: Vector3 = Vector3.ZERO
		var p1_inner: Vector3 = Vector3(sin(a0) * border_inner_r, 0.0, -cos(a0) * border_inner_r)
		var p2_inner: Vector3 = Vector3(sin(a1) * border_inner_r, 0.0, -cos(a1) * border_inner_r)

		# Inner sector triangle
		st.set_color(inner_color)
		st.add_vertex(p0_inner)
		st.set_color(outer_color)
		st.add_vertex(p1_inner)
		st.set_color(outer_color)
		st.add_vertex(p2_inner)

		# 2. Outer Rim Ribbon
		var p1_outer: Vector3 = Vector3(sin(a0) * border_outer_r, 0.0, -cos(a0) * border_outer_r)
		var p2_outer: Vector3 = Vector3(sin(a1) * border_outer_r, 0.0, -cos(a1) * border_outer_r)

		# Quad tri 1
		st.set_color(outer_color)
		st.add_vertex(p1_inner)
		st.set_color(rim_color)
		st.add_vertex(p1_outer)
		st.set_color(rim_color)
		st.add_vertex(p2_outer)

		# Quad tri 2
		st.set_color(outer_color)
		st.add_vertex(p1_inner)
		st.set_color(rim_color)
		st.add_vertex(p2_outer)
		st.set_color(outer_color)
		st.add_vertex(p2_inner)

	# 3. Center Arrow / Chevron along -Z
	var arrow_start: float = 0.35
	var arrow_tip: float = attack_range * 0.85
	var arrow_width: float = 0.16
	st.set_color(rim_color)
	st.add_vertex(Vector3(0.0, 0.002, -arrow_tip))
	st.set_color(Color(rim_color.r, rim_color.g, rim_color.b, 0.4))
	st.add_vertex(Vector3(-arrow_width, 0.002, -arrow_start))
	st.set_color(Color(rim_color.r, rim_color.g, rim_color.b, 0.4))
	st.add_vertex(Vector3(arrow_width, 0.002, -arrow_start))

	mesh_instance.mesh = st.commit()


func set_attack_direction(dir: Vector3) -> void:
	var flat_dir: Vector3 = dir
	flat_dir.y = 0.0
	if flat_dir.length_squared() < 0.0001:
		flat_dir = Vector3.FORWARD
	flat_dir = flat_dir.normalized()
	last_direction = flat_dir

	# In Godot -Z is forward. Rotate around Y so local -Z points towards flat_dir
	var yaw: float = atan2(-flat_dir.x, -flat_dir.z)
	rotation = Vector3(0.0, yaw, 0.0)


func trigger(origin: Vector3, direction: Vector3, windup: float = 0.35, source: Node3D = null) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	source_node = source
	last_origin = origin
	last_windup = windup
	is_active = true
	visible = true

	set_attack_direction(direction)
	global_position = origin + Vector3(0.0, 0.03, 0.0)

	if _material:
		_material.albedo_color = Color(1.0, 1.0, 1.0, 0.35)

	_tween = create_tween()
	# Pulse/ramp opacity up to full intensity right as impact apex arrives
	if _material:
		_tween.tween_property(_material, "albedo_color:a", 1.0, windup)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(stop)


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	is_active = false
	source_node = null


func _process(_delta: float) -> void:
	if not is_active:
		return
	if source_node and is_instance_valid(source_node):
		global_position = source_node.global_position + Vector3(0.0, 0.03, 0.0)
