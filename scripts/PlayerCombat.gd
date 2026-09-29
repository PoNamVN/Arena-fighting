class_name PlayerCombat
extends Node3D

## Configuration
@export var attack_damage: float = 25.0
@export var attack_range: float = 2.2
@export var attack_radius: float = 0.85
@export var attack_cooldown: float = 0.4
@export var target_collision_mask: int = 4 # Layer 3: Targets / Dummies
@export var wall_collision_mask: int = 1 # Layer 1: Environment / Walls

## Node References
@onready var slash_effect: Node3D = $VisualSlashCue
@onready var player: PlayerController = get_parent() as PlayerController

## Internal State
var _cooldown_timer: float = 0.0
var _slash_tween: Tween
var _cached_shape: SphereShape3D


func _ready() -> void:
	if slash_effect:
		slash_effect.visible = false
	_cached_shape = SphereShape3D.new()
	_cached_shape.radius = attack_radius


func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func try_attack() -> bool:
	if _cooldown_timer > 0.0:
		return false
	
	_cooldown_timer = attack_cooldown
	_perform_attack()
	return true


func _perform_attack() -> void:
	_trigger_visual_cue()
	
	var world_3d: World3D = get_world_3d()
	if not world_3d or not is_inside_tree():
		return
	
	var space_state: PhysicsDirectSpaceState3D = world_3d.direct_space_state
	if not space_state:
		return
	
	# Determine attack direction based on player Visuals facing direction
	var attack_basis: Basis = Basis.IDENTITY
	if player and player.visuals:
		attack_basis = player.visuals.global_basis
	else:
		attack_basis = global_basis
	
	var forward_dir: Vector3 = -attack_basis.z.normalized()
	var origin_pos: Vector3 = (player.global_position if player else global_position) + Vector3(0.0, 0.9, 0.0)
	var attack_center: Vector3 = origin_pos + forward_dir * (attack_range * 0.5)
	
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _cached_shape
	query.transform = Transform3D(Basis.IDENTITY, attack_center)
	query.collision_mask = target_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	if player:
		query.exclude = [player.get_rid()]
	
	var hits: Array[Dictionary] = space_state.intersect_shape(query, 16)
	if hits.is_empty():
		return
	
	var damaged_targets: Array[Node] = []
	
	for hit in hits:
		var collider: Object = hit.get("collider")
		if not collider is Node:
			continue
		
		var target_node: Node = collider as Node
		if target_node == player or target_node == self or target_node.is_ancestor_of(self) or self.is_ancestor_of(target_node):
			continue
		
		if target_node in damaged_targets:
			continue
		
		if not target_node.has_method("take_damage"):
			continue
		
		# Wall line-of-sight check: ensure no wall on Layer 1 is blocking between player and target
		var target_pos: Vector3 = (target_node as Node3D).global_position + Vector3(0.0, 0.9, 0.0) if target_node is Node3D else origin_pos
		var ray_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin_pos, target_pos, wall_collision_mask
		)
		ray_query.collide_with_areas = false
		ray_query.collide_with_bodies = true
		
		var exclude_list: Array[RID] = []
		if player:
			exclude_list.append(player.get_rid())
		if target_node is CollisionObject3D:
			exclude_list.append((target_node as CollisionObject3D).get_rid())
		ray_query.exclude = exclude_list
		
		var ray_result: Dictionary = space_state.intersect_ray(ray_query)
		if not ray_result.is_empty():
			# Blocked by wall
			continue
		
		target_node.call("take_damage", attack_damage)
		damaged_targets.append(target_node)


func _trigger_visual_cue() -> void:
	if not slash_effect:
		return
	
	if player and player.visuals:
		slash_effect.global_rotation = player.visuals.global_rotation
	else:
		slash_effect.global_rotation = global_rotation
		
	slash_effect.visible = true
	slash_effect.scale = Vector3(0.5, 0.5, 0.5)
	
	if _slash_tween and _slash_tween.is_valid():
		_slash_tween.kill()
		
	_slash_tween = create_tween()
	_slash_tween.tween_property(slash_effect, "scale", Vector3(1.2, 1.2, 1.2), 0.12)
	_slash_tween.tween_callback(func() -> void: if slash_effect: slash_effect.visible = false)
