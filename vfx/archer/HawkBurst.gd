extends "res://scripts/vfx/PooledVFX.gd"

var ring: MeshInstance3D
var feathers: CPUParticles3D
var material: StandardMaterial3D

func _ready() -> void:
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = .48
	torus.outer_radius = .53
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	add_child(ring)
	feathers = CPUParticles3D.new()
	feathers.amount = 20
	feathers.lifetime = .65
	feathers.one_shot = true
	feathers.explosiveness = .9
	feathers.direction = Vector3.UP
	feathers.spread = 75
	feathers.initial_velocity_min = .5
	feathers.initial_velocity_max = 2.8
	feathers.gravity = Vector3(0, -3, 0)
	feathers.angular_velocity_min = -90
	feathers.angular_velocity_max = 90
	var feather := PrismMesh.new()
	feather.size = Vector3(.06, .015, .2)
	feathers.mesh = feather
	var feather_material := StandardMaterial3D.new()
	feather_material.albedo_color = Color(.75, .6, .4)
	feather_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	feathers.material_override = feather_material
	add_child(feathers)
	super._ready()

func _on_play(context: Dictionary) -> void:
	material.albedo_color = context.get("color", Color(.5, .9, .8, .75))
	feathers.visible = effective_particles() > 0 and not context.get("mark", false)
	if feathers.visible: feathers.restart()
	ring.scale = Vector3.ONE

func _on_update(_delta: float) -> void:
	var progress := clampf(elapsed / duration, 0, 1)
	var marked: bool = _context.get("mark", false)
	ring.scale = Vector3.ONE * (1 + sin(elapsed * 12) * .06 if marked else 1 + progress * 2)
	material.albedo_color.a = .8 if marked else (1 - progress) * .65

func _on_reset() -> void:
	if ring: ring.scale = Vector3.ONE
