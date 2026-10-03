class_name WizardIceGlide
extends Node

const SPEED: float = 10.0
const MAX_DURATION: float = 3.0
const DRAIN: float = 15.0
const MAX_HEIGHT: float = 5.0
const ICE_LIFETIME: float = 4.0
var kit: WizardCombat
var active: bool = false
var elapsed: float = 0.0
var baseline: float = 0.0
var direction: Vector3
var tiles: Array[Dictionary] = []
var touched: Dictionary = {}
var _last_tile: Vector3
var _old_snap: float

func begin() -> bool:
	if not kit._can_spell() or not kit.actor.is_on_floor() or not kit.actor.ability_system.cast_ability("skill_3"):
		return false
	active = true
	elapsed = 0
	baseline = kit.actor.global_position.y
	direction = Basis(Vector3.UP, kit.actor._camera_yaw) * Vector3.FORWARD
	_last_tile = Vector3.INF
	touched.clear()
	_old_snap = kit.actor.floor_snap_length
	kit.actor.floor_snap_length = 0.6
	return true

func process_movement(delta: float) -> void:
	var actor: PlayerController = kit.actor
	var cost: float = DRAIN * delta
	if (not actor.external_controlled and not Input.is_action_pressed("skill_3")) or elapsed >= MAX_DURATION or not actor.controls_enabled or actor.is_dead or actor.is_control_impaired() or not actor.stamina_component.consume_stamina(cost):
		stop()
		return
	elapsed += delta
	var desired: Vector3 = Basis(Vector3.UP, actor._camera_yaw) * Vector3.FORWARD
	direction = direction.slerp(desired, minf(1, delta * 5)).normalized()
	var slope: float = clampf(-actor.camera.global_basis.z.y, -0.5, 0.8) * 0.65
	if actor.global_position.y >= baseline + MAX_HEIGHT:
		slope = minf(0, slope)
	if actor.global_position.y <= baseline + 0.05:
		slope = maxf(0, slope)
	if _last_tile == Vector3.INF or actor.global_position.distance_to(_last_tile) >= 0.55:
		_plant(slope)
	var before: Vector3 = actor.global_position
	actor.velocity.x = direction.x * SPEED
	actor.velocity.z = direction.z * SPEED
	actor.velocity.y = -0.6 if actor.is_on_floor() else actor.velocity.y - actor.gravity * delta
	actor.move_and_slide()
	_contact(before, actor.global_position)
	for index: int in range(actor.get_slide_collision_count()):
		var collision: KinematicCollision3D = actor.get_slide_collision(index)
		var body: Object = collision.get_collider()
		if collision.get_normal().y < 0.4 and (not body is Node or not body.is_in_group("wizard_ice")):
			stop()
			break

func _plant(slope: float) -> void:
	var actor: PlayerController = kit.actor
	var start: Vector3 = actor.global_position - direction * 0.55
	start.y = actor.global_position.y - 0.06 - slope * 0.55
	var end: Vector3 = actor.global_position + direction * 1.5
	end.y = clampf(actor.global_position.y - 0.06 + slope * 1.5, baseline - 0.025, baseline + MAX_HEIGHT)
	# Only own ice is excluded; arena walls still stop construction.
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP, end + Vector3.UP, 1)
	ray.exclude = [actor.get_rid()]
	for tile: Dictionary in tiles:
		ray.exclude.append(tile.body.get_rid())
	var wall: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		return
	var right: Vector3 = direction.cross(Vector3.UP).normalized() * 0.9
	var verts: PackedVector3Array = PackedVector3Array([start - right, start + right, end + right, end - right, Vector3(start.x - right.x, baseline - 0.15, start.z - right.z), Vector3(start.x + right.x, baseline - 0.15, start.z + right.z), Vector3(end.x + right.x, baseline - 0.15, end.z + right.z), Vector3(end.x - right.x, baseline - 0.15, end.z - right.z)])
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in [0, 1, 2, 0, 2, 3, 0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5, 2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7, 4, 5, 6, 4, 6, 7]:
		surface.add_vertex(verts[index])
	surface.generate_normals()
	var mesh: ArrayMesh = surface.commit()
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TemporaryIceRamp"
	body.add_to_group("wizard_ice")
	body.collision_layer = 1
	body.collision_mask = 0
	actor.add_child(body)
	body.top_level = true
	body.global_transform = Transform3D.IDENTITY
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.72, 0.92)
	material.roughness = 0.2
	material.metallic = 0.15
	visual.material_override = material
	body.add_child(visual)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var hull: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	hull.points = verts
	collision.shape = hull
	body.add_child(collision)
	tiles.append({"body": body, "age": 0.0})
	_last_tile = actor.global_position
	if tiles.size() > 55:
		var oldest: Dictionary = tiles.pop_front()
		oldest.body.queue_free()

func _contact(from: Vector3, to: Vector3) -> void:
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 1.1
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform.origin = (from + to) / 2 + Vector3.UP * 0.8
	query.collision_mask = kit.actor.combat.target_collision_mask
	query.exclude = [kit.actor.get_rid()]
	for hit: Dictionary in kit.actor.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var target: Node3D = hit.collider as Node3D
		if touched.has(target.get_instance_id()):
			continue
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from + Vector3.UP, target.global_position + Vector3.UP, 1)
		ray.exclude = [kit.actor.get_rid()]
		for tile: Dictionary in tiles:
			ray.exclude.append(tile.body.get_rid())
		if not kit.actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		touched[target.get_instance_id()] = true
		kit._polymorph_hit(target, from + Vector3.UP, true)
		if target is PlayerController or target is TrainingDummy:
			if target.frost.active():
				stop()

func _physics_process(delta: float) -> void:
	if kit.actor.is_dead or not kit.actor.controls_enabled:
		clear()
		return
	for i: int in range(tiles.size() - 1, -1, -1):
		tiles[i].age += delta
		if tiles[i].age >= ICE_LIFETIME:
			tiles[i].body.queue_free()
			tiles.remove_at(i)

func stop() -> void:
	if active:
		kit.actor.floor_snap_length = _old_snap
		kit.actor.velocity.x = 0
		kit.actor.velocity.z = 0
		kit.recovery_remaining = maxf(kit.recovery_remaining, 0.3)
	active = false

func clear() -> void:
	stop()
	for tile: Dictionary in tiles:
		tile.body.queue_free()
	tiles.clear()
	touched.clear()
