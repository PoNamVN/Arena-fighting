class_name WizardStaffStrike
extends Node

const LENGTH: float = 12.3
const WIDTH: float = 2.0
const WARNING: float = 0.8
const FALL: float = 0.42
var kit: WizardCombat
var elapsed: float = 0.0
var active: bool = false
var struck: bool = false
var pivot: Node3D
var outline: Node3D
var origin: Vector3
var direction: Vector3
var length: float

func begin() -> void:
	active = true
	struck = false
	elapsed = 0
	direction = Basis(Vector3.UP, kit.actor._camera_yaw) * Vector3.FORWARD
	origin = kit.actor.global_position + direction * 0.8
	length = LENGTH
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin + Vector3.UP, origin + Vector3.UP + direction * LENGTH, 1)
	ray.exclude = [kit.actor.get_rid()]
	var wall: Dictionary = kit.actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		length = maxf(0.1, origin.distance_to(wall.position - Vector3.UP) - 0.25)
	pivot = Node3D.new()
	kit.actor.add_child(pivot)
	pivot.top_level = true
	pivot.global_position = origin
	pivot.look_at(origin + direction)
	var staff: Node3D = preload("res://assets/models/wizard_staff.glb").instantiate() as Node3D
	pivot.add_child(staff)
	staff.scale = Vector3(6, length / 2.05, 6)
	staff.position.y = 0.75 * length / 2.05
	outline = Node3D.new()
	kit.actor.add_child(outline)
	outline.top_level = true
	outline.global_position = origin + Vector3(0, 0.05, 0)
	outline.look_at(outline.global_position + direction)
	for spec: Vector3 in [Vector3(-WIDTH / 2, 0, -length / 2), Vector3(WIDTH / 2, 0, -length / 2), Vector3(0, 0, 0), Vector3(0, 0, -length)]:
		var edge: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(0.06, 0.03, length) if absf(spec.x) > 0 else Vector3(WIDTH, 0.03, 0.06)
		edge.mesh = mesh
		edge.material_override = kit._material(Color(1, 0.62, 0.08))
		edge.position = spec
		outline.add_child(edge)

func _physics_process(delta: float) -> void:
	if not active:
		return
	if kit.actor.is_dead or not kit.actor.controls_enabled:
		stop()
		return
	elapsed += delta
	if elapsed < WARNING:
		pivot.scale = Vector3.ONE * lerpf(0.15, 1.0, smoothstep(0, WARNING * 0.6, elapsed))
	else:
		pivot.scale = Vector3.ONE
		pivot.rotation.x = -PI / 2 * pow(clampf((elapsed - WARNING) / FALL, 0, 1), 2)
	if not struck and elapsed >= WARNING + FALL:
		struck = true
		_strike()
		if not active:
			return
		outline.hide()
		_dust()
		kit._release_sound.stream = preload("res://assets/audio/wizard_counter_release.wav")
		kit._release_sound.pitch_scale = 0.4
		kit._release_sound.play()
	if elapsed >= WARNING + FALL + 0.2:
		pivot.scale = Vector3.ONE * maxf(0, 1 - (elapsed - WARNING - FALL - 0.2) / 0.35)
	if elapsed >= WARNING + FALL + 0.55:
		stop()

func _strike() -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(WIDTH, 2.5, length)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(outline.global_basis, origin + direction * length / 2 + Vector3.UP)
	query.collision_mask = kit.actor.combat.target_collision_mask
	query.exclude = [kit.actor.get_rid()]
	for hit: Dictionary in kit.actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		if not kit.actor.controls_enabled or kit.actor.is_dead:
			return
		var target: Node3D = hit.collider as Node3D
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin + Vector3.UP, target.global_position + Vector3.UP, 1)
		ray.exclude = [kit.actor.get_rid(), (target as CollisionObject3D).get_rid()]
		if not kit.actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var before: int = kit.hits_landed
		var blocking: bool = target.is_blocking and not target.is_shield_broken and kit.actor.combat.is_attack_inside_block_cone(target, origin + Vector3.UP, target.block_cone_deg) if target is PlayerController or target is TrainingDummy else false
		kit._impact(target, 38, origin + Vector3.UP, target.global_position + Vector3.UP, false, 30)
		if kit.hits_landed > before and not blocking and target is PlayerController and not target.is_dead:
			target.apply_knockback(direction, 1.4, 0.2)

func stop() -> void:
	active = false
	if is_instance_valid(pivot):
		pivot.queue_free()
	if is_instance_valid(outline):
		outline.queue_free()
	pivot = null
	outline = null


func _dust() -> void:
	var dust: CPUParticles3D = CPUParticles3D.new()
	dust.amount = 32
	dust.lifetime = 0.45
	dust.one_shot = true
	dust.explosiveness = 1
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(WIDTH / 2, 0.02, length / 2)
	dust.direction = Vector3.UP
	dust.spread = 35
	dust.initial_velocity_min = 1
	dust.initial_velocity_max = 3
	dust.gravity = Vector3(0, -6, 0)
	dust.scale_amount_min = 0.08
	dust.scale_amount_max = 0.2
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 3
	dust.mesh = mesh
	dust.material_override = kit._material(Color(0.6, 0.4, 0.17))
	pivot.add_child(dust)
	dust.top_level = true
	dust.global_transform = Transform3D(outline.global_basis, origin + direction * length / 2 + Vector3.UP * 0.15)
	dust.emitting = true
