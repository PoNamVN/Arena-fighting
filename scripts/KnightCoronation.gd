extends Node3D
## Finisher presentation only. It never dispatches damage or changes arena collision.
const DURATION: float = 9.2
const ROCK_HIT: float = 1.35
const SWORD_DROP: float = 2.55
const SWORD_HIT: float = 3.75
const REVELATION: float = 5.35
const STONE_HEIGHT: float = 8.5
var elapsed: float = 0.0
var hold_revelation: bool = false
var rock: Node3D
var birds: Array[Node3D] = []
var beams: Array[MeshInstance3D] = []
var beam_materials: Array[ShaderMaterial] = []
var sunlight: SpotLight3D
var altar_light: OmniLight3D
var motes: MultiMesh
var sound: AudioStreamPlayer
var _rock_hit: bool = false
var _sword_hit: bool = false
var _revealed: bool = false
var _vfx: GiantSwordVFX
var garden: Node3D
var _stone_materials: Array[ShaderMaterial] = []

func _ready() -> void:
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	rock = preload("res://assets/models/knight_coronation_stone.scn").instantiate() as Node3D
	add_child(rock)
	for mesh: MeshInstance3D in rock.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
			var material := ShaderMaterial.new()
			material.shader = preload("res://assets/shaders/knight_coronation_stone.gdshader")
			material.set_shader_parameter("stone_color", original.albedo_color if original else Color(.3, .3, .3))
			mesh.set_surface_override_material(surface, material)
			_stone_materials.append(material)
	for i in 9:
		var bird: Node3D = preload("res://assets/models/knight_coronation_dove.scn").instantiate() as Node3D
		for mesh: MeshInstance3D in bird.find_children("*", "MeshInstance3D", true, false):
			var source: StandardMaterial3D = mesh.get_active_material(0) as StandardMaterial3D
			if source:
				var material: StandardMaterial3D = source.duplicate()
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.material_override = material
		add_child(bird); birds.append(bird)
	garden = preload("res://scripts/KnightCoronationGarden.gd").new()
	add_child(garden); garden.build(rock)
	for i in 5:
		var beam := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 15.0 if i == 0 else 3.5
		cone.bottom_radius = 10.0 if i == 0 else 2.5
		cone.height = 65.0; cone.radial_segments = 48
		beam.mesh = cone
		beam.position = Vector3(0, 32.5, 0) if i == 0 else Vector3(cos(i * TAU / 4) * 6.5, 32.5, sin(i * TAU / 4) * 6.5)
		beam.rotation.z = (i % 3 - 1) * .055
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/knight_coronation_radiance.gdshader")
		beam.material_override = material
		add_child(beam); beams.append(beam); beam_materials.append(material)
	sunlight = SpotLight3D.new(); sunlight.position.y = 60.0; sunlight.rotation_degrees.x = -90
	sunlight.spot_range = 80; sunlight.spot_angle = 35; sunlight.light_color = Color(1.0, .96, .86); sunlight.shadow_enabled = false
	add_child(sunlight)
	altar_light = OmniLight3D.new(); altar_light.position.y = 15; altar_light.omni_range = 24; altar_light.light_color = Color(1.0, .93, .79)
	add_child(altar_light)
	var glitter := MultiMeshInstance3D.new()
	motes = MultiMesh.new(); motes.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new(); sphere.radius = .04; sphere.height = .08; sphere.radial_segments = 8; sphere.rings = 4
	var golden := StandardMaterial3D.new(); golden.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	golden.emission_enabled = true; golden.emission = Color(1, .76, .28); golden.emission_energy_multiplier = 1.2
	sphere.material = golden; motes.mesh = sphere; motes.instance_count = 72; glitter.multimesh = motes
	add_child(glitter)
	sound = AudioStreamPlayer.new()
	sound.stream = preload("res://assets/audio/knight_coronation_fanfare.res")
	sound.volume_db = -12
	add_child(sound)
	stop()

func begin(origin: Vector3, vfx: GiantSwordVFX) -> void:
	hold_revelation = false
	stop(); _vfx = vfx; global_position = origin
	elapsed = 0.0; _rock_hit = false; _sword_hit = false; _revealed = false
	show(); rock.show(); rock.position.y = 68.0
	_vfx.begin(origin, 4.5); _vfx.sword.hide()
	for cloud in _vfx.clouds: cloud.hide()
	_vfx.ring.hide(); _vfx._fall_audio.stop()

func advance(delta: float) -> void:
	elapsed += delta
	var t: float = elapsed
	rock.position.y = lerpf(68.0, -.35, pow(clampf(t / ROCK_HIT, 0, 1), 2.4))
	if not _rock_hit and t >= ROCK_HIT:
		_rock_hit = true; _vfx.impact(); _vfx.sword.hide()
	if not _sword_hit and t >= SWORD_HIT:
		_sword_hit = true
		_vfx._burst.ground_y = global_position.y
		_vfx.impact()
		_vfx._impact_light.position.y = STONE_HEIGHT + 1.0
		_vfx._crater.hide(); _vfx._cracks.hide()
		garden.begin(global_position, _vfx)
	if _rock_hit:
		_vfx.update_impact(delta)
		if _sword_hit:
			_vfx.shockwave.position.y = .15
			_vfx.sword.position.y = STONE_HEIGHT - lerpf(2.4, 5.8, 1.0 - pow(1.0 - clampf((t - SWORD_HIT - _vfx.IMPACT_HOLD_SECONDS) / .24, 0, 1), 3.0))
			_vfx._floor_batch.visible_instance_count = 0
			_settle_stone_fragments(t - SWORD_HIT)
	_lower_dust()
	garden.update_growth(smoothstep(SWORD_HIT, 7.5, t), t)
	for cloud in _vfx.clouds: cloud.hide()
	_vfx.sword.visible = t >= SWORD_DROP
	if t >= SWORD_DROP and t < SWORD_HIT:
		_vfx.sword.position.y = lerpf(62.0, STONE_HEIGHT - 2.4, pow(clampf((t - SWORD_DROP) / (SWORD_HIT - SWORD_DROP), 0, 1), 2.2))
	# Preserve this same sword for the final royal tableau.
	for material in _vfx._sword_materials: material.set_shader_parameter("dissolve", 0.0)
	var light: float = smoothstep(REVELATION, REVELATION + 1.45, t)
	var finish: float = 1.0 if hold_revelation else 1.0 - smoothstep(DURATION - .65, DURATION, t)
	for material in _stone_materials:
		material.set_shader_parameter("fracture", smoothstep(SWORD_HIT, SWORD_HIT + .6, t))
		material.set_shader_parameter("radiance", light * finish)
		material.set_shader_parameter("growth", garden.growth)
	if not _revealed and t >= REVELATION:
		_revealed = true; sound.play()
	for i in beams.size():
		beams[i].visible = light > .001
		beam_materials[i].set_shader_parameter("strength", light * finish * (1.0 if i == 0 else .65))
		beam_materials[i].set_shader_parameter("flow", t)
	sunlight.light_energy = light * finish * 2.8; altar_light.light_energy = light * finish * .7
	# The radiance sweeps existing world dust outward, rather than masking it with a screen overlay.
	var clear: float = 1.0 - smoothstep(REVELATION + .2, REVELATION + 1.65, t)
	for i in _vfx._impact_smoke.size():
		var puff: MeshInstance3D = _vfx._impact_smoke[i]
		if not _rock_hit:
			puff.hide()
			continue
		if light > 0:
			var outward := Vector2(puff.position.x, puff.position.z).normalized()
			puff.position.x += outward.x * (t - REVELATION) * 14.0
			puff.position.z += outward.y * (t - REVELATION) * 14.0
		var alpha: float = _vfx._impact_smoke_materials[i].get_shader_parameter("opacity")
		_vfx._impact_smoke_materials[i].set_shader_parameter("opacity", alpha * clear)
		if clear <= .001: puff.hide()
	motes.visible_instance_count = 72 if light > 0 else 0
	for i in motes.visible_instance_count:
		var angle: float = i * 2.39996 + t * .45
		var radius: float = 2.0 + (i % 9) * .6
		var at := Vector3(cos(angle) * radius, 4.0 + fmod(i * .39 + t * 1.5, 25), sin(angle) * radius)
		motes.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * light * finish), at))
	for i in birds.size():
		var age: float = t - REVELATION - .5 - i * .14
		birds[i].visible = age >= 0 and age < 3.2
		birds[i].position = Vector3(-17.0 + age * 11.0, 18.0 + (i % 3) * 2.0 + sin(age * 2 + i) * .6, 5.0 + (i % 4) * 2.0)
		# The exported dove's beak points along +Z; orient that axis along its flight velocity.
		var velocity := Vector3(11.0, cos(age * 2.0 + i) * 1.2, 0.0)
		birds[i].look_at(birds[i].global_position + velocity, Vector3.UP, true)
		for wing: Node3D in birds[i].find_children("Wing*", "MeshInstance3D", true, false):
			wing.rotation.z = sin(age * 12.0 + i) * .65 * (-1.0 if wing.name.begins_with("WingLeft") else 1.0)

func stop() -> void:
	hide()
	if is_instance_valid(_vfx): _vfx.stop()
	if sound: sound.stop()
	if sunlight: sunlight.light_energy = 0
	if altar_light: altar_light.light_energy = 0
	if garden: garden.stop()
	for material in _stone_materials: material.set_shader_parameter("growth", 0.0)
	if motes: motes.visible_instance_count = 0
	for bird in birds: bird.hide()
	for beam in beams: beam.hide()

func _settle_stone_fragments(age: float) -> void:
	# Material blasted off the elevated stone falls to the arena, not an invisible plane at its top.
	for i in _vfx.debris.size():
		var transform: Transform3D = _vfx.debris[i]
		var speed: float = 8.0 if i % 8 == 0 else 3.0 + (i % 5) * .8
		transform.origin.y = maxf(.08, STONE_HEIGHT + speed * age - 5.0 * age * age)
		_vfx._debris_batch.set_instance_transform(i, transform)
	for i in _vfx._sand_batch.visible_instance_count:
		var transform: Transform3D = _vfx._sand_transforms[i]
		var angle: float = i * 2.3999632
		var radius: float = 1.2 + (12.0 + (i % 11) * 1.5) * .85 * (1.0 - exp(-age / .85))
		transform.origin = Vector3(cos(angle) * radius, maxf(.035, STONE_HEIGHT + (1.8 + (i % 9) * .55) * age - 4.9 * age * age), sin(angle) * radius)
		_vfx._sand_batch.set_instance_transform(i, transform)

func _lower_dust() -> void:
	# Both impacts roll dense dust around the foot of the stone, below its upper surface.
	for i in _vfx._impact_smoke.size():
		var puff: MeshInstance3D = _vfx._impact_smoke[i]
		puff.position.y = .8 + (i % 3) * .4 + sin(elapsed * 2.2 + i) * .15
		puff.scale.y = minf(puff.scale.y, .65 + (i % 3) * .10)
	for material in _vfx._pressure_materials:
		material.set_shader_parameter("height", .65)
