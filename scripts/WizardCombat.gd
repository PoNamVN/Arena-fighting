class_name WizardCombat
extends Node

const MAX_CHARGE: float = 1.6
const RANGE: float = 24.0
const RECOVERY: float = 0.5
const COUNTER_RETREAT_DISTANCE: float = 3.2
const COUNTER_RETREAT_DURATION: float = 0.32
var presentation: Node
static var _fire_material_cache: ShaderMaterial
var ice: WizardIceGlide
var storm: WizardStormUltimate
var staff_strike: WizardStaffStrike
var spell: String = ""
var spell_elapsed: float = 0.0
var spell_direction: Vector3
var actor: PlayerController
var charging: bool = false
var charge_time: float = 0.0
var recovery_remaining: float = 0.0
var locked_target: Node3D
var counter_active: bool = false
var counter_elapsed: float = 0.0
var counters_fired: int = 0
var shots_fired: int = 0
var hits_landed: int = 0
var _counter_target: Node3D
var _retreat_direction: Vector3 = Vector3.BACK
var _projectiles: Array[Dictionary] = []
var _effects: Array[Dictionary] = []
var _staff: Node3D
var _orb: MeshInstance3D
var _shield: MeshInstance3D
var _marker: MeshInstance3D
var _label: Label
var _release_sound: AudioStreamPlayer3D
var _bar: ProgressBar

func _ready() -> void:
	process_priority = 100
	for spec: Array in [["skill_1", "wizard_giant_staff", "Đại trượng", 30.0, 7.0, 38.0], ["skill_2", "wizard_chicken_hex", "Hóa gà", 25.0, 9.0, 0.0], ["skill_3", "wizard_ice_glide", "Trượt băng", 15.0, 10.0, 0.0], ["ultimate", "wizard_lightning_storm", "Bão sét", 100.0, 0.0, 24.0]]:
		var ability: AbilityData = AbilityData.new()
		ability.id = spec[1]
		ability.display_name = spec[2]
		ability.stamina_cost = spec[3]
		ability.cooldown = spec[4]
		ability.damage = spec[5]
		ability.requires_full_stamina = spec[0] == "ultimate"
		ability.range = RANGE
		actor.ability_system.equip_ability(spec[0], ability)
	staff_strike = WizardStaffStrike.new()
	staff_strike.kit = self
	add_child(staff_strike)
	ice = WizardIceGlide.new()
	ice.kit = self
	add_child(ice)
	storm = WizardStormUltimate.new()
	storm.kit = self
	add_child(storm)
	actor.block_damage_reduction = 0.75
	actor.shield_break_stun_duration = 0.65
	actor.dodge_controller.perfect_dodge_registered.connect(_record_counter_attacker)
	_staff = preload("res://assets/models/wizard_staff.glb").instantiate() as Node3D
	actor.visuals.add_child(_staff)
	presentation = preload("res://scripts/WizardPresentation.gd").new()
	presentation.kit = self
	add_child(presentation)
	_orb = _sphere(0.2, Color(1, 0.22, 0.025))
	actor.add_child(_orb)
	_orb.top_level = true
	_orb.hide()
	_orb.material_override = _fire_material()
	_add_flames(_orb, 0.2)
	_release_sound = AudioStreamPlayer3D.new()
	_release_sound.volume_db = -10
	actor.add_child(_release_sound)
	_shield = _sphere(0.8, Color(0.2, 0.65, 1, 0.3))
	actor.visuals.add_child(_shield)
	_shield.position = Vector3(0, 1.05, -0.75)
	_shield.scale = Vector3(1, 1.1, 0.10)
	_shield.hide()
	_marker = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.53
	ring.outer_radius = 0.57
	ring.rings = 24
	ring.ring_segments = 6
	_marker.mesh = ring
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.material_override = _material(Color(1, 0.5, 0.05))
	actor.add_child(_marker)
	_marker.top_level = true
	_marker.hide()
	if not actor.external_controlled:
		_build_hud()
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = Color(1, 0.3, 0.035)
		_bar.add_theme_stylebox_override("fill", fill)

func _add_flames(parent: Node3D, radius: float) -> void:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	sparks.amount = 18
	sparks.lifetime = 0.35
	sparks.direction = Vector3.UP
	sparks.spread = 65
	sparks.initial_velocity_min = 0.35
	sparks.initial_velocity_max = 1.3
	sparks.gravity = Vector3(0, 1.2, 0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = radius
	sparks.scale_amount_min = 0.025
	sparks.scale_amount_max = 0.075
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 3
	sparks.mesh = mesh
	sparks.material_override = _material(Color(1, 0.65, 0.08))
	parent.add_child(sparks)

func _material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _fire_material() -> ShaderMaterial:
	if not _fire_material_cache:
		_fire_material_cache = ShaderMaterial.new()
		_fire_material_cache.shader = preload("res://assets/shaders/fireball_energy.gdshader")
	return _fire_material_cache

func _sphere(radius: float, color: Color) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 16
	mesh.rings = 8
	node.mesh = mesh
	node.material_override = _material(color)
	return node

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ultimate") and not event.is_echo():
		storm.begin()
	elif event.is_action_pressed("skill_3") and not event.is_echo():
		ice.begin()
	elif event.is_action_released("skill_3"):
		ice.stop()
	elif event.is_action_pressed("skill_1") and not event.is_echo():
		start_staff()
	elif event.is_action_pressed("skill_2") and not event.is_echo():
		start_polymorph()
	elif event.is_action_pressed("attack") and not event.is_echo():
		if actor.is_counter_window_active():
			start_counter()
		else:
			start_charge()
	elif event.is_action_released("attack"):
		release_fireball()
	elif event.is_action_pressed("block"):
		start_block()
	elif event.is_action_released("block"):
		actor._release_block()
	elif event.is_action_pressed("dodge") and not event.is_echo():
		actor._try_dodge()

func start_charge() -> bool:
	if storm.active() or ice.active or spell != "" or staff_strike.active or actor.is_control_impaired() or charging or counter_active or actor.is_shield_broken or actor.is_shield_stunned or recovery_remaining > 0 or not actor.controls_enabled or actor.is_dead:
		return false
	if actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN] or actor._knockback_timer > 0:
		return false
	charging = true
	charge_time = 0
	locked_target = _find_target()
	return true

func cancel_charge() -> void:
	charging = false
	charge_time = 0
	locked_target = null
	if _orb:
		_orb.hide()
	if _marker:
		_marker.hide()

func release_fireball() -> bool:
	if not charging:
		return false
	if not actor.controls_enabled or actor.is_dead or actor._knockback_timer > 0 or actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN]:
		cancel_charge()
		return false
	if not _target_valid(locked_target):
		locked_target = null
	var origin: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	var direction: Vector3 = -actor.camera.global_basis.z
	if is_instance_valid(locked_target):
		direction = (locked_target.global_position + Vector3(0, 0.9, 0) - origin).normalized()
	var ratio: float = charge_time / MAX_CHARGE
	_spawn_projectile(direction, lerpf(18, 28, ratio), lerpf(10, 34, ratio), lerpf(0.12, 0.42, ratio), true, lerpf(0, 1.5, ratio))
	cancel_charge()
	recovery_remaining = RECOVERY
	return true

func start_block() -> bool:
	if storm.active() or ice.active:
		return false
	if actor.is_control_impaired() or not actor.controls_enabled or actor.is_dead or actor.is_shield_broken or actor.is_shield_stunned or counter_active or actor.combat_state == PlayerController.CombatState.DODGE:
		return false
	interrupt()
	return actor.transition_to(PlayerController.CombatState.BLOCK)

func start_counter() -> bool:
	if storm.active() or ice.active:
		return false
	if actor.is_control_impaired() or not actor.controls_enabled or actor.is_dead or counter_active or actor.is_shield_broken or actor.is_shield_stunned or not actor.is_counter_window_active():
		return false
	if not is_instance_valid(_counter_target) or _counter_target == actor or not _counter_target is CollisionObject3D:
		return false
	if (_counter_target as CollisionObject3D).collision_layer & actor.combat.target_collision_mask == 0:
		return false
	if (_counter_target is PlayerController and not _counter_target.is_targetable()) or (_counter_target is TrainingDummy and _counter_target.is_dead()):
		return false
	var offset: Vector3 = _counter_target.global_position + Vector3(0, 0.9, 0) - (actor.global_position + Vector3(0, 1.35, 0))
	if offset.length() > RANGE or offset.length() < 0.01:
		return false
	interrupt()
	actor.dodge_controller.cancel_dodge()
	if not actor.transition_to(PlayerController.CombatState.COUNTER):
		return false
	actor.dodge_controller.consume_counter_window()
	var direction: Vector3 = offset.normalized()
	_retreat_direction = -Vector3(direction.x, 0, direction.z).normalized()
	actor._camera_yaw = atan2(-direction.x, -direction.z)
	actor.camera_pivot.rotation.y = actor._camera_yaw
	actor.visuals.rotation.y = actor._camera_yaw
	counter_active = true
	counter_elapsed = 0
	actor.velocity.y = 3.6 if actor.is_on_floor() else actor.velocity.y
	_spawn_projectile(direction, 40, 45, 0.16, false, 0)
	counters_fired += 1
	return true

func interrupt() -> void:
	if storm and storm.channeling():
		return
	if presentation:
		presentation.reset()
	if storm and storm.active():
		storm.stop()
	if ice:
		ice.stop()
	if spell != "" or (staff_strike and staff_strike.active):
		recovery_remaining = maxf(recovery_remaining, 0.35)
	spell = ""
	if staff_strike:
		staff_strike.stop()
	cancel_charge()
	if counter_active:
		counter_active = false
		actor.velocity.x = 0
		actor.velocity.z = 0
		actor.transition_to(PlayerController.CombatState.IDLE)
		recovery_remaining = maxf(recovery_remaining, 0.3)

func reset() -> void:
	if presentation:
		presentation.reset()
	if storm:
		storm.stop()
	if ice:
		ice.clear()
	interrupt()
	if actor._skeleton:
		actor._skeleton.clear_bones_global_pose_override()
	if _release_sound:
		_release_sound.stop()
	for data: Dictionary in _projectiles:
		if is_instance_valid(data.node):
			data.node.queue_free()
	_projectiles.clear()
	for data: Dictionary in _effects:
		if is_instance_valid(data.node):
			data.node.queue_free()
	_effects.clear()
	recovery_remaining = 0
	_counter_target = null
	if _shield:
		_shield.hide()

func _spawn_projectile(direction: Vector3, speed: float, damage: float, radius: float, basic: bool, splash: float, hex_shot: bool = false) -> void:
	var node: MeshInstance3D = _sphere(radius, Color(1, 0.25, 0.025) if basic else Color(0.75, 0.2, 1) if hex_shot else Color(0.35, 0.8, 1))
	actor.add_child(node)
	node.top_level = true
	node.global_position = actor.global_position + Vector3(0, 1.35, 0)
	if basic:
		node.material_override = _fire_material()
		_add_flames(node, radius)
	if not basic:
		var beam: MeshInstance3D = MeshInstance3D.new()
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.055
		mesh.bottom_radius = 0.1
		mesh.height = 1.8
		mesh.radial_segments = 8
		beam.mesh = mesh
		beam.material_override = _material(Color(0.8, 0.25, 1) if hex_shot else Color(0.4, 0.85, 1))
		beam.rotation.x = PI * 0.5
		node.add_child(beam)
		node.look_at(node.global_position + direction, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	_projectiles.append({"node": node, "direction": direction, "speed": speed, "damage": damage, "radius": radius, "basic": basic, "splash": splash, "distance": 0.0, "hex": hex_shot})
	presentation.released(Color(1, 0.35, 0.06) if basic else Color(0.8, 0.3, 1) if hex_shot else Color(0.3, 0.75, 1))
	shots_fired += 1
	_release_sound.stream = preload("res://assets/audio/wizard_fire_release.wav") if basic else preload("res://assets/audio/wizard_counter_release.wav")
	_release_sound.pitch_scale = 1.0
	_release_sound.play()

func _physics_process(delta: float) -> void:
	if not actor.controls_enabled or actor.is_dead:
		reset()
		return
	recovery_remaining = maxf(0, recovery_remaining - delta)
	if spell == "X":
		spell_elapsed += delta
		if spell_elapsed >= 0.22:
			_spawn_projectile(spell_direction, 26, 0, 0.12, false, 0, true)
			spell = ""
			recovery_remaining = 0.45
	if charging:
		if actor.combat_state not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN] or actor._knockback_timer > 0 or not actor._is_mouse_captured:
			cancel_charge()
		else:
			charge_time = minf(MAX_CHARGE, charge_time + delta)
			if not _target_valid(locked_target):
				locked_target = _find_target()
			if is_instance_valid(locked_target):
				var offset: Vector3 = locked_target.global_position - actor.global_position
				actor._camera_yaw = lerp_angle(actor._camera_yaw, atan2(-offset.x, -offset.z), minf(1, delta * 8))
				actor.camera_pivot.rotation.y = actor._camera_yaw
				actor.visuals.rotation.y = actor._camera_yaw
	for i: int in range(_projectiles.size()-1, -1, -1):
		var data: Dictionary = _projectiles[i]
		var from: Vector3 = data.node.global_position
		var travel: float = minf(data.speed * delta, RANGE - float(data.distance))
		var motion: Vector3 = data.direction * travel
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = data.radius
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = from
		query.collision_mask = 1 | actor.combat.target_collision_mask
		query.exclude = [actor.get_rid()]
		var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
		var overlaps: Array[Dictionary] = space.intersect_shape(query, 8)
		query.motion = motion
		var fractions: PackedFloat32Array = space.cast_motion(query)
		var hit: Dictionary = overlaps[0] if not overlaps.is_empty() else {}
		var fraction: float = 0
		if hit.is_empty() and fractions[0] < 1:
			fraction = fractions[0]
			query.transform.origin = from + motion * fractions[1]
			query.motion = Vector3.ZERO
			hit = space.get_rest_info(query)
		var to: Vector3 = from + motion * fraction if not hit.is_empty() else from + motion
		data.node.global_position = to
		data.distance += travel
		if not hit.is_empty():
			var target: Object = hit.get("collider")
			if target == null and hit.has("collider_id"):
				target = instance_from_id(hit.collider_id)
			if data.hex:
				_polymorph_hit(target, from)
			else:
				_explode(data, target, from, to)
			data.node.queue_free()
			_projectiles.remove_at(i)
		elif data.distance >= RANGE:
			data.node.queue_free()
			_projectiles.remove_at(i)
	for i: int in range(_effects.size()-1, -1, -1):
		var data: Dictionary = _effects[i]
		data.age += delta
		data.node.scale = Vector3.ONE * (1 + data.age * 3)
		var mat: StandardMaterial3D = data.node.material_override
		mat.albedo_color.a = maxf(0, 0.65 * (1 - data.age / 0.3))
		if data.age >= 0.3:
			data.node.queue_free()
			_effects.remove_at(i)

func _explode(data: Dictionary, target: Object, incoming: Vector3, position: Vector3) -> void:
	# One energy reward per basic shot, including multi-target explosions.
	var hits_before: int = hits_landed
	_impact(target, data.damage, incoming, position, false, 15 if data.basic else 20)
	if data.basic and data.splash > 0.1:
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = data.splash
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = position
		query.collision_mask = actor.combat.target_collision_mask
		query.exclude = [actor.get_rid()]
		for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
			var receiver: Node3D = hit.collider as Node3D
			if receiver == target:
				continue
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(incoming, receiver.global_position + Vector3(0, 0.9, 0), 1)
			ray.exclude = [actor.get_rid(), (receiver as CollisionObject3D).get_rid()]
			if actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				_impact(receiver, data.damage * 0.5, incoming, receiver.global_position + Vector3.UP, false, 8)
	if data.basic and hits_landed > hits_before:
		actor.stamina_component.add_stamina(actor.stamina_component.attack_stamina_gain)
	var effect: MeshInstance3D = _sphere(maxf(data.radius, data.splash * 0.5), Color(1, 0.45, 0.06, 0.65) if data.basic else Color(0.35, 0.8, 1, 0.65))
	actor.add_child(effect)
	effect.top_level = true
	effect.global_position = position
	_effects.append({"node": effect, "age": 0.0})

func _process(delta: float) -> void:
	presentation.update(delta)
	_shield.visible = actor.is_blocking and not actor.is_dead and actor.controls_enabled
	if actor.is_dead or actor.is_control_impaired():
		_staff.visible = not actor.is_dead and not actor.is_control_impaired()
		_shield.hide()
		if _label:
			_label.hide()
			_bar.hide()
		return
	_staff.visible = true
	_orb.visible = charging
	if charging:
		_orb.global_position = actor.global_position + Vector3(0, 1.4, 0) - actor.visuals.global_basis.z * 0.6
		_orb.scale = Vector3.ONE * lerpf(0.6, 2.1, charge_time / MAX_CHARGE)
	_marker.visible = charging and is_instance_valid(locked_target)
	if _marker.visible:
		_marker.global_position = locked_target.global_position + Vector3(0, 0.05, 0)
	if _label:
		_label.visible = actor.controls_enabled and not actor.is_dead
		_bar.visible = _label.visible and charging
		_bar.value = charge_time / MAX_CHARGE * 100
		_label.text = "COUNTER · TIA PHÉP" if counter_active else ("KHIÊN PHÉP" if actor.is_blocking else ("PERFECT DODGE · PHẢN CÔNG SẴN SÀNG" if actor.is_counter_window_active() else ("CẦU LỬA · %d%%" % roundi(charge_time / MAX_CHARGE * 100) if charging else "")))
		if staff_strike.active:
			_label.text = "ĐẠI TRƯỢNG · GIÁNG XUỐNG"
		elif ice.active:
			_label.text = "TRƯỢT BĂNG · %.1fs" % (WizardIceGlide.MAX_DURATION - ice.elapsed)
		elif storm.active():
			_label.text = "BÃO SÉT · %.1fs" % (WizardStormUltimate.DURATION - storm.elapsed) if storm.channeling() else "BÃO SÉT · CHỌN VÙNG"
		elif spell == "X":
			_label.text = "HÓA GÀ · THI TRIỂN"

func _record_counter_attacker(payload: Variant) -> void:
	_counter_target = null
	var position: Vector3 = PlayerController.NO_ATTACKER_POS
	if payload is AttackPayload:
		_counter_target = payload.attacker
		position = payload.attacker_pos
	elif payload is Dictionary:
		_counter_target = payload.get("attacker", null) as Node3D
		position = payload.get("attacker_pos", position)
	if is_instance_valid(_counter_target):
		return
	# Older attacks carry position only. Resolve the source, not a nearer bystander.
	if position == PlayerController.NO_ATTACKER_POS:
		return
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = RANGE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = actor.global_position
	query.collision_mask = actor.combat.target_collision_mask
	query.exclude = [actor.get_rid()]
	var nearest: float = 4.0
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var candidate: Node3D = hit.collider as Node3D
		if candidate:
			var distance: float = candidate.global_position.distance_squared_to(position)
			if distance < nearest:
				_counter_target = candidate
				nearest = distance


func process_counter_movement(delta: float) -> void:
	var step: float = minf(delta, COUNTER_RETREAT_DURATION - counter_elapsed)
	actor.velocity.x = _retreat_direction.x * COUNTER_RETREAT_DISTANCE / COUNTER_RETREAT_DURATION * step / delta
	actor.velocity.z = _retreat_direction.z * COUNTER_RETREAT_DISTANCE / COUNTER_RETREAT_DURATION * step / delta
	actor.velocity.y -= actor.gravity * delta
	actor.move_and_slide()
	counter_elapsed += delta
	if counter_elapsed >= COUNTER_RETREAT_DURATION:
		counter_active = false
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		recovery_remaining = 0.30
		actor.transition_to(PlayerController.CombatState.IDLE)


func _impact(target: Object, damage: float, incoming_position: Vector3, position: Vector3, basic: bool = true, shield_damage: float = 15.0) -> void:
	var actual: float = 0.0
	var blocked: bool = false
	if target is PlayerController:
		var receiver: PlayerController = target as PlayerController
		var before: float = receiver.health_component.current_health
		blocked = receiver.is_blocking and actor.combat.is_attack_inside_block_cone(receiver, incoming_position, receiver.block_cone_deg)
		var payload: AttackPayload = AttackPayload.new(damage, incoming_position, shield_damage, true)
		payload.attacker = actor
		receiver.take_damage(payload, incoming_position)
		actual = before - receiver.health_component.current_health
	elif target is TrainingDummy:
		var receiver: TrainingDummy = target as TrainingDummy
		var before: float = receiver.current_hp
		blocked = receiver.is_blocking and not receiver.is_shield_broken and actor.combat.is_attack_inside_block_cone(receiver, incoming_position, receiver.block_cone_deg)
		receiver.take_damage(damage * (1.0 - receiver.block_damage_reduction) if blocked else damage, incoming_position, blocked)
		if blocked:
			receiver.apply_shield_damage(shield_damage)
		actual = before - receiver.current_hp
	if actual > 0.0:
		hits_landed += 1
		if basic:
			actor.stamina_component.add_stamina(actor.stamina_component.attack_stamina_gain)
		actor.combat.hit_landed.emit(target, actual, blocked)
		actor.combat.spawn_damage_number(position, actual, blocked, shield_damage if blocked else 0.0)
		if actor.combat_feedback:
			actor.combat_feedback.trigger_hit_feedback(target, actual)
		if blocked:
			actor.combat.trigger_block_impact(position, (position - incoming_position).normalized())
		else:
			actor.combat.trigger_hit_impact(position, (position - incoming_position).normalized())


func _target_valid(target: Variant) -> bool:
	if not is_instance_valid(target) or target == actor or not target is CollisionObject3D or not target.has_method("take_damage"):
		return false
	if (target as CollisionObject3D).collision_layer & actor.combat.target_collision_mask == 0:
		return false
	if target is PlayerController and (target.is_dead or not target.is_targetable()):
		return false
	if target is TrainingDummy and target.is_dead():
		return false
	var from: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	var to: Vector3 = target.global_position + Vector3(0, 0.9, 0)
	var offset: Vector3 = to - from
	if offset.length() > RANGE or offset.length() < 0.01:
		return false
	var forward: Vector3 = Basis(Vector3.UP, actor._camera_yaw) * Vector3.FORWARD
	var flat: Vector3 = Vector3(offset.x, 0, offset.z).normalized()
	if forward.dot(flat) < cos(deg_to_rad(55.0)):
		return false
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	ray.exclude = [actor.get_rid(), (target as CollisionObject3D).get_rid()]
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _find_target() -> Node3D:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = RANGE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = actor.global_position
	query.collision_mask = actor.combat.target_collision_mask
	query.exclude = [actor.get_rid()]
	var best: Node3D
	var nearest: float = INF
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var candidate: Node3D = hit.collider as Node3D
		if _target_valid(candidate):
			var distance: float = actor.global_position.distance_squared_to(candidate.global_position)
			if distance < nearest:
				best = candidate
				nearest = distance
	return best


func _build_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_label = Label.new()
	layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_label.offset_left = -380
	_label.offset_right = 380
	_label.offset_top = -210
	_label.offset_bottom = -150
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_constant_override("outline_size", 4)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar = ProgressBar.new()
	layer.add_child(_bar)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -140
	_bar.offset_right = 140
	_bar.offset_top = -145
	_bar.offset_bottom = -125
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.33, 0.8, 0.15)
	fill.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.10, 0.04, 0.9)
	background.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", background)


func _can_spell() -> bool:
	return not storm.active() and not ice.active and not actor.is_control_impaired() and not charging and not counter_active and spell == "" and not staff_strike.active and recovery_remaining <= 0 and actor.controls_enabled and not actor.is_dead and not actor.is_shield_broken and not actor.is_shield_stunned and actor._knockback_timer <= 0 and actor.combat_state in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN]

func start_staff() -> bool:
	if not _can_spell() or not actor.ability_system.cast_ability("skill_1"):
		return false
	staff_strike.begin()
	recovery_remaining = WizardStaffStrike.WARNING + WizardStaffStrike.FALL + 0.4
	return true

func start_polymorph() -> bool:
	if not _can_spell() or not actor.ability_system.cast_ability("skill_2"):
		return false
	var target: Node3D = _find_target()
	var origin: Vector3 = actor.global_position + Vector3(0, 1.35, 0)
	spell_direction = -actor.camera.global_basis.z
	if is_instance_valid(target):
		spell_direction = (target.global_position + Vector3(0, 0.9, 0) - origin).normalized()
	spell = "X"
	spell_elapsed = 0
	return true

func _polymorph_hit(target: Object, incoming: Vector3, freeze: bool = false) -> void:
	if not (target is PlayerController or target is TrainingDummy):
		return
	if target is PlayerController:
		if target.is_dead or not target.controls_enabled or (target.wizard_combat and target.wizard_combat.storm.channeling()):
			return
		var payload: AttackPayload = AttackPayload.new(0, incoming, 15)
		payload.attacker = actor
		if target.is_in_dodge_iframe():
			target.take_damage(payload)
			return
		var protected: bool = target.active_ability_action and target.active_ability_action.has_front_protection()
		if (target.is_blocking or protected) and actor.combat.is_attack_inside_block_cone(target, incoming, target.block_cone_deg):
			target.take_damage(payload)
			return
	elif target.is_dead():
		return
	elif target.is_blocking and not target.is_shield_broken and actor.combat.is_attack_inside_block_cone(target, incoming, target.block_cone_deg):
		target.apply_shield_damage(15)
		return
	if freeze:
		target.frost.begin()
	else:
		target.polymorph.begin()
