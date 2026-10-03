class_name WhirlingBladeVFX
extends Node3D

var _mesh: MeshInstance3D
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2.25, 2.25)
	_mesh.mesh = plane
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = preload("res://scripts/CombatSpectacle.gd").sigil_material(Color(1.0, 0.85, 0.25), 2)
	_mesh.material_override = _material
	add_child(_mesh)
	visible = false


func trigger(origin: Vector3, radius: float, duration: float) -> void:
	stop()
	global_transform = Transform3D(Basis.IDENTITY, origin + Vector3(0.0, 0.9, 0.0))
	_mesh.scale = Vector3(radius, 0.4, radius)
	_material.set_shader_parameter("opacity", 0.7)
	visible = true
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void: _material.set_shader_parameter("opacity", value), 0.7, 0.0, duration)
	_tween.tween_callback(stop)


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false
