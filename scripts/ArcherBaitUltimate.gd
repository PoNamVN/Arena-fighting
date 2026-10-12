class_name ArcherBaitUltimate
extends Node

enum Phase { IDLE, AIM, FLIGHT, LURE, CHASE, BITE, LEAVE }
const TARGET_RANGE: float = 24.0
const TAG_RADIUS: float = 2.2
const TREX_SCALE: float = 1.6
const MOUTH_REACH: float = 4.4
var actor: PlayerController
var phase: Phase = Phase.IDLE
var timer: float = 0.0
var elapsed: float = 0.0
var target_valid: bool = false
var ground: Vector3 = Vector3.ZERO
var tagged: Node3D
var bite_count: int = 0
var damage_attempts: int = 0
var casts: int = 0
var camera: Camera3D
var _previous_camera: Camera3D
var _previous_capture: bool = true
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED
var _camera_start: Transform3D
var _camera_goal: Transform3D
var _click_armed: bool = true
var _entry_frame: int = -1
var _origin: Vector3
var _direction: Vector3
var _bait: Node3D
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _dino: CharacterBody3D
var _model: Node3D
var _head: Node3D
var _jaw: Node3D
var _legs: Array[Node3D] = []
var _tail: Node3D
var _bite_origin: Vector3
var _miss: bool = false
var _roar: AudioStreamPlayer3D
var _crunch: AudioStreamPlayer3D
var _dust: CPUParticles3D
var _showcase: bool = false
var _showcase_elapsed: float = 0.0
var _showcase_start: Transform3D
var _fade_surfaces: Array[Dictionary] = []

func _ready() -> void:
	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 70.0
	camera.far = 250.0
	add_child(camera)
	_ring = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = TAG_RADIUS - 0.07
	ring.outer_radius = TAG_RADIUS
	ring.rings = 48
	ring.ring_segments = 6
	_ring.mesh = ring
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = Color(1.0, 0.52, 0.13)
	_ring.material_override = _ring_material
	_ring.scale.y = 0.25
	_ring.top_level = true
	actor.add_child(_ring)
	_ring.hide()
	_roar = AudioStreamPlayer3D.new()
	_roar.stream = preload("res://assets/audio/trex_roar.wav")
	_roar.volume_db = -8
	actor.add_child(_roar)
	_crunch = AudioStreamPlayer3D.new()
	_crunch.stream = preload("res://assets/audio/trex_bite.wav")
	_crunch.volume_db = -10
	actor.add_child(_crunch)
	_dust = CPUParticles3D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 55
	_dust.lifetime = 1.0
	_dust.explosiveness = 0.92
	_dust.direction = Vector3.UP
	_dust.spread = 85.0
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 6.5
	_dust.gravity = Vector3(0, -8, 0)
	_dust.scale_amount_min = 0.18
	_dust.scale_amount_max = 0.55
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radial_segments = 6
	mesh.rings = 3
	_dust.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.48, 0.25)
	_dust.material_override = material
	actor.add_child(_dust)
	_dust.top_level = true

func input_busy() -> bool:
	return phase in [Phase.AIM, Phase.FLIGHT]

func active() -> bool:
	return phase != Phase.IDLE

func begin() -> bool:
	if active() or not actor.archer_combat._can_skill() or not actor.ability_system.can_cast("ultimate"):
		return false
	_showcase = false
	phase = Phase.AIM
	elapsed = 0.0
	target_valid = false
	_entry_frame = Engine.get_physics_frames()
	_click_armed = not Input.is_action_pressed("attack")
	_previous_capture = actor._is_mouse_captured
	_previous_mouse_mode = Input.mouse_mode
	_previous_camera = actor.get_viewport().get_camera_3d()
	_camera_start = _previous_camera.global_transform if _previous_camera else actor.camera.global_transform
	var back: Vector3 = Basis(Vector3.UP,actor._camera_yaw).z
	camera.global_position = actor.global_position + back * 13.0 + Vector3.UP * 14.0
	camera.look_at(actor.global_position - back * 6.0)
	_camera_goal = camera.global_transform
	camera.global_transform = _camera_start
	camera.make_current()
	actor._is_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true

func handle_input(event: InputEvent) -> void:
	if phase != Phase.AIM:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		stop()
		return
	if event.is_action_released("attack"):
		_click_armed = true
	if event.is_action_pressed("attack") and not event.is_echo() and _click_armed and elapsed >= 0.35 and Engine.get_physics_frames() > _entry_frame:
		var position: Vector2 = event.position if event is InputEventMouseButton else actor.get_viewport().get_mouse_position()
		update_target(position)
		if target_valid:
			confirm(ground)

func valid_ground(point: Vector3) -> bool:
	var offset: Vector3 = point - actor.global_position
	if Vector2(offset.x, offset.z).length() > TARGET_RANGE or absf(offset.y) > 4.0:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.25, point - Vector3.UP, 1)
	query.exclude = [actor.get_rid()]
	var floor_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	if floor_hit.is_empty() or floor_hit.normal.y < 0.7:
		return false
	var sight: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 1.35, point + Vector3.UP * 0.12, 1)
	sight.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(sight).is_empty()

func update_target(position: Vector2) -> void:
	var start: Vector3 = camera.project_ray_origin(position)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start,start+camera.project_ray_normal(position)*250.0,1)
	query.exclude = [actor.get_rid()]
	var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
	target_valid = not hit.is_empty() and hit.normal.y >= 0.7
	if target_valid:
		ground = hit.position
		target_valid = valid_ground(ground)
	_ring.visible = not hit.is_empty()
	_ring.global_position = ground + Vector3.UP * 0.07
	_ring_material.albedo_color = Color(1,0.52,0.13) if target_valid else Color(0.9,0.1,0.08)

func confirm(point: Vector3) -> bool:
	if phase != Phase.AIM or elapsed < 0.35 or not valid_ground(point) or not actor.ability_system.cast_ability("ultimate"):
		return false
	ground = point
	_origin = actor.global_position + Vector3.UP * 1.35
	_direction = Vector3(ground.x-_origin.x,0,ground.z-_origin.z).normalized()
	if _direction.length_squared() < 0.01:
		_direction = actor.get_facing_direction()
	_bait = preload("res://assets/models/hunter_bait.glb").instantiate() as Node3D
	actor.add_child(_bait)
	_bait.top_level = true
	_bait.global_position = _origin
	_ring.show()
	_ring.global_position = ground + Vector3.UP * 0.07
	phase = Phase.FLIGHT
	timer = 0.50
	casts += 1
	bite_count = 0
	damage_attempts = 0
	tagged = null
	_miss = false
	return true

func _restore_camera() -> void:
	if camera.current:
		if is_instance_valid(_previous_camera):
			_previous_camera.make_current()
		elif actor.camera:
			actor.camera.make_current()
		if not _showcase:
			actor._is_mouse_captured = _previous_capture
			Input.mouse_mode = _previous_mouse_mode

func _target_alive(target: Variant) -> bool:
	return is_instance_valid(target) and target != actor and target is CollisionObject3D and (target is PlayerController or target is TrainingDummy) and (target as CollisionObject3D).collision_layer & actor.combat.target_collision_mask != 0 and not (target is PlayerController and target.is_dead) and not (target is TrainingDummy and target.is_dead())

func _clear_sight(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from,to,1)
	query.exclude = [actor.get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _find_tag() -> void:
	if is_instance_valid(tagged):
		return
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = TAG_RADIUS
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = ground + Vector3.UP * 0.8
	query.collision_mask = actor.combat.target_collision_mask
	query.exclude = [actor.get_rid()]
	var nearest: float = INF
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query,32):
		var candidate: Node3D = hit.collider as Node3D
		if not _target_alive(candidate) or (candidate is PlayerController and candidate.is_in_dodge_iframe()):
			continue
		var flat: Vector3 = candidate.global_position-ground
		flat.y = 0
		if flat.length() <= TAG_RADIUS and absf(candidate.global_position.y-ground.y) < 2.0 and flat.length_squared() < nearest and _clear_sight(ground+Vector3.UP*0.6,candidate.global_position+Vector3.UP*0.9):
			nearest = flat.length_squared()
			tagged = candidate
	if is_instance_valid(tagged):
		_ring_material.albedo_color = Color(1,0.17,0.08)

func _spawn_trex() -> void:
	_dino = CharacterBody3D.new()
	_dino.name = "SummonedForestTrex"
	_dino.collision_layer = 0
	_dino.collision_mask = 1
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 1.1
	capsule.height = 3.0
	shape.shape = capsule
	shape.position.y = 1.55
	_dino.add_child(shape)
	_model = preload("res://assets/models/forest_trex.glb").instantiate() as Node3D
	_model.rotation.y = PI
	_model.scale = Vector3.ONE * TREX_SCALE
	_dino.add_child(_model)
	actor.add_child(_dino)
	_dino.top_level = true
	var goal: Vector3 = tagged.global_position if _target_alive(tagged) else ground
	var entry: Vector3 = goal - _direction * (MOUTH_REACH+8.0)
	var sweep: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(goal+Vector3.UP,entry+Vector3.UP,1)
	sweep.exclude = [actor.get_rid()]
	var obstruction: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(sweep)
	if not obstruction.is_empty():
		entry = obstruction.position + _direction * 1.3
		entry.y = ground.y
	var floor_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(entry+Vector3.UP*6,entry-Vector3.UP*8,1)
	var floor_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(floor_ray)
	if not floor_hit.is_empty():
		entry.y = floor_hit.position.y + 0.05
	_dino.global_position = entry
	_dino.look_at(entry+_direction)
	_head = _model.find_child("Head",true,false) as Node3D
	_jaw = _model.find_child("Jaw",true,false) as Node3D
	_tail = _model.find_child("Tail",true,false) as Node3D
	_legs = [_model.find_child("LegL",true,false) as Node3D,_model.find_child("LegR",true,false) as Node3D]
	_cache_fade(_model)
	_roar.global_position = entry + Vector3.UP*3
	_roar.play()
	if actor.spectacle:
		actor.spectacle.burst(entry, Color(0.4, 1, 0.35), 4, 1.5)
	_dust.global_position = entry
	_dust.restart()
	_trigger_quake_shockwave(entry)
	_showcase_start = actor.get_viewport().get_camera_3d().global_transform
	_showcase_elapsed = 0.0
	_showcase = true
	camera.global_transform = _showcase_start
	camera.make_current()
	phase = Phase.CHASE
	timer = 3.5

func _update_showcase(delta: float) -> void:
	if not _showcase or not is_instance_valid(_dino):
		return
	_showcase_elapsed += delta
	var center: Vector3 = (actor.global_position + _dino.global_position) * 0.5 + Vector3.UP * 2.5
	var yaw: Basis = Basis(Vector3.UP,actor._camera_yaw)
	camera.global_position = center + yaw.z * 18.0 + yaw.x * 10.0 + Vector3.UP * 11.0
	camera.look_at(center)
	var goal: Transform3D = camera.global_transform
	if phase == Phase.LEAVE and timer < 0.45 and is_instance_valid(_previous_camera):
		goal = goal.interpolate_with(_previous_camera.global_transform,smoothstep(0,1,1-timer/0.45))
	camera.global_transform = _showcase_start.interpolate_with(goal,smoothstep(0,1,minf(1,_showcase_elapsed/0.4)))
	# Gentle non-accumulating impact shake while the jaw closes.
	camera.h_offset = sin(elapsed*65)*0.09 if phase == Phase.BITE else 0.0
	camera.v_offset = cos(elapsed*51)*0.05 if phase == Phase.BITE else 0.0

func _cache_fade(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for index: int in range(node.mesh.get_surface_count()):
			var original: Material = node.get_active_material(index)
			if original is StandardMaterial3D:
				var faded: StandardMaterial3D = original.duplicate() as StandardMaterial3D
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				node.set_surface_override_material(index,faded)
				_fade_surfaces.append({"material":faded})
	for child: Node in node.get_children():
		_cache_fade(child)

func _bite() -> void:
	if actor.spectacle:
		actor.spectacle.burst(ground, Color(1, 0.6, 0.18), 3.5, 1.4)
	bite_count += 1
	_crunch.global_position = ground + Vector3.UP
	_crunch.play()
	_dust.global_position = ground
	_dust.restart()
	_trigger_quake_shockwave(ground)
	if not _target_alive(tagged):
		return
	var point: Vector3 = tagged.global_position+Vector3.UP*0.9
	if point.distance_to(_bite_origin) > 2.6 or not _clear_sight(_bite_origin,point):
		return
	damage_attempts += 1
	if tagged is PlayerController:
		var payload: AttackPayload = AttackPayload.new(30.0,_bite_origin,30.0,true)
		payload.attacker = actor
		tagged.take_damage(payload,_bite_origin)
	else:
		var blocked: bool = tagged.is_blocking and not tagged.is_shield_broken and actor.combat.is_attack_inside_block_cone(tagged,_bite_origin,tagged.block_cone_deg)
		tagged.take_damage(30.0*(1.0-tagged.block_damage_reduction) if blocked else 30.0,_bite_origin,blocked)
		if blocked:
			tagged.apply_shield_damage(30.0)
	if actor.combat_feedback:
		actor.combat_feedback.trigger_ultimate_feedback()
	actor.combat.trigger_hit_impact(point,-_direction)

func _physics_process(delta: float) -> void:
	if not active():
		return
	if actor.is_dead or not actor.controls_enabled:
		stop()
		return
	elapsed += delta
	if _ring and _ring.visible:
		_ring.rotate_y(delta * 1.6)
	if phase == Phase.AIM:
		camera.global_transform = _camera_start.interpolate_with(_camera_goal,smoothstep(0,1,minf(1,elapsed/0.35)))
		if not Input.is_action_pressed("attack"):
			_click_armed = true
		update_target(actor.get_viewport().get_mouse_position())
		if elapsed > 8.0:
			stop()
		return
	timer = maxf(0.0,timer-delta)
	if phase == Phase.FLIGHT:
		var t: float = 1.0-timer/0.5
		var to: Vector3 = _origin.lerp(ground+Vector3.UP*0.18,t)+Vector3.UP*sin(t*PI)*3.0
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(_bait.global_position,to,1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			ground = hit.position
			to = ground+Vector3.UP*0.18
			timer = 0.0
		_bait.global_position = to
		_bait.rotation.z += delta*8
		if timer <= 0.0:
			_bait.rotation = Vector3.ZERO
			_restore_camera()
			phase = Phase.LURE
			timer = 0.8
	elif phase == Phase.LURE:
		_find_tag()
		if timer <= 0.0:
			_miss = not _target_alive(tagged)
			_spawn_trex()
	elif phase == Phase.CHASE:
		if not _target_alive(tagged):
			tagged = null
			_miss = true
		var goal: Vector3 = tagged.global_position if _target_alive(tagged) else ground
		var offset: Vector3 = goal-_dino.global_position
		offset.y = 0
		var direction: Vector3 = offset.normalized()
		if direction.length_squared() > 0.01:
			_dino.rotation.y = lerp_angle(_dino.rotation.y,atan2(-direction.x,-direction.z),minf(1.0,delta*6.0))
		var travel: float = maxf(0.0,offset.length()-MOUTH_REACH)
		_dino.velocity = direction * minf(14.0,travel/maxf(delta,0.001))
		_dino.velocity.y = -4.0
		_dino.move_and_slide()
		var stride: float = sin(elapsed*16)*0.45
		for index: int in range(_legs.size()):
			_legs[index].rotation.x = stride*(1 if index==0 else -1)
		_tail.rotation.y = sin(elapsed*8)*0.12
		_model.position.y = absf(sin(elapsed*16))*0.12
		_jaw.rotation.x = 0.35
		if travel < 0.25 and _clear_sight(_dino.global_position+Vector3.UP,goal+Vector3.UP*0.9):
			phase = Phase.BITE
			timer = 1.15
			_bite_origin = _dino.global_position - _dino.global_basis.z * (MOUTH_REACH-1.0) + Vector3.UP*0.9
			ground = goal
		elif timer <= 0:
			phase = Phase.LEAVE
			timer = 1.2
	elif phase == Phase.BITE:
		var progress: float = 1.15-timer
		var crouch: float = smoothstep(0,0.35,progress)
		_model.rotation.x = 0.72*crouch
		_model.position = Vector3(0,0.10,3.5*crouch)
		for leg: Node3D in _legs:
			leg.rotation.x = -0.72*crouch
		_jaw.rotation.x = 0.08 + pow(sin((progress - 0.42) * PI / 0.24), 2) * 0.8
		_model.position.y = 0.10 - maxf(0, cos((progress - 0.42) * TAU / 0.24)) * 0.08
		while bite_count < 3 and progress >= 0.42 + float(bite_count)*0.24:
			_bite()
			if phase != Phase.BITE:
				return
		if timer <= 0:
			if is_instance_valid(_bait):
				_bait.hide()
			_ring.hide()
			phase = Phase.LEAVE
			timer = 1.2
	elif phase == Phase.LEAVE:
		_dino.velocity = -_direction*8
		_dino.velocity.y = -4
		_dino.move_and_slide()
		_dino.rotation.y = lerp_angle(_dino.rotation.y,atan2(_direction.x,_direction.z),minf(1,delta*6))
		for surface: Dictionary in _fade_surfaces:
			surface.material.albedo_color.a = clampf(timer/0.7,0.0,1.0)
		_model.rotation.x = move_toward(_model.rotation.x,0.0,delta*2)
		_model.position.z = move_toward(_model.position.z,0.0,delta*5)
		for index: int in range(_legs.size()):
			_legs[index].rotation.x = sin(elapsed*16)*0.4*(1 if index==0 else -1)
		if timer <= 0:
			stop()
	if _target_alive(tagged) and phase in [Phase.LURE,Phase.CHASE,Phase.BITE]:
		_bait.global_position = tagged.global_position + Vector3(0,1.1,0)
		_ring.global_position = tagged.global_position + Vector3.UP*0.07
	else:
		_ring.global_position = ground+Vector3.UP*0.07
	_update_showcase(delta)
	_ring.scale = Vector3(1+sin(elapsed*9)*0.04,0.25,1+sin(elapsed*9)*0.04)

func status() -> String:
	match phase:
		Phase.AIM: return "MỒI T-REX · CHỌN ĐIỂM ĐẶT MỒI" if target_valid else "MỒI T-REX · MỤC TIÊU KHÔNG HỢP LỆ"
		Phase.FLIGHT: return "PHÓNG MỒI · TRÁNH VÒNG CAM!"
		Phase.LURE: return "ĐÃ DÍNH MỒI!" if _target_alive(tagged) else "MỒI THỊT · VÒNG BẮT MỤC TIÊU"
		Phase.CHASE: return "T-REX ĐANG SĂN!" if not _miss else "T-REX ĐẾN ĂN MỒI"
		Phase.BITE: return "T-REX · CẮN!" if not _miss else "T-REX · ĂN MỒI"
	return ""

func stop() -> void:
	_restore_camera()
	phase = Phase.IDLE
	_showcase = false
	camera.h_offset = 0
	camera.v_offset = 0
	tagged = null
	_ring.hide()
	_ring.scale = Vector3(1,0.25,1)
	_roar.stop()
	_crunch.stop()
	_dust.emitting = false
	for node: Node3D in [_bait,_dino]:
		if is_instance_valid(node):
			node.queue_free()
	_bait = null
	_dino = null
	_model = null
	_fade_surfaces.clear()

func _exit_tree() -> void:
	_restore_camera()


func _trigger_quake_shockwave(pos: Vector3) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 1.3
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.12, 0.85)
	ring.material_override = mat

	get_tree().root.add_child(ring)
	ring.global_position = pos + Vector3.UP * 0.1
	ring.scale.y = 0.2

	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(5.5, 0.2, 5.5), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)
