class_name WizardStormUltimate
extends Node

enum Phase { IDLE, AIM, CHANNEL }
const TARGET_RANGE: float = 24.0
const RADIUS: float = 7.0
const STRIKE_RADIUS: float = 2.0
const DURATION: float = 5.0
const WEATHER_FADE: float = 1.0
var _bolt_mesh: CylinderMesh
var _bolt_core_material: StandardMaterial3D
var _bolt_halo_material: StandardMaterial3D
var kit: WizardCombat
var actor: PlayerController
var phase: Phase = Phase.IDLE
var elapsed: float = 0.0
var ground: Vector3
var target_valid: bool = false
var camera: Camera3D
var shield: MeshInstance3D
var ring: MeshInstance3D
var weather: Node3D
var strikes: Array[Dictionary] = []
var strikes_spawned: int = 0
var strikes_landed: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _previous_camera: Camera3D
var _previous_capture: bool
var _previous_mode: int
var _camera_start: Transform3D
var _camera_goal: Transform3D
var _entry_frame: int
var _click_armed: bool
var _world: WorldEnvironment
var _original_environment: Environment
var _dark_environment: Environment
var _light: DirectionalLight3D
var _original_energy: float

func _ready() -> void:
	rng.randomize()
	actor = kit.actor
	_bolt_mesh = CylinderMesh.new()
	_bolt_mesh.top_radius = 0.055
	_bolt_mesh.bottom_radius = 0.085
	_bolt_mesh.height = 1
	_bolt_mesh.radial_segments = 6
	_bolt_core_material = kit._material(Color(0.8, 0.9, 1))
	_bolt_halo_material = kit._material(Color(0.25, 0.5, 1, 0.22))
	_bolt_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	camera = Camera3D.new()
	add_child(camera)
	camera.top_level = true
	camera.far = 200
	ring = _ring(RADIUS, Color(0.4, 0.65, 1))
	actor.add_child(ring)
	ring.top_level = true
	ring.hide()

func active() -> bool:
	return phase != Phase.IDLE

func channeling() -> bool:
	return phase == Phase.CHANNEL

func begin() -> bool:
	if active() or not kit._can_spell() or not actor.ability_system.can_cast("ultimate"):
		return false
	phase = Phase.AIM
	elapsed = 0
	target_valid = false
	_entry_frame = Engine.get_physics_frames()
	_click_armed = not Input.is_action_pressed("attack")
	_previous_capture = actor._is_mouse_captured
	_previous_mode = Input.mouse_mode
	_previous_camera = actor.get_viewport().get_camera_3d()
	_camera_start = _previous_camera.global_transform if _previous_camera else actor.camera.global_transform
	var back: Vector3 = Basis(Vector3.UP, actor._camera_yaw).z
	camera.global_position = actor.global_position + back * 14 + Vector3.UP * 16
	camera.look_at(actor.global_position - back * 6)
	_camera_goal = camera.global_transform
	camera.global_transform = _camera_start
	camera.make_current()
	actor._is_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true

func handle_input(event: InputEvent) -> void:
	if channeling() and event.is_action_pressed("ui_cancel"):
		_previous_capture = false
		_previous_mode = Input.MOUSE_MODE_VISIBLE
		return
	if phase != Phase.AIM:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		stop()
		return
	if event.is_action_released("attack"):
		_click_armed = true
	if event.is_action_pressed("attack") and not event.is_echo() and _click_armed and elapsed >= 0.35 and Engine.get_physics_frames() > _entry_frame:
		var point: Vector2 = event.position if event is InputEventMouseButton else actor.get_viewport().get_mouse_position()
		update_target(point)
		if target_valid:
			confirm(ground)

func valid_ground(point: Vector3) -> bool:
	var offset: Vector3 = point - actor.global_position
	if Vector2(offset.x, offset.z).length() > TARGET_RANGE or absf(offset.y) > 8:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.25, point - Vector3.UP, 1)
	query.exclude = [actor.get_rid()]
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.7:
		return false
	var sight: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.35, point + Vector3.UP * 0.12, 1)
	sight.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty()

func update_target(point: Vector2) -> void:
	var from: Vector3 = camera.project_ray_origin(point)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + camera.project_ray_normal(point) * 200, 1)
	query.exclude = [actor.get_rid()]
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	target_valid = not hit.is_empty() and hit.normal.y >= 0.7
	if not hit.is_empty():
		ground = hit.position
	if target_valid:
		target_valid = valid_ground(ground)
	ring.visible = not hit.is_empty()
	ring.global_position = ground + Vector3.UP * 0.07
	(ring.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.4, 0.65, 1) if target_valid else Color(1, 0.15, 0.1))

func confirm(point: Vector3) -> bool:
	if phase != Phase.AIM or elapsed < 0.35 or not valid_ground(point) or not actor.ability_system.cast_ability("ultimate"):
		return false
	phase = Phase.CHANNEL
	elapsed = 0
	ground = point
	strikes_spawned = 0
	strikes_landed = 0
	actor.health_component.ability_invulnerable = true
	shield = kit._sphere(1.4, Color(0.2, 0.6, 1, 0.25))
	actor.add_child(shield)
	shield.position.y = 1.05
	shield.scale.y = 1.05
	for axis: int in range(3):
		var rune: MeshInstance3D = _ring(1.42, Color(0.45, 0.85, 1))
		shield.add_child(rune)
		rune.rotation = Vector3(PI / 2 if axis == 0 else 0, 0, PI / 2 if axis == 2 else 0)
	ring.show()
	(ring.material_override as ShaderMaterial).set_shader_parameter("tint", Color(0.4, 0.65, 1))
	ring.global_position = ground + Vector3.UP * 0.07
	_weather()
	return true

func _ring(radius: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2.ONE * radius * 2 / 0.9
	node.mesh = mesh
	node.material_override = preload("res://scripts/CombatSpectacle.gd").sigil_material(color, 1 if radius>1.5 and radius<3 else 0)
	(node.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.24 if radius <= 1.5 else 0.4 if radius >= 3 else 0.6)
	return node

func _weather() -> void:
	var worlds: Array[Node] = actor.get_parent().find_children("*", "WorldEnvironment", true, false)
	if not worlds.is_empty():
		_world = worlds[0] as WorldEnvironment
		_original_environment = _world.environment
		if _original_environment:
			_dark_environment = _original_environment.duplicate() as Environment
			_world.environment = _dark_environment
	var lights: Array[Node] = actor.get_parent().find_children("*", "DirectionalLight3D", true, false)
	if not lights.is_empty():
		_light = lights[0] as DirectionalLight3D
		_original_energy = _light.light_energy
	weather = Node3D.new()
	actor.add_child(weather)
	weather.top_level = true
	weather.global_position = ground + Vector3.UP * 12
	for i: int in range(16):
		var cloud: MeshInstance3D = kit._sphere(1, Color(0.09, 0.11, 0.16, 0))
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weather.add_child(cloud)
		var angle: float = TAU * i / 16.0
		cloud.position = Vector3(cos(angle) * 5, rng.randf_range(-0.5, 0.5), sin(angle) * 5)
		cloud.scale = Vector3(4, 1.1, 3)
	_update_weather()

func _update_weather() -> void:
	# Fade at both ends of the channel, reaching the original lighting before cleanup.
	var weight: float = minf(smoothstep(0, WEATHER_FADE, elapsed), smoothstep(0, WEATHER_FADE, DURATION - elapsed))
	if is_instance_valid(_world) and _world.environment == _dark_environment:
		_dark_environment.background_energy_multiplier = lerpf(_original_environment.background_energy_multiplier, 0.08, weight)
		_dark_environment.background_color = _original_environment.background_color.lerp(Color(0.025, 0.035, 0.065), weight)
		_dark_environment.ambient_light_energy = lerpf(_original_environment.ambient_light_energy, 0.35, weight)
	if is_instance_valid(_light):
		_light.light_energy = lerpf(_original_energy, 0.35, weight)
	if is_instance_valid(weather):
		for cloud: MeshInstance3D in weather.get_children():
			var material: StandardMaterial3D = cloud.material_override as StandardMaterial3D
			material.albedo_color.a = weight

func _physics_process(delta: float) -> void:
	if not active():
		return
	if actor.is_dead or not actor.controls_enabled or actor.is_control_impaired():
		stop()
		return
	elapsed += delta
	if phase == Phase.AIM:
		camera.global_transform = _camera_start.interpolate_with(_camera_goal, smoothstep(0, 0.35, elapsed))
		update_target(actor.get_viewport().get_mouse_position())
		if elapsed >= 8:
			stop()
		return
	_update_weather()
	shield.rotation.y += delta * 0.7
	while strikes_spawned < 20 and elapsed >= 0.1 + strikes_spawned * 0.24:
		_schedule()
		strikes_spawned += 1
	for i: int in range(strikes.size() - 1, -1, -1):
		var strike: Dictionary = strikes[i]
		if not strike.hit and elapsed >= strike.time:
			strike.hit = true
			_bolt(strike)
			_damage_at(strike.point)
			if not channeling():
				return
		if strike.hit and elapsed >= strike.time + 0.18:
			strike.node.queue_free()
			strikes.remove_at(i)
	if elapsed >= DURATION:
		stop()

func _schedule() -> void:
	# Stratified disk samples remain random while spreading pressure across the zone.
	var angle: float = float(strikes_spawned) * 2.399963 + rng.randf_range(-0.3, 0.3)
	var radius: float = sqrt((float(strikes_spawned % 5) + rng.randf()) / 5) * (RADIUS - 0.1)
	var point: Vector3 = ground + Vector3(cos(angle), 0, sin(angle)) * radius
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 20, point - Vector3.UP * 8, 1)
	ray.exclude = [actor.get_rid()]
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.7 or absf(hit.position.y - ground.y) > 8:
		return
	point = hit.position
	var marker: MeshInstance3D = _ring(STRIKE_RADIUS, Color(0.75, 0.6, 1))
	actor.add_child(marker)
	marker.top_level = true
	marker.global_position = point + Vector3.UP * 0.07
	strikes.append({"point": point, "node": marker, "time": 0.1 + strikes_spawned * 0.24 + 0.32, "hit": false})

func _bolt(strike: Dictionary) -> void:
	strikes_landed += 1
	if actor.spectacle:
		actor.spectacle.burst(strike.point, Color(0.35, 0.6, 1), 2.1, 0.9)
	var parent: Node3D = strike.node
	var core: MultiMesh = _bolt_batch(parent, _bolt_core_material)
	var halo: MultiMesh = _bolt_batch(parent, _bolt_halo_material)
	var last: Vector3 = Vector3(0, 12, 0)
	for i: int in range(12):
		var next: Vector3 = Vector3(rng.randf_range(-0.45, 0.45), 11 - i, rng.randf_range(-0.45, 0.45)) if i < 11 else Vector3.ZERO
		var basis: Basis = Basis(Quaternion(Vector3.UP, (last-next).normalized()))
		var length: float = last.distance_to(next)
		core.set_instance_transform(i, Transform3D(basis * Basis.from_scale(Vector3(1, length, 1)), (last+next)/2))
		halo.set_instance_transform(i, Transform3D(basis * Basis.from_scale(Vector3(3.5, length, 3.5)), (last+next)/2))
		last = next
	var flash: OmniLight3D = OmniLight3D.new()
	parent.add_child(flash)
	flash.position.y = 2
	flash.omni_range = 7
	flash.light_energy = 2
	kit._release_sound.stream = preload("res://assets/audio/wizard_storm_thunder.wav")
	kit._release_sound.pitch_scale = rng.randf_range(0.8, 1.1)
	kit._release_sound.play()

func _bolt_batch(parent: Node3D, material: Material) -> MultiMesh:
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = material
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _bolt_mesh
	batch.instance_count = 12
	node.multimesh = batch
	parent.add_child(node)
	return batch

func _damage_at(point: Vector3) -> void:
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = STRIKE_RADIUS
	shape.height = 3
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point + Vector3.UP * 1.4
	query.collision_mask = actor.combat.target_collision_mask
	query.exclude = [actor.get_rid()]
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target: Node3D = hit.collider as Node3D
		var sight: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 12, target.global_position + Vector3.UP, 1)
		sight.exclude = [actor.get_rid(), (target as CollisionObject3D).get_rid()]
		if actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			kit._impact(target, 24, point + Vector3.UP * 12, target.global_position + Vector3.UP, false, 20)
		if not channeling():
			return

func stop() -> void:
	if not active():
		return
	phase = Phase.IDLE
	if is_instance_valid(actor.health_component):
		actor.health_component.ability_invulnerable = false
	if is_instance_valid(shield):
		shield.queue_free()
	shield = null
	for strike: Dictionary in strikes:
		strike.node.queue_free()
	strikes.clear()
	if is_instance_valid(weather):
		weather.queue_free()
	weather = null
	if is_instance_valid(_world) and _world.environment == _dark_environment:
		_world.environment = _original_environment
	if is_instance_valid(_light):
		_light.light_energy = _original_energy
	_world = null
	_light = null
	ring.hide()
	if camera.current:
		if is_instance_valid(_previous_camera):
			_previous_camera.make_current()
		else:
			actor.camera.make_current()
		actor._is_mouse_captured = _previous_capture
		Input.mouse_mode = _previous_mode
	kit.recovery_remaining = maxf(kit.recovery_remaining, 0.4)
	if is_instance_valid(kit._release_sound):
		kit._release_sound.stop()

func _exit_tree() -> void:
	stop()
