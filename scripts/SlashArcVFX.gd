class_name SlashArcVFX
extends Node3D

## Configuration
@export_range(60.0, 180.0, 5.0) var arc_angle_deg: float = 120.0
@export_range(0.5, 2.5, 0.05) var radius: float = 1.05
@export_range(0.04, 0.4, 0.01) var ribbon_width: float = 0.14
@export_range(0.08, 0.30, 0.01) var duration: float = 0.15
@export var arc_segments: int = 24
@export var trail_color_core: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var trail_color_glow: Color = Color(1.0, 0.88, 0.45, 0.85)

## Node References
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

## Internal State
var _tween: Tween
var _material: StandardMaterial3D


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
	if mesh_instance.mesh == null:
		mesh_instance.mesh = _build_arc_mesh()


func _build_arc_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for i in range(arc_segments + 1):
		var t: float = float(i) / float(arc_segments)
		# Gladiator right-handed slash: sweeps from character's right (+angle) to left (-angle)
		var angle_deg: float = lerp(arc_angle_deg * 0.5, -arc_angle_deg * 0.5, t)
		var alpha: float = deg_to_rad(angle_deg)
		
		# Crescent width profile: tapered at both tips, thickest in middle
		var w: float = pow(sin(t * PI), 0.6) * ribbon_width
		if i == 0 or i == arc_segments:
			w = 0.001
			
		# Arc centerline on circle centered at local (0, 0, radius)
		# Arc midpoint (alpha=0) passes directly through local (0, 0, 0)
		var xc: float = radius * sin(alpha)
		var zc: float = radius - radius * cos(alpha)
		var yc: float = (0.5 - t) * 0.08 # Subtle downward slash slant
		
		var nx: float = sin(alpha)
		var nz: float = -cos(alpha)
		
		# Alpha profile: sharp crescent blade
		var arc_alpha: float = sin(t * PI)
		if t > 0.5:
			arc_alpha = lerp(1.0, 0.7, (t - 0.5) * 2.0)
		else:
			arc_alpha = lerp(0.0, 1.0, t * 2.0)
			
		var color_out: Color = Color(
			trail_color_core.r,
			trail_color_core.g,
			trail_color_core.b,
			trail_color_core.a * arc_alpha
		)
		var color_in: Color = Color(
			trail_color_glow.r,
			trail_color_glow.g,
			trail_color_glow.b,
			trail_color_glow.a * arc_alpha * 0.75
		)
		
		var v_out: Vector3 = Vector3(xc + nx * (w * 0.5), yc, zc + nz * (w * 0.5))
		var v_in: Vector3 = Vector3(xc - nx * (w * 0.5), yc, zc - nz * (w * 0.5))
		
		# Outer cutting edge vertex
		st.set_color(color_out)
		st.set_uv(Vector2(t, 1.0))
		st.set_normal(Vector3.UP)
		st.add_vertex(v_out)
		
		# Inner edge vertex
		st.set_color(color_in)
		st.set_uv(Vector2(t, 0.0))
		st.set_normal(Vector3.UP)
		st.add_vertex(v_in)
		
	for i in range(arc_segments):
		var v0: int = i * 2
		var v1: int = i * 2 + 1
		var v2: int = (i + 1) * 2
		var v3: int = (i + 1) * 2 + 1
		
		st.add_index(v0)
		st.add_index(v1)
		st.add_index(v2)
		
		st.add_index(v2)
		st.add_index(v1)
		st.add_index(v3)
		
	return st.commit()


func trigger(attack_dir: Vector3, player_pos: Vector3) -> void:
	if not mesh_instance or not _material:
		_setup_mesh_and_material()
		
	var direction: Vector3 = attack_dir
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = -global_basis.z
		direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	
	# Place the cue 1.1m in front of the player along the attack direction
	global_position = player_pos + direction * 1.1
	global_position.y = player_pos.y + 0.9
	
	# Orient towards the attack direction
	global_basis = Basis.looking_at(direction, Vector3.UP)
	
	# Prevent overlapping stale tweens from previous attacks
	if _tween and _tween.is_valid():
		_tween.kill()
		
	visible = true
	scale = Vector3(0.4, 0.7, 0.4)
	if mesh_instance:
		mesh_instance.transparency = 0.0
		mesh_instance.rotation_degrees.y = 8.0 # Small lead angle
		
	_tween = create_tween()
	_tween.set_parallel(true)
	
	# 1. Quickly expand from small/short to full arc (0.06s)
	_tween.tween_property(self, "scale", Vector3(1.05, 1.0, 1.05), 0.06)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# 2. Dynamic sweep rotation along the cut (0.09s)
	if mesh_instance:
		_tween.tween_property(mesh_instance, "rotation_degrees:y", -6.0, 0.09)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			
	# 3. Fade out transparency (begins at 0.04s, finishes at total duration ~0.15s)
	var fade_time: float = max(0.05, duration - 0.04)
	if mesh_instance:
		_tween.tween_property(mesh_instance, "transparency", 1.0, fade_time)\
			.set_delay(0.04)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			
	# 4. Hide when finished: use both tween_callback with exact delay and finished signal
	_tween.finished.connect(func() -> void:
		visible = false
	)


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
	if mesh_instance:
		mesh_instance.transparency = 1.0
