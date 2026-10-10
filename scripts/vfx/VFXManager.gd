extends Node

const Definition = preload("res://scripts/vfx/VFXDefinition.gd")
const PooledEffect = preload("res://scripts/vfx/PooledVFX.gd")
const COMMON_LIBRARY = preload("res://vfx/common/library.tres")
const COMMON_MULTIPLIERS: Array[float] = [0.5, 1.0, 1.2]
const DEFAULT_LIBRARY = preload("res://vfx/vfx_library.tres")
const HAWK_LIBRARY = preload("res://vfx/archer/hawk_library.tres")
enum Quality { LOW, MEDIUM, HIGH }
const MULTIPLIERS: Array[float] = [0.5, 0.75, 1.0]

signal warmup_started()
signal warmup_finished(rendered: bool)
signal quality_changed(quality: int)
signal enabled_changed(enabled: bool)
signal presentation_event(event: StringName, context: Dictionary)
signal spawn_rejected(effect_name: StringName, reason: StringName)

var _quality: Quality = Quality.MEDIUM
var _enabled: bool = true
var quality: Quality:
	get: return _quality
	set(value): set_quality(value)
var enabled: bool:
	get: return _enabled
	set(value): set_enabled(value)
var warmup_complete: bool = false
var warmup_rendered: bool = false
var _entries: Dictionary = {}
var _bindings: Dictionary = {}
var _active: Dictionary = {}
var _observed: Dictionary = {}
var _warming: bool = false
var _common_defaults: Dictionary = {}
var _visual_stop: Node
var hit_stop_enabled := false:
	set(value):
		hit_stop_enabled = value
		if is_instance_valid(_visual_stop):
			_visual_stop.enabled = value
			if not value:
				_visual_stop.restore()
var _pool_root: Node3D
var _warm_viewport: SubViewport
var _warm_root: Node3D
var _spawn_count: int = 0
var _drop_count: int = 0

func _ready() -> void:
	_visual_stop = preload("res://vfx/common/visual_hit_stop.gd").new()
	_visual_stop.name = "VisualHitStop"
	add_child(_visual_stop)
	_pool_root = Node3D.new()
	_pool_root.name = "Pools"
	_pool_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_pool_root)
	get_tree().node_added.connect(_on_node_added)
	for definition: Resource in DEFAULT_LIBRARY.definitions:
		register_definition(definition)
	for definition: Resource in HAWK_LIBRARY.definitions:
		register_definition(definition)
	for definition: Resource in COMMON_LIBRARY.definitions:
		var authored := definition.duplicate()
		if authored.effect_name == &"DustPuff":
			authored.pool_size = 16
		register_definition(authored)
	call_deferred("warm_up")
	_scan(get_tree().root)

func register_definition(definition: Definition) -> bool:
	if _warming or not definition or definition.effect_name.is_empty() or not definition.scene or _entries.has(definition.effect_name):
		return false
	var instances: Array[Node3D] = []
	for index: int in range(clampi(definition.pool_size, 1, 64)):
		var effect: Node = definition.scene.instantiate()
		if not effect is PooledEffect or _contains_gameplay_node(effect):
			effect.free()
			for created: Node3D in instances:
				created.free()
			return false
		effect.name = "%s_%d" % [definition.effect_name,index]
		_pool_root.add_child(effect)
		effect.configure(clampf(definition.duration,0.02,30), 500 if definition.ultimate else 200)
		effect.apply_quality(1.0 if definition.essential else _quality_for(definition))
		effect.finished.connect(_on_effect_finished)
		if _is_common(definition) and effect.particles:
			_common_defaults[effect.get_instance_id()] = {"direction":effect.motion.direction,"spread":effect.motion.spread,"initial_velocity_min":effect.motion.initial_velocity_min,"initial_velocity_max":effect.motion.initial_velocity_max,"lifetime":effect.particles.lifetime}
		instances.append(effect)
	var available: Array[Node3D] = instances.duplicate()
	_entries[definition.effect_name] = {"definition":definition,"instances":instances,"available":available,"warmed":false,"rendered":false}
	if not definition.event.is_empty():
		if not _bindings.has(definition.event):
			_bindings[definition.event] = []
		_bindings[definition.event].append(definition.effect_name)
	warmup_complete = false
	return true

func _contains_gameplay_node(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		return true
	for child: Node in node.get_children():
		if _contains_gameplay_node(child):
			return true
	return false

func spawn(effect_name: StringName, at: Variant = Transform3D.IDENTITY, context: Dictionary = {}) -> Node3D:
	if not _entries.has(effect_name):
		_reject(effect_name,&"unknown_name")
		return null
	var entry: Dictionary = _entries[effect_name]
	if not enabled and not entry.definition.essential:
		return null
	if not entry.warmed:
		_reject(effect_name,&"not_warmed")
		return null
	if entry.available.is_empty():
		_reject(effect_name,&"pool_full")
		return null
	if _is_common(entry.definition):
		var requested: int = entry.available.back().requested_particles(_quality_for(entry.definition),context)
		var limit: int = clampi(int(context.get("particle_limit",600 if context.get("ultimate",false) else 300)),1,600)
		if common_particles() + requested > limit:
			_reject(effect_name,&"particle_budget")
			return null
	var effect: Node3D = entry.available.pop_back()
	effect.global_transform = Transform3D(Basis.IDENTITY,at) if at is Vector3 else at
	effect.apply_quality(1.0 if entry.definition.essential else _quality_for(entry.definition))
	var owner_id: int = context.actor.get_instance_id() if context.get("actor") is Node else 0
	_active[effect.get_instance_id()] = {"effect":effect,"name":effect_name,"owner_id":owner_id}
	_spawn_count += 1
	if _is_common(entry.definition):
		_prepare_common(effect,entry.definition,context)
	effect.play(context)
	return effect

func _reject(effect_name: StringName, reason: StringName) -> void:
	_drop_count += 1
	spawn_rejected.emit(effect_name,reason)

func release(effect: Node3D) -> bool:
	if not is_instance_valid(effect) or not _active.has(effect.get_instance_id()):
		return false
	var item: Dictionary = _active[effect.get_instance_id()]
	_active.erase(effect.get_instance_id())
	effect.reset()
	_entries[item.name].available.append(effect)
	return true

func _on_effect_finished(effect: Node3D) -> void:
	release(effect)

func clear() -> void:
	for item: Dictionary in _active.values():
		release(item.effect)

func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	_enabled = value
	if not enabled:
		for item: Dictionary in _active.values():
			if not _entries[item.name].definition.essential:
				release(item.effect)
	enabled_changed.emit(enabled)

func set_quality(value: Quality) -> void:
	_quality = clampi(value,Quality.LOW,Quality.HIGH) as Quality
	for entry: Dictionary in _entries.values():
		for effect: Node3D in entry.available:
			effect.apply_quality(1.0 if entry.definition.essential else _quality_for(entry.definition))
	quality_changed.emit(quality)

func warm_up() -> void:
	if _warming:
		return
	_warming = true
	warmup_complete = false
	warmup_started.emit()
	var can_render: bool = DisplayServer.get_name() != "headless"
	if can_render:
		_create_warmup_viewport()
	for entry: Dictionary in _entries.values():
		if entry.warmed:
			continue
		if can_render:
			# Borrow a real pooled scene and render it in an isolated world.
			var effect: Node3D = entry.available.pop_back()
			effect.reparent(_warm_root,false)
			effect.transform = Transform3D(Basis.IDENTITY,Vector3(0,0.5,0))
			effect.configure(maxf(entry.definition.duration,entry.definition.warmup_seconds+0.5),500 if entry.definition.ultimate else 200)
			effect.apply_quality(1)
			var payload: Dictionary = entry.definition.warmup_context.duplicate()
			payload["warmup"] = true
			effect.play(payload)
			await RenderingServer.frame_post_draw
			if not _is_common(entry.definition):
				await get_tree().create_timer(entry.definition.warmup_seconds).timeout
			await RenderingServer.frame_post_draw
			# Readback ensures this is an actual render, not just resource preloading.
			var rendered_image: Image = _warm_viewport.get_texture().get_image()
			entry.rendered = rendered_image != null and not rendered_image.is_empty()
			entry["warmup_draws"] = _warm_viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
			effect.reset()
			effect.reparent(_pool_root,false)
			effect.transform = Transform3D.IDENTITY
			effect.configure(clampf(entry.definition.duration,0.02,30),500 if entry.definition.ultimate else 200)
			effect.apply_quality(1.0 if entry.definition.essential else _quality_for(entry.definition))
			entry.available.append(effect)
		entry.warmed = true
	if is_instance_valid(_warm_viewport):
		_warm_viewport.queue_free()
		_warm_viewport = null
		_warm_root = null
		await get_tree().process_frame
		await get_tree().process_frame
	_warming = false
	warmup_complete = true
	warmup_rendered = can_render
	for entry: Dictionary in _entries.values():
		warmup_rendered = warmup_rendered and entry.rendered
	warmup_finished.emit(warmup_rendered)

func _create_warmup_viewport() -> void:
	_warm_viewport = SubViewport.new()
	_warm_viewport.name = "WarmupViewport"
	_warm_viewport.size = Vector2i(128,128)
	_warm_viewport.own_world_3d = true
	_warm_viewport.process_mode = Node.PROCESS_MODE_ALWAYS
	_warm_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warm_viewport)
	_warm_root = Node3D.new()
	_warm_viewport.add_child(_warm_root)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.layers = 8
	var plane := PlaneMesh.new()
	plane.size = Vector2(8,8)
	floor_mesh.mesh = plane
	_warm_root.add_child(floor_mesh)
	var camera: Camera3D = Camera3D.new()
	_warm_root.add_child(camera)
	camera.position = Vector3(0,1.1,3)
	camera.look_at(Vector3(0,0.5,0))
	camera.current = true
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	_warm_root.add_child(sun)
	sun.rotation_degrees = Vector3(-45,-30,0)

func stats() -> Dictionary:
	var pooled: int = 0
	var available: int = 0
	var particles: int = 0
	for entry: Dictionary in _entries.values():
		pooled += entry.instances.size()
		available += entry.available.size()
	for item: Dictionary in _active.values():
		particles += item.effect.effective_particles()
	return {"pooled":pooled,"available":available,"active":_active.size(),"particle_budget":particles,"spawned":_spawn_count,"dropped":_drop_count,"observed":_observed.size(),"warmup_complete":warmup_complete,"warmup_rendered":warmup_rendered}

func _scan(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_scan(child)

func _on_node_added(node: Node) -> void:
	if node is Node3D and (node.has_signal("shield_broken") or node.has_signal("ability_action_started")):
		if node.is_node_ready():
			observe_actor(node)
		else:
			node.ready.connect(observe_actor.bind(node),CONNECT_ONE_SHOT)

func observe_actor(actor: Node3D) -> void:
	if _observed.has(actor.get_instance_id()):
		return
	_observed[actor.get_instance_id()] = weakref(actor)
	actor.tree_exiting.connect(_actor_left.bind(actor.get_instance_id()))
	var abilities: Node = actor.get_node_or_null("AbilitySystem")
	if abilities and abilities.has_signal("ability_cast_started"):
		abilities.connect("ability_cast_started",_cast_started.bind(actor))
	var combat: Node = actor.get_node_or_null("PlayerCombat")
	if combat and combat.has_signal("hit_landed"):
		combat.connect("hit_landed",_hit_landed.bind(actor))
	if actor.has_signal("shield_broken"):
		actor.connect("shield_broken",_shield_broken.bind(actor))
	if actor.has_signal("hit_reacted"):
		actor.connect("hit_reacted",_received_hit.bind(actor))
	if actor.has_signal("ability_action_finished"):
		actor.connect("ability_action_finished",_action_finished.bind(actor))
	# Reserved signals have declarations only: no combat emissions added in task 0.2.
	if actor.has_signal("presentation_cast_started"):
		actor.connect("presentation_cast_started",_reserved_cast.bind(actor))
	if actor.has_signal("presentation_skill_finished"):
		actor.connect("presentation_skill_finished",_reserved_end.bind(actor))
	if combat and combat.has_signal("presentation_impact_frame"):
		combat.connect("presentation_impact_frame",_impact_frame.bind(actor))

func _context(actor: Node3D) -> Dictionary:
	return {"actor":actor,"hero":StringName(actor.get("hero_profile")) if actor.has_signal("ability_action_started") else &"dummy","position":actor.global_position+Vector3.UP,"normal":Vector3.UP}

func _cast_started(_slot: String, ability: Resource, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	payload["skill"] = StringName(ability.id)
	dispatch(&"cast_started",payload)

func _hit_landed(target: Node, damage: float, blocked: bool, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	payload["target"] = target
	payload["damage"] = damage
	payload["position"] = target.global_position+Vector3.UP if target is Node3D else payload.position
	dispatch(&"block" if blocked else &"hit",payload)

func _received_hit(blocked: bool, direction: Vector3, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	payload["normal"] = direction
	# Separate names avoid duplicating caster-side hit/block effects.
	dispatch(&"received_block" if blocked else &"received_hit",payload)

func _shield_broken(actor: Node3D) -> void:
	dispatch(&"shield_break",_context(actor))

func _action_finished(slot: String, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	var system: Node = actor.get_node_or_null("AbilitySystem")
	var ability: Resource = system.get_ability(slot) if system else null
	payload["skill"] = StringName(ability.id) if ability else StringName(slot)
	dispatch(&"skill_finished",payload)

func _reserved_cast(skill: StringName, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	payload["skill"] = skill
	dispatch(&"cast_started",payload)

func _reserved_end(skill: StringName, cancelled: bool, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	payload["skill"] = skill
	payload["cancelled"] = cancelled
	dispatch(&"skill_finished",payload)

func _impact_frame(skill: StringName, position: Vector3, normal: Vector3, actor: Node3D) -> void:
	var payload: Dictionary = _context(actor)
	payload["skill"] = skill
	payload["position"] = position
	payload["normal"] = normal
	dispatch(&"impact_frame",payload)

func dispatch(event: StringName, payload: Dictionary) -> void:
	presentation_event.emit(event,payload)
	for effect_name: StringName in _bindings.get(event,[]):
		var definition: Resource = _entries[effect_name].definition
		if not definition.hero.is_empty() and definition.hero != payload.get("hero",&""):
			continue
		if not definition.skill.is_empty() and definition.skill != payload.get("skill",&""):
			continue
		spawn(effect_name,Transform3D(Basis.IDENTITY,payload.get("position",Vector3.ZERO)),payload)

func _actor_left(id: int) -> void:
	_observed.erase(id)
	for item: Dictionary in _active.values():
		if item.owner_id == id:
			release(item.effect)

func _is_common(definition: Resource) -> bool:
	return definition.scene.resource_path.begins_with("res://vfx/common/")

func _quality_for(definition: Resource) -> float:
	return COMMON_MULTIPLIERS[quality] if _is_common(definition) else MULTIPLIERS[quality]

func common_particles() -> int:
	var count := 0
	for item: Dictionary in _active.values():
		if _is_common(_entries[item.name].definition):
			count += item.effect.effective_particles()
	return count

func warmup() -> void:
	if _warming:
		await warmup_finished
	else:
		await warm_up()

# Existing actor recoil owns camera motion; no parallel shake system.
func camera_recoil(actor: Node, type: int = 0) -> void:
	if is_instance_valid(actor) and actor.has_method("apply_camera_recoil"):
		actor.apply_camera_recoil(clampi(type,0,2))

func hit_stop(visual: AnimationPlayer, seconds: float = 0.06) -> bool:
	_visual_stop.enabled = hit_stop_enabled
	return _visual_stop.hit_stop(visual,seconds)

# Optional visual parameters for Z; defaults are restored on every lease.
func _prepare_common(effect: Node3D, definition: Resource, params: Dictionary) -> void:
	effect.configure(clampf(definition.duration,0.02,30),200)
	if not effect.particles:
		return
	var defaults: Dictionary = _common_defaults[effect.get_instance_id()]
	effect.motion.direction = params.get("direction",defaults.direction)
	effect.motion.spread = params.get("spread",defaults.spread)
	effect.motion.initial_velocity_min = params.get("speed_min",defaults.initial_velocity_min)
	effect.motion.initial_velocity_max = params.get("speed_max",defaults.initial_velocity_max)
	effect.particles.lifetime = clampf(params.get("particle_lifetime",defaults.lifetime),0.05,defaults.lifetime)
	if params.has("particle_lifetime"):
		effect.duration = effect.particles.lifetime+0.05

func try_spawn(effect_name: StringName, at: Variant, params: Dictionary = {}) -> Node3D:
	if not _entries.has(effect_name) or not enabled:
		return null
	var entry: Dictionary = _entries[effect_name]
	if not entry.warmed or entry.available.is_empty():
		return null
	if _is_common(entry.definition):
		var count: int = entry.available.back().requested_particles(_quality_for(entry.definition),params)
		var limit:=clampi(int(params.get("particle_limit",600 if params.get("ultimate",false) else 300)),1,600)
		if common_particles()+count > limit:
			return null
	return spawn(effect_name,at,params)
