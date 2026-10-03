class_name GiantSwordVFX
extends Node3D

const DROP_HEIGHT: float = 60.0
const CLOUD_HEIGHT: float = 34.0
var _sigil: MeshInstance3D
var _sigil_material: ShaderMaterial
var _fall_wake: MeshInstance3D
var sword: Node3D
var ring: MeshInstance3D
var shockwave: MeshInstance3D
var clouds: Array[MeshInstance3D] = []
var debris: Array[Transform3D] = []
var _debris_batch: MultiMesh
var _sword_materials: Array[ShaderMaterial] = []
var _ring_material: StandardMaterial3D
var _cloud_material: StandardMaterial3D
var _shock_material: StandardMaterial3D
var _fall_audio: AudioStreamPlayer
var _impact_audio: AudioStreamPlayer
var _impact_elapsed: float = -1.0
var _cloud_split: float = 0.0
var _radius: float = 4.5


func _ready() -> void:
	top_level = true
	sword = preload("res://assets/models/knight_ultimate_sword.glb").instantiate() as Node3D
	add_child(sword)
	for mesh: MeshInstance3D in sword.find_children("*", "MeshInstance3D", true, false):
		var original: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/ultimate_sword_dissolve.gdshader")
		material.set_shader_parameter("metal_color", original.albedo_color if original else Color(0.6, 0.67, 0.74))
		material.set_shader_parameter("metalness", original.metallic if original else 0.85)
		mesh.material_override = material
		_sword_materials.append(material)
	_sigil = MeshInstance3D.new()
	var sigil_plane: PlaneMesh = PlaneMesh.new()
	sigil_plane.size = Vector2(2.22, 2.22)
	_sigil.mesh = sigil_plane
	_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sigil_material = preload("res://scripts/CombatSpectacle.gd").sigil_material(Color(1, 0.65, 0.15))
	_sigil.material_override = _sigil_material
	add_child(_sigil)
	_fall_wake = MeshInstance3D.new()
	var wake: CylinderMesh = CylinderMesh.new()
	wake.top_radius = 1.2
	wake.bottom_radius = 0.12
	wake.height = 16
	wake.radial_segments = 8
	_fall_wake.mesh = wake
	_fall_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var wake_material: StandardMaterial3D = _make_material(Color(1, 0.6, 0.15, 0.16), true)
	wake_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fall_wake.material_override = wake_material
	add_child(_fall_wake)
	_ring_material = _make_material(Color(1, 0.72, 0.15, 0.85), true)
	ring = _make_ring(_ring_material)
	_shock_material = _make_material(Color(1, 0.78, 0.38, 0.8), true)
	shockwave = _make_ring(_shock_material)
	_cloud_material = _make_material(Color(0.85, 0.89, 0.94, 0.9), false)
	var puff: SphereMesh = SphereMesh.new()
	puff.radius = 1.0
	puff.height = 2.0
	puff.radial_segments = 12
	puff.rings = 6
	for index: int in range(12):
		var cloud: MeshInstance3D = MeshInstance3D.new()
		cloud.mesh = puff
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.material_override = _cloud_material
		cloud.scale = Vector3(6, 2.8 + float(index % 3) * 0.6, 4.5)
		add_child(cloud)
		clouds.append(cloud)
	var dust_material: StandardMaterial3D = _make_material(Color(0.35, 0.25, 0.14), false)
	var dust: MultiMeshInstance3D = MultiMeshInstance3D.new()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.material_override = dust_material
	_debris_batch = MultiMesh.new()
	_debris_batch.transform_format = MultiMesh.TRANSFORM_3D
	_debris_batch.mesh = puff
	_debris_batch.instance_count = 32
	_debris_batch.visible_instance_count = 0
	dust.multimesh = _debris_batch
	add_child(dust)
	debris.resize(32)
	_fall_audio = AudioStreamPlayer.new()
	_fall_audio.stream = preload("res://assets/audio/ultimate_fall.wav")
	_fall_audio.volume_db = -8
	add_child(_fall_audio)
	_impact_audio = AudioStreamPlayer.new()
	_impact_audio.stream = preload("res://assets/audio/ultimate_impact.wav")
	_impact_audio.volume_db = -5
	add_child(_impact_audio)
	stop()


func _make_material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _make_ring(material: Material) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	torus.rings = 64
	torus.ring_segments = 4
	mesh.mesh = torus
	mesh.material_override = material
	add_child(mesh)
	return mesh


func show_target(origin: Vector3, radius: float, valid: bool) -> void:
	global_transform = Transform3D(Basis.IDENTITY, origin)
	_radius = radius
	_sigil.show()
	_sigil.position.y = 0.07
	_sigil.scale = Vector3(radius, 1, radius)
	_sigil_material.set_shader_parameter("tint", Color(1, 0.65, 0.15) if valid else Color(1, 0.15, 0.1))
	ring.position.y = 0.08
	ring.scale = Vector3(radius, 0.2, radius)
	_ring_material.albedo_color = Color(1, 0.72, 0.15, 0.85) if valid else Color(1, 0.15, 0.1, 0.7)
	ring.visible = true
	sword.visible = false
	shockwave.visible = false
	visible = true


func begin(origin: Vector3, radius: float) -> void:
	stop()
	show_target(origin, radius, true)
	sword.visible = true
	sword.position.y = DROP_HEIGHT
	_cloud_split = 0.0
	_cloud_material.albedo_color.a = 0.9
	for material: ShaderMaterial in _sword_materials:
		material.set_shader_parameter("dissolve", 0.0)
	_update_clouds()
	_fall_audio.play()


func _update_clouds() -> void:
	for index: int in range(clouds.size()):
		var angle: float = TAU * float(index) / float(clouds.size())
		var distance: float = 5.0 + _cloud_split * 9.0 + float(index % 3)
		clouds[index].position = Vector3(cos(angle) * distance, CLOUD_HEIGHT + float(index % 3) - 1.0, sin(angle) * distance)
		clouds[index].visible = true


func update_startup(remaining: float, duration: float) -> void:
	var progress: float = clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)
	sword.position.y = lerpf(DROP_HEIGHT, 0.0, progress * progress)
	_fall_wake.visible = progress > 0.1
	_fall_wake.position.y = sword.position.y + 18
	_fall_wake.scale = Vector3.ONE * smoothstep(0.1, 0.4, progress)
	_cloud_split = clampf((CLOUD_HEIGHT + 8.0 - sword.position.y) / 20.0, 0.0, 1.0)
	_update_clouds()


func impact() -> void:
	_fall_wake.hide()
	_sigil.hide()
	var owner_actor: PlayerController = get_parent().get_parent() as PlayerController
	if owner_actor and owner_actor.spectacle:
		owner_actor.spectacle.burst(global_position, Color(1, 0.65, 0.15), _radius * 1.6, 2)
	sword.position.y = -0.4
	_impact_elapsed = 0.0
	_fall_audio.stop()
	_impact_audio.play()
	shockwave.visible = true
	_debris_batch.visible_instance_count = 32


func update_impact(delta: float) -> void:
	if _impact_elapsed < 0:
		return
	_impact_elapsed += delta
	var time: float = _impact_elapsed
	var wave_radius: float = lerpf(1.0, _radius * 2.5, clampf(time / 0.75, 0, 1))
	shockwave.position.y = 0.15
	shockwave.scale = Vector3(wave_radius, 0.15, wave_radius)
	_shock_material.albedo_color.a = maxf(0.0, 0.85 * (1.0 - time / 0.9))
	_cloud_material.albedo_color.a = maxf(0.0, 0.9 * (1.0 - time / 1.6))
	for index: int in range(debris.size()):
		var angle: float = TAU * float(index) / float(debris.size())
		var distance: float = (2.0 + float(index % 7)) * time
		var height: float = maxf(0.1, (3.0 + float(index % 5)) * time - 5.0 * time * time)
		var position: Vector3 = Vector3(cos(angle) * distance, height, sin(angle) * distance)
		var size: float = (0.2 + float(index % 4) * 0.13) * maxf(0, 1 - time / 1.8)
		debris[index] = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), position)
		_debris_batch.set_instance_transform(index, debris[index])


func update_recovery(remaining: float, duration: float) -> void:
	var progress: float = clampf(1.0 - remaining / maxf(duration, 0.001), 0, 1)
	# Solid during descent/impact; only dissolve once embedded in the ground.
	var dissolve: float = clampf((progress - 0.3) / 0.7, 0, 1)
	for material: ShaderMaterial in _sword_materials:
		material.set_shader_parameter("dissolve", dissolve)


func stop() -> void:
	if _fall_wake:
		_fall_wake.hide()
	if _sigil:
		_sigil.hide()
	visible = false
	_impact_elapsed = -1.0
	if _fall_audio:
		_fall_audio.stop()
	if _impact_audio:
		_impact_audio.stop()
	for cloud: MeshInstance3D in clouds:
		cloud.visible = false
	if _debris_batch:
		_debris_batch.visible_instance_count = 0
