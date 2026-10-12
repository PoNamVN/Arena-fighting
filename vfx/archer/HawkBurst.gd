extends "res://scripts/vfx/PooledVFX.gd"

var ring: MeshInstance3D
var feathers: CPUParticles3D
var material: StandardMaterial3D
var waves: Array[MeshInstance3D] = []
var dust: CPUParticles3D

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
	for index in range(2):
		var wave := MeshInstance3D.new()
		wave.mesh = torus
		wave.material_override = material.duplicate()
		add_child(wave)
		waves.append(wave)
	feathers = CPUParticles3D.new()
	feathers.amount = 20
	feathers.lifetime = .65
	feathers.one_shot = true
	feathers.explosiveness = .9
	feathers.emitting = false
	feathers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	feathers.emission_sphere_radius = .6
	feathers.direction = Vector3.UP
	feathers.spread = 75
	feathers.initial_velocity_min = 1.5
	feathers.initial_velocity_max = 6.0
	feathers.gravity = Vector3(0, -14, 0)
	feathers.angular_velocity_min = -90
	feathers.angular_velocity_max = 90
	var feather := PrismMesh.new()
	feather.size = Vector3(.045, .025, .06)
	feathers.mesh = feather
	var feather_material := StandardMaterial3D.new()
	feather_material.albedo_color = Color(.75, .6, .4)
	feather_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	feathers.material_override = feather_material
	add_child(feathers)
	dust = CPUParticles3D.new()
	dust.amount = 36
	dust.lifetime = .65
	dust.one_shot = true
	dust.explosiveness = .9
	dust.emitting = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = .8
	dust.direction = Vector3.UP
	dust.spread = 85
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.gravity = Vector3(0, -2, 0)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.8
	var puff := SphereMesh.new()
	puff.radius = .10
	puff.height = .20
	puff.radial_segments = 8
	puff.rings = 4
	dust.mesh = puff
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color = Color(.75, .62, .43, .35)
	dust.material_override = haze
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0, .12, 1])
	dust.color_ramp = fade
	add_child(dust)
	super._ready()

func _on_play(context: Dictionary) -> void:
	material.albedo_color = context.get("color", Color(.65, .85, 1, .65))
	feathers.visible = effective_particles() > 0 and context.get("ground", false) and not context.get("mark", false)
	dust.visible = feathers.visible
	var strength: float = context.get("strength", 1.0)
	feathers.initial_velocity_max = 6.0 * strength
	dust.initial_velocity_max = 4.0 * strength
	if feathers.visible:
		feathers.restart()
		dust.restart()
	ring.scale = Vector3.ONE

func _on_update(_delta: float) -> void:
	var progress := clampf(elapsed / duration, 0, 1)
	var marked: bool = _context.get("mark", false)
	var strength: float = _context.get("strength", 1.0)
	ring.scale = Vector3.ONE * (1 + sin(elapsed * 12) * .06 if marked else .7 + progress * 6.0 * strength)
	material.albedo_color.a = .3 + .5 * (.5 + .5 * sin(elapsed * TAU * 8)) if marked else (1 - progress) * .55
	for index in range(waves.size()):
		var wave_progress := clampf((progress - (index + 1) * .13) / .74, 0, 1)
		waves[index].visible = not marked and progress >= (index + 1) * .13
		waves[index].scale = Vector3.ONE * (.7 + wave_progress * 6.0 * strength)
		var tint := waves[index].material_override as StandardMaterial3D
		tint.albedo_color = Color(material.albedo_color, (1 - wave_progress) * .4)

func _on_reset() -> void:
	if ring: ring.scale = Vector3.ONE
