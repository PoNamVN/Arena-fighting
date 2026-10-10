class_name GiantSwordVFX
extends Node3D

const DROP_HEIGHT: float = 46.0
const CLOUD_HEIGHT: float = 42.0
const INITIAL_EMBED_DEPTH: float = 2.4
const FINAL_EMBED_DEPTH: float = 5.8
const WIND_SPEED: float = 30.0
const WIND_DRAG_SECONDS: float = 1.6
const IMPACT_HOLD_SECONDS: float = .09
const DUST_CLEAR_SECONDS: float = 4.4
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
var _cloud_material: ShaderMaterial
var _shock_material: StandardMaterial3D
var _fall_audio: AudioStreamPlayer
var _impact_audio: AudioStreamPlayer
var _impact_elapsed: float = -1.0
var _cloud_split: float = 0.0
var _radius: float = 4.5
var _burst: Node3D
var _fall_particles: GPUParticles3D
var _metal_shards: GPUParticles3D
var _wake_material: ShaderMaterial
var _impact_light: OmniLight3D
var _crater: MultiMeshInstance3D
var _crater_material: StandardMaterial3D
var _crater_batch: MultiMesh
var _chips_started: bool = false
var _cloud_layers: Array[ShaderMaterial] = []
var _cloud_time: float = 0.0
var _cloud_quality: int = 1
var _cracks: MeshInstance3D
var _crack_material: ShaderMaterial
var _fracture_radius: float = 20.0
var _impact_smoke: Array[MeshInstance3D] = []
var _impact_smoke_materials: Array[ShaderMaterial] = []
var _pressure_waves: Array[MeshInstance3D] = []
var _pressure_materials: Array[ShaderMaterial] = []
var _sand: MultiMeshInstance3D
var _sand_batch: MultiMesh
var _sand_material: StandardMaterial3D
var _burst_started: bool = false
var _floor_wave: MultiMeshInstance3D
var _floor_batch: MultiMesh
var _floor_material: StandardMaterial3D
var _floor_lifts: Array[float] = []
var _floor_planes := PackedVector4Array()
var _wind_audio: AudioStreamPlayer3D
var _wind_started: bool = false
var _sand_transforms: Array[Transform3D] = []


func _ready() -> void:
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	sword = preload("res://assets/models/knight_ultimate_sword.glb").instantiate() as Node3D
	add_child(sword)
	for mesh: MeshInstance3D in sword.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh.get_aabb().size.y > 15:
			var source: Material = mesh.get_active_material(0)
			var hero: ArrayMesh = _hero_blade()
			hero.surface_set_material(0, source if source else StandardMaterial3D.new())
			mesh.mesh = hero
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
	var wake: ArrayMesh = _airflow_mesh()
	_fall_wake.mesh = wake
	_fall_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wake_material = ShaderMaterial.new()
	_wake_material.shader = preload("res://assets/shaders/knight_ultimate_wind.gdshader")
	_fall_wake.material_override = _wake_material
	add_child(_fall_wake)
	_ring_material = _make_material(Color(1, 0.72, 0.15, 0.85), true)
	ring = _make_ring(_ring_material)
	_shock_material = _make_material(Color(.86, .83, .75, .5), true)
	shockwave = _make_ring(_shock_material)
	# Reusable billboards form a soft cloud bank with depth and an opening.
	var cloud_plane := QuadMesh.new()
	cloud_plane.size = Vector2(20, 14)
	var noise := FastNoiseLite.new()
	noise.seed = 731; noise.frequency = .035; noise.fractal_octaves = 3
	var smoke := NoiseTexture2D.new()
	smoke.width = 128; smoke.height = 128; smoke.seamless = true
	smoke.normalize = true; smoke.noise = noise
	for index in 48:
		var cloud := MeshInstance3D.new()
		cloud.mesh = cloud_plane
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/knight_ultimate_cloud.gdshader")
		material.set_shader_parameter("layer", float(index))
		material.set_shader_parameter("noise_texture", smoke)
		cloud.material_override = material
		_cloud_layers.append(material)
		add_child(cloud)
		clouds.append(cloud)
	_cloud_material = _cloud_layers[0]
	# Ground-level rolling dust is separate from the cloud bank above the sword.
	var impact_quad := QuadMesh.new()
	impact_quad.size = Vector2(7, 5)
	for index in 144:
		var puff := MeshInstance3D.new()
		puff.mesh = impact_quad
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/knight_ultimate_impact_smoke.gdshader")
		material.set_shader_parameter("noise_texture", smoke)
		material.set_shader_parameter("layer", float(index))
		puff.material_override = material
		add_child(puff)
		_impact_smoke.append(puff)
		_impact_smoke_materials.append(material)
	_build_pressure_waves(smoke)
	_sand = MultiMeshInstance3D.new()
	_sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sand_batch = MultiMesh.new()
	_sand_batch.transform_format = MultiMesh.TRANSFORM_3D
	_sand_batch.use_colors = true
	var grain := BoxMesh.new()
	grain.size = Vector3.ONE
	_sand_batch.mesh = grain
	_sand_batch.instance_count = 128
	_sand_transforms.resize(128)
	_sand_batch.visible_instance_count = 0
	_sand.multimesh = _sand_batch
	_sand_material = _make_material(Color(.6, .52, .4), false)
	_sand_material.vertex_color_use_as_albedo = true
	_sand.material_override = _sand_material
	add_child(_sand)
	var dust_material: StandardMaterial3D = _make_material(Color(0.35, 0.25, 0.14), false)
	var dust: MultiMeshInstance3D = MultiMeshInstance3D.new()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.material_override = dust_material
	_debris_batch = MultiMesh.new()
	_debris_batch.transform_format = MultiMesh.TRANSFORM_3D
	var rock: PrismMesh = PrismMesh.new()
	rock.size = Vector3.ONE
	_debris_batch.mesh = rock
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
	_wind_audio = AudioStreamPlayer3D.new()
	_wind_audio.stream = _wind_sound()
	_wind_audio.volume_db = -12.0
	_wind_audio.max_distance = 80.0
	_wind_audio.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	add_child(_wind_audio)
	_build_extras()
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
	_sigil.hide()
	_sigil.position.y = 0.07
	_sigil.scale = Vector3(radius, 1, radius)
	_sigil_material.set_shader_parameter("tint", Color(1, 0.65, 0.15) if valid else Color(1, 0.15, 0.1))
	ring.position.y = 0.08
	ring.scale = Vector3(radius, 0.2, radius)
	_ring_material.albedo_color = Color(.55, .45, .30, .65) if valid else Color(.8, .2, .1, .6)
	ring.visible = true
	sword.visible = false
	shockwave.visible = false
	visible = true


func begin(origin: Vector3, radius: float) -> void:
	stop()
	show_target(origin, radius, true)
	sword.visible = true
	sword.position.y = DROP_HEIGHT
	_burst.sample_ground(origin)
	_configure_fracture(origin)
	_chips_started = false
	_cloud_split = 0.0
	_cloud_time = 0.0
	_fall_audio.volume_db = -8.0
	for material in _cloud_layers:
		material.set_shader_parameter("opacity", .82)
		material.set_shader_parameter("origin", origin)
	for material: ShaderMaterial in _sword_materials:
		material.set_shader_parameter("dissolve", 0.0)
		material.set_shader_parameter("impact_heat", 0.0)
		material.set_shader_parameter("fall_speed", 0.0)
	_update_clouds()
	_fall_audio.play()


func _update_clouds() -> void:
	for index in clouds.size():
		var angle: float = TAU * (index / 6) / 8.0 + (index % 6) * .17
		var radius: float = 4.0 + (index % 3) * 6.5 + _cloud_split * 3.0
		clouds[index].position = Vector3(cos(angle) * radius, CLOUD_HEIGHT + (index % 6) * 5.0, sin(angle) * radius)
		clouds[index].visible = index % 2 == 0 if _cloud_quality == 0 else (index % 4 != 3 if _cloud_quality == 1 else true)
		_cloud_layers[index].set_shader_parameter("split", _cloud_split)
		_cloud_layers[index].set_shader_parameter("flow", _cloud_time)


func update_cloud_hold(delta: float) -> void:
	_cloud_time += delta
	_update_clouds()


func update_startup(remaining: float, duration: float) -> void:
	var progress: float = clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)
	sword.position.y = lerpf(DROP_HEIGHT, 0.0, pow(progress, 1.65))
	_fall_wake.visible = progress > 0.05
	_fall_wake.position.y = sword.position.y
	_wake_material.set_shader_parameter("strength", .9 * smoothstep(.05, .25, progress))
	_wake_material.set_shader_parameter("flow", progress * 4.0)
	_fall_particles.position.y = sword.position.y + 10
	_fall_particles.emitting = progress > .15
	for material in _sword_materials:
		material.set_shader_parameter("fall_speed", progress)
	_fall_wake.scale = Vector3.ONE * smoothstep(0.02, 0.2, progress)
	_cloud_split = clampf((CLOUD_HEIGHT + 2.0 - sword.position.y) / 10.0, 0.0, 1.0)
	_update_clouds()
	_update_inflow(progress)


func impact() -> void:
	_fall_wake.hide()
	_sigil.hide()
	ring.hide()
	_fall_particles.emitting = false
	_burst_started = false
	_wind_started = false
	for puff in _impact_smoke: puff.hide()
	_floor_material.albedo_color = _burst.ground_color.darkened(.12)
	_update_floor_wave(0.0)
	_crater.show()
	_cracks.show()
	_cracks.position.y = _burst.ground_y - global_position.y + .035
	_cracks.scale = Vector3(_fracture_radius, 1, _fracture_radius)
	_crack_material.set_shader_parameter("spread", 0.0)
	_crack_material.set_shader_parameter("opacity", 1.0)
	_crack_material.set_shader_parameter("ground_color", Vector3(_burst.ground_color.r, _burst.ground_color.g, _burst.ground_color.b))
	_crater_material.albedo_color = _burst.ground_color.darkened(.28)
	_sand_material.albedo_color = _burst.ground_color
	_sand_batch.visible_instance_count = [48, 88, 128][_cloud_quality]
	_impact_light.light_energy = 12.0
	_impact_light.position.y = 1.0
	sword.position.y = _burst.ground_y - global_position.y - INITIAL_EMBED_DEPTH
	_impact_elapsed = 0.0
	_fall_audio.stop()
	_impact_audio.play()
	shockwave.visible = true
	_debris_batch.visible_instance_count = 32


func update_impact(delta: float) -> void:
	if _impact_elapsed < 0:
		return
	_impact_elapsed += delta
	if not _burst_started and _impact_elapsed >= IMPACT_HOLD_SECONDS:
		_burst_started = true
		_burst.impact(global_position, _radius)
	if not _wind_started:
		var camera: Camera3D = get_viewport().get_camera_3d()
		var camera_radius: float = Vector2(camera.global_position.x - global_position.x, camera.global_position.z - global_position.z).length() if camera else 0.0
		if _impact_elapsed >= wind_arrival_time(camera_radius):
			_wind_started = true
			_wind_audio.play()
	_update_floor_wave(_impact_elapsed)
	# A hard first bite, then the weight drives the blade further into the floor.
	sword.position.y = _burst.ground_y - global_position.y - lerpf(INITIAL_EMBED_DEPTH, FINAL_EMBED_DEPTH, 1.0 - pow(1.0 - clampf((_impact_elapsed - IMPACT_HOLD_SECONDS) / .24, 0, 1), 3.0))
	_update_impact_smoke(_impact_elapsed)
	_update_pressure_waves(_impact_elapsed)
	_update_sand(_impact_elapsed)
	_impact_light.light_energy = maxf(0, 12.0 * (1.0 - _impact_elapsed / .14))
	for material in _sword_materials:
		material.set_shader_parameter("impact_heat", maxf(0, 1.0 - _impact_elapsed / .32))
	_update_crater(_impact_elapsed)
	var time: float = maxf(0.0, _impact_elapsed - IMPACT_HOLD_SECONDS)
	var wave_radius: float = wind_front_radius(_impact_elapsed)
	shockwave.position.y = 0.15
	shockwave.scale = Vector3(wave_radius, 0.15, wave_radius)
	_shock_material.albedo_color.a = maxf(0.0, 0.22 * (1.0 - time / .65))
	for material in _cloud_layers: material.set_shader_parameter("opacity", .82 * (1.0 - smoothstep(.3, 1.6, time)))
	_crack_material.set_shader_parameter("spread", smoothstep(0.0, .55, time))
	_crack_material.set_shader_parameter("opacity", 1.0 - smoothstep(3.8, 4.9, time))
	for index: int in range(debris.size()):
		var angle: float = TAU * float(index) / float(debris.size())
		var launch_speed: float = 26.0 if index % 8 == 0 else 7.0 + float(index % 7) * 1.4
		var distance: float = launch_speed * 1.2 * (1.0 - exp(-time / 1.2))
		var launch_height: float = 8.0 if index % 8 == 0 else 3.0 + float(index % 5) * .8
		var height: float = maxf(.08, launch_height * time - 5.0 * time * time)
		var position: Vector3 = Vector3(cos(angle) * distance, _burst.ground_y - global_position.y + height, sin(angle) * distance)
		var size: float = (.12 + float(index % 4) * .08) * (1.0 - smoothstep(3.7, 4.6, time))
		debris[index] = Transform3D(Basis.from_euler(Vector3(time * (index % 4), angle, time * .4)).scaled(Vector3.ONE * size), position)
		_debris_batch.set_instance_transform(index, debris[index])


func update_recovery(remaining: float, duration: float) -> void:
	# Solid during descent/impact; only dissolve once embedded in the ground.
	var time: float = maxf(_impact_elapsed, duration - remaining)
	var dissolve: float = smoothstep(3.6, 4.75, time)
	for material: ShaderMaterial in _sword_materials:
		material.set_shader_parameter("dissolve", dissolve)
	if dissolve > .01 and not _chips_started:
		_chips_started = true
		_metal_shards.position.y = 12.0
		_metal_shards.restart()
		_metal_shards.emitting = true


func stop() -> void:
	for puff in _impact_smoke: puff.hide()
	for wave in _pressure_waves: wave.hide()
	if _floor_batch: _floor_batch.visible_instance_count = 0
	if _sand_batch: _sand_batch.visible_instance_count = 0
	if _burst: _burst.stop()
	if _fall_particles: _fall_particles.emitting = false
	if _metal_shards: _metal_shards.emitting = false
	if _impact_light: _impact_light.light_energy = 0
	if _crater: _crater.hide()
	if _cracks: _cracks.hide()
	if _fall_wake:
		_fall_wake.hide()
	if _sigil:
		_sigil.hide()
	visible = false
	_impact_elapsed = -1.0
	if _wind_audio: _wind_audio.stop()
	if _fall_audio:
		_fall_audio.stop()
	if _impact_audio:
		_impact_audio.stop()
	for cloud: MeshInstance3D in clouds:
		cloud.visible = false
	if _debris_batch:
		_debris_batch.visible_instance_count = 0


static func wind_front_radius(time: float) -> float:
	return 1.2 + WIND_SPEED * WIND_DRAG_SECONDS * (1.0 - exp(-maxf(time - IMPACT_HOLD_SECONDS, 0.0) / WIND_DRAG_SECONDS))


static func dust_envelope(time: float) -> float:
	return smoothstep(IMPACT_HOLD_SECONDS, IMPACT_HOLD_SECONDS + .12, time) * (1.0 - smoothstep(2.4, DUST_CLEAR_SECONDS, time))


static func wind_arrival_time(radius: float) -> float:
	return IMPACT_HOLD_SECONDS - WIND_DRAG_SECONDS * log(clampf(1.0 - (radius - 1.2) / (WIND_SPEED * WIND_DRAG_SECONDS), .001, 1.0))


func _update_impact_smoke(time: float) -> void:
	var manager := get_node_or_null("/root/VFXManager")
	var enabled: bool = not manager or manager.enabled
	var fade: float = dust_envelope(time)
	var front: float = wind_front_radius(time)
	var settling: float = smoothstep(2.5, DUST_CLEAR_SECONDS, time)
	var ground: Color = _burst.ground_color.lerp(Color(.40, .37, .33), .65)
	for i in _impact_smoke.size():
		var row: int = i / 24
		var angle: float = TAU * (i % 24) / 24.0 + row * .11 + sin(time * 1.6 + i) * .045
		# Three dense curls follow the front; a broad wake and a rising source plume fill its interior.
		var distance: float = maxf(.8, front - row * 3.2) if row < 3 else front * [.0, .0, .0, .7, .38, .12][row]
		var rise: float = smoothstep(IMPACT_HOLD_SECONDS, 1.1, time)
		var height: float = 1.1 + rise * (1.6 + row * .5) + sin(time * 3.2 + i * 1.7) * .6 * rise
		if row == 5: height += rise * 3.5
		height = lerpf(height, .75 + row * .25, settling)
		_impact_smoke[i].position = Vector3(cos(angle) * distance, _burst.ground_y - global_position.y + height, sin(angle) * distance)
		var grow: float = .35 + smoothstep(IMPACT_HOLD_SECONDS, 1.1, time) * (2.0 + row * .16)
		_impact_smoke[i].scale = Vector3(grow, grow * (.9 + row * .06), grow)
		_impact_smoke[i].visible = enabled and fade > .001 and (i % 3 == 0 if _cloud_quality == 0 else (i % 3 != 2 if _cloud_quality == 1 else true))
		_impact_smoke_materials[i].set_shader_parameter("flow", time)
		_impact_smoke_materials[i].set_shader_parameter("opacity", fade * [.98, .95, .90, .84, .80, .86][row])
		_impact_smoke_materials[i].set_shader_parameter("turbulence", 1.0 - settling * .7)
		_impact_smoke_materials[i].set_shader_parameter("dust_color", Vector3(ground.r, ground.g, ground.b))


func _update_inflow(progress: float) -> void:
	var manager := get_node_or_null("/root/VFXManager")
	var enabled: bool = not manager or manager.enabled
	var gather: float = smoothstep(.50, 1.0, progress)
	var color: Color = _burst.ground_color.lerp(Color(.4, .37, .33), .65)
	for i in 24:
		var angle: float = TAU * i / 24.0 + gather * .5
		var radius: float = lerpf(7.0 + (i % 4) * 1.3, 1.4 + (i % 3) * .8, gather)
		_impact_smoke[i].position = Vector3(cos(angle) * radius, _burst.ground_y - global_position.y + .3 + gather * .8, sin(angle) * radius)
		_impact_smoke[i].scale = Vector3(1.0, .25 + gather * .25, 1.0) * (.4 + gather * .5)
		_impact_smoke[i].visible = enabled and gather > .001 and (i % 3 == 0 if _cloud_quality == 0 else true)
		_impact_smoke_materials[i].set_shader_parameter("opacity", gather * .45)
		_impact_smoke_materials[i].set_shader_parameter("flow", -gather * 2.0)
		_impact_smoke_materials[i].set_shader_parameter("turbulence", .6)
		_impact_smoke_materials[i].set_shader_parameter("dust_color", Vector3(color.r, color.g, color.b))
	_sand_batch.visible_instance_count = [48, 88, 128][_cloud_quality] if enabled and gather > .001 else 0
	for i in _sand_batch.visible_instance_count:
		var angle: float = i * 2.3999632 + gather * .6
		var radius: float = lerpf(3.0 + (i % 16) * .45, .6 + (i % 16) * .15, gather)
		var at := Vector3(cos(angle) * radius, _burst.ground_y - global_position.y + gather * (.15 + (i % 7) * .11), sin(angle) * radius)
		var size: float = (.035 + (i % 5) * .017) * gather
		_sand_transforms[i] = Transform3D(Basis.from_euler(Vector3(gather * i, angle, gather)).scaled(Vector3.ONE * size), at)
		_sand_batch.set_instance_transform(i, _sand_transforms[i])
	_fall_audio.volume_db = lerpf(-8.0, -18.0, gather)


func _wind_sound() -> AudioStreamWAV:
	# Filtered air rush: its playback begins when the visible front reaches the camera.
	var samples := PackedByteArray()
	var random := RandomNumberGenerator.new()
	random.seed = 1729
	var low: float = 0.0
	var slow: float = 0.0
	for i in 66150:
		var time: float = i / 22050.0
		low = lerpf(low, random.randf_range(-1.0, 1.0), .18)
		slow = lerpf(slow, low, .035)
		var envelope: float = smoothstep(0.0, .07, time) * exp(-time * 1.6) * (1.0 - smoothstep(2.4, 3.0, time))
		var sample: int = roundi(clampf((low * .65 + slow * 1.8) * envelope, -1.0, 1.0) * 32767.0)
		samples.append(sample & 255)
		samples.append((sample >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = samples
	return stream


func _build_pressure_waves(noise: Texture2D) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for sector in 96:
		for row in 8:
			for offset: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
				var u: float = (sector + offset.x) / 96.0
				var v: float = (row + offset.y) / 8.0
				vertices.append(Vector3(cos(u * TAU), 0, sin(u * TAU)))
				uvs.append(Vector2(u, v))
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for i in 3:
		var wave := MeshInstance3D.new(); wave.mesh = mesh
		wave.custom_aabb = AABB(Vector3(-60, 0, -60), Vector3(120, 16, 120))
		wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/knight_ultimate_pressure_wave.gdshader")
		material.set_shader_parameter("noise_texture", noise)
		wave.material_override = material; add_child(wave)
		_pressure_waves.append(wave); _pressure_materials.append(material)


func _update_pressure_waves(time: float) -> void:
	var manager := get_node_or_null("/root/VFXManager")
	for i in _pressure_waves.size():
		var age: float = time - i * .16
		_pressure_waves[i].visible = age > IMPACT_HOLD_SECONDS and age < 2.8 and (not manager or manager.enabled) and i <= _cloud_quality
		_pressure_waves[i].position.y = _burst.ground_y - global_position.y
		_pressure_materials[i].set_shader_parameter("radius", wind_front_radius(age))
		_pressure_materials[i].set_shader_parameter("width", 1.5 + smoothstep(0.0, 1.2, age) * 3.0)
		_pressure_materials[i].set_shader_parameter("height", .7 + smoothstep(0.0, .8, age) * 2.2)
		_pressure_materials[i].set_shader_parameter("opacity", smoothstep(0.0, .06, age) * (1.0 - smoothstep(.9, 2.8, age)))
		_pressure_materials[i].set_shader_parameter("flow", age)


func _update_sand(time: float) -> void:
	var manager := get_node_or_null("/root/VFXManager")
	_sand_batch.visible_instance_count = [48, 88, 128][_cloud_quality] if not manager or manager.enabled else 0
	for i in _sand_batch.visible_instance_count:
		var angle: float = i * 2.3999632
		# The front picks sand up from successive patches of floor, not all at once.
		var pickup_radius: float = .5 + (i % 16) * 1.05
		var age: float = maxf(0.0, time - wind_arrival_time(pickup_radius))
		var speed: float = 12.0 + (i % 11) * 1.5
		var distance: float = pickup_radius + speed * .85 * (1.0 - exp(-age / .85))
		var vertical_speed: float = 1.8 + (i % 9) * .55
		var height: float = maxf(.035, vertical_speed * age - 4.9 * age * age)
		var at := Vector3(cos(angle) * distance, _burst.ground_y - global_position.y + height, sin(angle) * distance)
		var size: float = (.025 + (i % 5) * .018) * smoothstep(0.0, .03, age) * (1.0 - smoothstep(3.2, 4.5, time))
		var basis := Basis.from_euler(Vector3(time * (i % 7), angle, time * 3.0)).scaled(Vector3(size, size * .6, size * 1.8))
		_sand_transforms[i] = Transform3D(basis, at)
		_sand_batch.set_instance_transform(i, _sand_transforms[i])
		_sand_batch.set_instance_color(i, Color.WHITE.darkened((i % 5) * .09))

func _airflow_mesh() -> ArrayMesh:
	# Six trails on each face, plus eight curling wakes around the blade edges.
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for lane in 20:
		for step in 25:
			var t: float = step / 24.0
			var centre: Vector3
			var tangent: Vector3
			if lane < 12:
				var face: float = -1.0 if lane < 6 else 1.0
				var x: float = (lane % 6 - 2.5) * .66
				centre = Vector3(x * smoothstep(0, .18, t) + sin(t*7+lane)*.13, .5+t*20.5, face*(.77+sin(t*PI)*.16))
				tangent = Vector3.RIGHT
			else:
				var angle: float = TAU * (lane-12)/8.0 + t*1.8
				var radial := Vector3(cos(angle),0,sin(angle))
				centre = radial*(2.3+t*2.1)+Vector3.UP*(t*25)
				tangent = Vector3(-sin(angle),0,cos(angle))
			for side in [-1.0,1.0]:
				vertices.append(centre+tangent*(.16 if lane<12 else .24)*side*sin(PI*t))
				uv.append(Vector2(t,0 if side<0 else 1))
				colors.append(Color(lane/20.0,0,0,1))
			if step<24:
				var i: int = lane*50+step*2
				indices.append_array(PackedInt32Array([i,i+1,i+2,i+1,i+3,i+2]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

func _particles(amount: int, shards: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new();particles.amount=amount;particles.lifetime=.65 if shards else .32
	particles.emitting=false;particles.local_coords=false;particles.fixed_fps=30;particles.one_shot=shards
	particles.visibility_aabb=AABB(Vector3(-15,-90,-15),Vector3(30,180,30));particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new();motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=Vector3(2.4,11,.5) if shards else Vector3(2.8,.1,2.8)
	motion.direction=Vector3.UP;motion.spread=50 if shards else 8;motion.gravity=Vector3(0,-3,0) if shards else Vector3.ZERO
	motion.initial_velocity_min=3 if shards else 8;motion.initial_velocity_max=6 if shards else 16
	motion.particle_flag_align_y=not shards;motion.angular_velocity_min=-120;motion.angular_velocity_max=120
	var gradient := Gradient.new();gradient.offsets=PackedFloat32Array([0,.15,.65,1]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,.7),Color(1,1,1,0)])
	var ramp := GradientTexture1D.new();ramp.gradient=gradient;motion.color_ramp=ramp;particles.process_material=motion
	var box := BoxMesh.new();box.size=Vector3(.15,.3,.06) if shards else Vector3(.02,.65,.02)
	var material := StandardMaterial3D.new();material.albedo_color=Color(.70,.73,.78,.8);material.metallic=.85 if shards else 0;material.roughness=.3
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.vertex_color_use_as_albedo=true
	if not shards:material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material=material;particles.draw_pass_1=box;add_child(particles);return particles

func _build_extras() -> void:
	_burst=preload("res://scripts/KnightUltimateBurst.gd").new();_burst.name="UltimateImpactPool";add_child(_burst)
	_fall_particles=_particles(64,false);_metal_shards=_particles(24,true)
	_impact_light=OmniLight3D.new();_impact_light.shadow_enabled=false;_impact_light.omni_range=12;_impact_light.light_color=Color(1,.84,.6);_impact_light.light_energy=0;add_child(_impact_light)
	_crater=MultiMeshInstance3D.new();_crater.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crater_batch=MultiMesh.new();_crater_batch.transform_format=MultiMesh.TRANSFORM_3D
	var slab := BoxMesh.new();slab.size=Vector3(.75,.45,1.5);_crater_batch.mesh=slab;_crater_batch.instance_count=24
	_crater.multimesh=_crater_batch;_crater_material=_make_material(Color(.45,.36,.25),false);_crater.material_override=_crater_material;add_child(_crater)
	_build_floor_wave()
	_build_cracks()
	var manager := get_node_or_null("/root/VFXManager")
	if manager:manager.quality_changed.connect(_quality_changed)
	_quality_changed(manager.quality if manager else 1)

func _quality_changed(quality: int) -> void:
	_cloud_quality = clampi(quality, 0, 2)
	if _fall_particles:_fall_particles.amount_ratio=[.5,.75,1.0][clampi(quality,0,2)]
	if _metal_shards:_metal_shards.amount_ratio=[.5,.8,1.0][clampi(quality,0,2)]

func _update_crater(time: float) -> void:
	var rise: float = smoothstep(0.0,.12,time) * (1.0-smoothstep(3.5,4.6,time))
	for i in 24:
		var angle: float = TAU*i/24.0
		var radius: float = 1.2+(i%3)*.55
		var position := Vector3(cos(angle)*radius,.06+rise*(.3+(i%4)*.1),sin(angle)*radius)
		var basis := Basis.from_euler(Vector3(rise*.35,angle,((i%3)-1)*.2*rise)).scaled(Vector3(1.0,maxf(.01,rise),1.0))
		_crater_batch.set_instance_transform(i,Transform3D(basis,position))

func active_particles() -> int:
	var count: int = _burst.active_particles() if _burst else 0
	if _fall_particles and _fall_particles.emitting:count+=roundi(_fall_particles.amount*_fall_particles.amount_ratio)
	if _metal_shards and _metal_shards.emitting:count+=roundi(_metal_shards.amount*_metal_shards.amount_ratio)
	return count

func _hero_blade() -> ArrayMesh:
	# Forged silhouette: swept shoulder, raised spine, six beveled bands and a sharp tip.
	# Built once; the existing sword remains the source of guard/grip/materials.
	var rings: Array[Vector3] = [Vector3(0,.015,.008),Vector3(2.8,1.3,.28),Vector3(5.0,1.8,.5),Vector3(16.5,1.9,.55),Vector3(18.5,2.4,.6),Vector3(19.8,2.4,.6)]
	var profile: Array[Vector2] = [Vector2(-1,0),Vector2(-.78,.3),Vector2(-.2,.85),Vector2(0,1),Vector2(.2,.85),Vector2(.78,.3),Vector2(1,0),Vector2(.78,-.3),Vector2(.2,-.85),Vector2(0,-1),Vector2(-.2,-.85),Vector2(-.78,-.3)]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for r in rings.size()-1:
		for j in profile.size():
			var k: int = (j+1)%profile.size()
			var a := Vector3(profile[j].x*rings[r].y,rings[r].x,profile[j].y*rings[r].z)
			var b := Vector3(profile[k].x*rings[r].y,rings[r].x,profile[k].y*rings[r].z)
			var c := Vector3(profile[k].x*rings[r+1].y,rings[r+1].x,profile[k].y*rings[r+1].z)
			var d := Vector3(profile[j].x*rings[r+1].y,rings[r+1].x,profile[j].y*rings[r+1].z)
			for triangle: Array in [[a,b,c],[a,c,d]]:
				var normal: Vector3 = (triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
				var center: Vector3 = (triangle[0]+triangle[1]+triangle[2])/3.0
				center.y=0
				if normal.dot(center)<0:
					normal=-normal
					vertices.append_array(PackedVector3Array([triangle[0],triangle[1],triangle[2]]))
				else:
					vertices.append_array(PackedVector3Array([triangle[0],triangle[2],triangle[1]]))
				normals.append_array(PackedVector3Array([normal,normal,normal]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
	var result := ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

func _build_cracks() -> void:
	# One reusable mesh: jagged trunks, alternating forks and cross faults.
	# Unit coordinates let measured arena size control coverage independently of damage.
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	for branch in 24:
		var angle: float = branch*TAU/24.0+sin(branch*7.13)*.025
		var last := Vector3.ZERO
		for segment in 16:
			var radius: float = (segment+1)/16.0*(1.0+.06*sin(branch*3.71))
			var a: float = angle+sin(branch*9.7+segment*3.1)*.035
			var next := Vector3(cos(a),0,sin(a))*radius
			_append_fissure(vertices,colors,last,next,lerpf(.012,.0014,clampf(radius,0,1)))
			if segment in [3,7,11]:
				var fork_last: Vector3 = next
				var side: float = -1.0 if (branch+segment)%2 else 1.0
				for twig in 3:
					var direction: float = a+side*(.55+twig*.17)
					var fork_next: Vector3 = fork_last+Vector3(cos(direction),0,sin(direction))*(.045+.025*(branch%3))
					_append_fissure(vertices,colors,fork_last,fork_next,.0035*(1-twig*.24))
					fork_last=fork_next
			if segment in [5,10] and branch%3!=0:
				var cross_angle: float = angle+TAU/24.0
				var link := Vector3(cos(cross_angle),0,sin(cross_angle))*radius
				_append_fissure(vertices,colors,next,(next+link)*.5+Vector3.UP*.001,.0026)
				_append_fissure(vertices,colors,(next+link)*.5+Vector3.UP*.001,link,.0026)
			last=next
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	var mesh := ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_cracks=MeshInstance3D.new();_cracks.mesh=mesh
	_cracks.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crack_material=ShaderMaterial.new()
	_crack_material.shader=preload("res://assets/shaders/knight_ultimate_cracks.gdshader")
	_cracks.material_override=_crack_material;add_child(_cracks)


func _append_fissure(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, width: float) -> void:
	var normal: Vector3=(b-a).normalized().cross(Vector3.UP)
	# Chipped lighter shoulders flank a dark core; all use the same surface.
	for strip in 3:
		var lo: float=[-1.6,-1.0,1.0][strip]*width
		var hi: float=[-1.0,1.0,1.6][strip]*width
		for point: Vector3 in [a+normal*lo,b+normal*lo*.7,b+normal*hi*.7,a+normal*lo,b+normal*hi*.7,a+normal*hi]:
			vertices.append(point)
			colors.append(Color(clampf(point.length()/1.2,0,1),0 if strip==1 else 1,0,1))


func _configure_fracture(origin: Vector3) -> void:
	var floor_body: Node=get_tree().root.find_child("FloorCollision",true,false)
	var center: Vector3=origin
	var area: float=PI*20.0*20.0/.75
	_crack_material.set_shader_parameter("arena_min",Vector2(-1000,-1000))
	_crack_material.set_shader_parameter("arena_max",Vector2(1000,1000))
	var planes := PackedVector4Array()
	if floor_body:
		var shape: CollisionShape3D=floor_body.find_child("CollisionShape3D",true,false) as CollisionShape3D
		if shape and shape.shape is BoxShape3D:
			var size: Vector3=shape.shape.size
			var bounds: AABB=shape.global_transform*AABB(-size*.5,size)
			center=bounds.get_center();area=bounds.size.x*bounds.size.z
			_crack_material.set_shader_parameter("arena_min",Vector2(bounds.position.x,bounds.position.z))
			_crack_material.set_shader_parameter("arena_max",Vector2(bounds.end.x,bounds.end.z))
		var walls: Node=floor_body.get_parent().get_node_or_null("PerimeterWalls")
		var apothem: float=INF
		if walls:
			for wall: CollisionShape3D in walls.get_children():
				if not wall.shape is BoxShape3D or planes.size()==8:continue
				var normal: Vector3=wall.global_basis.z.normalized()
				if normal.dot(wall.global_position-center)<0:normal=-normal
				var distance: float=normal.dot(wall.global_position)-wall.shape.size.z*.5*wall.global_basis.z.length()-.15
				planes.append(Vector4(normal.x,normal.y,normal.z,distance))
				apothem=minf(apothem,distance-normal.dot(center))
			if planes.size()==8:area=8.0*apothem*apothem*tan(PI/8.0)
	_crack_material.set_shader_parameter("plane_count",planes.size())
	_floor_planes = planes.duplicate()
	planes.resize(8);_crack_material.set_shader_parameter("arena_planes",planes)
	var offset: float=Vector2(origin.x-center.x,origin.z-center.z).length()
	_fracture_radius=sqrt(area*.75/PI)+offset*.55


func _build_floor_wave() -> void:
	_floor_wave = MultiMeshInstance3D.new()
	_floor_wave.name = "ImpactFloorWave"
	_floor_wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_floor_batch = MultiMesh.new()
	_floor_batch.transform_format = MultiMesh.TRANSFORM_3D
	_floor_batch.use_colors = true
	var slab := BoxMesh.new()
	slab.size = Vector3.ONE
	_floor_batch.mesh = slab
	_floor_batch.instance_count = 192
	_floor_batch.visible_instance_count = 0
	_floor_wave.multimesh = _floor_batch
	_floor_material = _make_material(Color(.45, .43, .39), false)
	_floor_material.vertex_color_use_as_albedo = true
	_floor_wave.material_override = _floor_material
	_floor_lifts.resize(192)
	add_child(_floor_wave)


func _update_floor_wave(time: float) -> void:
	var manager := get_node_or_null("/root/VFXManager")
	_floor_batch.visible_instance_count = 192 if not manager or manager.enabled else 0
	var stride: int = [3, 2, 1][_cloud_quality]
	var minimum: Vector2 = _crack_material.get_shader_parameter("arena_min")
	var maximum: Vector2 = _crack_material.get_shader_parameter("arena_max")
	for i in _floor_batch.visible_instance_count:
		var band: int = i / 32
		var radius: float = 2.0 + band * 2.0
		var angle: float = TAU * (i % 32) / 32.0 + band * .055
		var local := Vector3(cos(angle) * radius, _burst.ground_y - global_position.y, sin(angle) * radius)
		var world: Vector3 = global_position + local
		var inside: bool = world.x > minimum.x + .8 and world.x < maximum.x - .8 and world.z > minimum.y + .8 and world.z < maximum.y - .8
		for plane in _floor_planes:
			inside = inside and Vector3(plane.x, plane.y, plane.z).dot(world) < plane.w - .8
		var age: float = time - wind_arrival_time(radius)
		var phase: float = clampf(age / .52, 0.0, 1.0)
		var lift: float = sin(phase * PI) * (.6 + (i % 5) * .12)
		_floor_lifts[i] = lift if inside else 0.0
		# Slabs appear as the floor breaks, rise under the front, then settle under its wake.
		var reveal: float = smoothstep(0.0, .045, age) * (1.0 - smoothstep(3.4, 4.5, time))
		var size: float = reveal if inside and i % stride == 0 else 0.0
		local.y += .015 + lift
		var basis := Basis.from_euler(Vector3(lift * .35, -angle, sin(i * 2.7) * lift * .25))
		basis = basis.scaled(Vector3(1.35, .12 + lift * .2, .25 + radius * .12) * size)
		_floor_batch.set_instance_transform(i, Transform3D(basis, local))
		_floor_batch.set_instance_color(i, Color.WHITE.darkened((i % 7) * .025))
