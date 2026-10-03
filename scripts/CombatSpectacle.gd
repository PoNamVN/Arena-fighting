extends Node3D

# Fixed visual budget. Saturation reuses the oldest burst, never allocates more nodes.
const POOL_SIZE: int = 6
const SHARDS: int = 24
const LIFETIME: float = 0.75
const SIGIL: Shader = preload("res://assets/shaders/combat_sigil.gdshader")
var actor: PlayerController
var bursts: Array[Dictionary] = []
var cursor: int = 0
var triggered: int = 0
var _model: Node3D
var _model_rest: Transform3D
var _recoil: float = 0
var _lean: float = 0

static func sigil_material(color: Color, style: float = 0.0) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SIGIL
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("style", style)
	return material

func _ready() -> void:
	process_priority = 110
	actor = get_parent() as PlayerController
	_model = actor.visuals.get_node("CharacterModel") as Node3D
	_model_rest = _model.transform
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(2, 2)
	var shard: PrismMesh = PrismMesh.new()
	shard.size = Vector3(0.09, 0.3, 0.09)
	var shard_material: StandardMaterial3D = StandardMaterial3D.new()
	shard_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard_material.vertex_color_use_as_albedo = true
	shard.material = shard_material
	for index: int in range(POOL_SIZE):
		var root_node: Node3D = Node3D.new()
		add_child(root_node)
		root_node.top_level = true
		var rings: Array[MeshInstance3D] = []
		for layer: int in range(2):
			var ring: MeshInstance3D = MeshInstance3D.new()
			ring.mesh = plane
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ring.material_override = sigil_material(Color.WHITE, 1)
			root_node.add_child(ring)
			rings.append(ring)
		var sparks: MultiMeshInstance3D = MultiMeshInstance3D.new()
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var batch: MultiMesh = MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = shard
		batch.instance_count = SHARDS
		batch.visible_instance_count = 0
		sparks.multimesh = batch
		root_node.add_child(sparks)
		root_node.hide()
		bursts.append({"root": root_node, "rings": rings, "batch": batch, "age": LIFETIME, "radius": 1.0, "power": 1.0})
	set_process(false)

func burst(point: Vector3, color: Color, radius: float = 1.5, power: float = 1.0, ground: bool = true) -> void:
	if not actor.controls_enabled or actor.is_dead:
		return
	var slot: Dictionary = bursts[cursor]
	cursor = (cursor + 1) % POOL_SIZE
	triggered += 1
	slot.age = 0.0
	slot.radius = clampf(radius, 0.4, 9.0)
	slot.power = clampf(power, 0.3, 2.0)
	slot.root.global_transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.08)
	if not ground:
		slot.root.rotation.x = PI / 2
	for ring: MeshInstance3D in slot.rings:
		(ring.material_override as ShaderMaterial).set_shader_parameter("tint", color)
		(ring.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.7)
	for i: int in range(SHARDS):
		slot.batch.set_instance_color(i, color.lightened(0.25 if i % 3 == 0 else 0))
	slot.batch.visible_instance_count = SHARDS
	slot.root.show()
	_recoil = maxf(_recoil, 0.12)
	set_process(true)
	_update_slot(slot)

func shooting() -> void:
	_recoil = 0.22
	set_process(true)

func wake() -> void:
	set_process(true)

func _process(delta: float) -> void:
	if actor.is_dead or not actor.controls_enabled or actor.is_control_impaired():
		clear()
		return
	var busy: bool = false
	for slot: Dictionary in bursts:
		if slot.age >= LIFETIME:
			continue
		slot.age += delta
		if slot.age >= LIFETIME:
			slot.root.hide()
			slot.batch.visible_instance_count = 0
		else:
			_update_slot(slot)
			busy = true
	_recoil = maxf(0, _recoil - delta)
	var bow: ArcherCombat = actor.archer_combat
	var drawing: bool = bow and (bow.charging or bow.volley_active or bow.seeking_active)
	var target_lean: float = 0.10 if drawing else -0.12 * (_recoil / 0.22)
	var knight_casting: bool = actor.hero_profile == "knight" and actor.active_ability_action != null and actor.active_ability_action.is_active()
	if knight_casting:
		var id: String = actor.active_ability_action.data.id
		if id == "shield_charge":
			target_lean = -0.24 if actor.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE else -0.10
		elif id == "sky_dive":
			target_lean = -0.16 if actor.active_ability_action.current_phase == AbilityAction.Phase.ACTIVE else 0.08
	if bow or actor.hero_profile == "knight":
		_lean = lerpf(_lean, target_lean, 1 - exp(-12 * delta))
		_model.transform = _model_rest * Transform3D(Basis(Vector3.RIGHT, _lean), Vector3.ZERO)
		if bow:
			bow._bow.transform = Transform3D(Basis(Vector3.RIGHT, _lean), Vector3.ZERO) * bow._bow.transform
		busy = busy or drawing or knight_casting or absf(_lean) > 0.001 or _recoil > 0
	if not busy:
		if bow or actor.hero_profile == "knight":
			_model.transform = _model_rest
		set_process(false)

func _update_slot(slot: Dictionary) -> void:
	var t: float = slot.age / LIFETIME
	for layer: int in range(2):
		var ring: MeshInstance3D = slot.rings[layer]
		var progress: float = clampf((t - layer * 0.12) / 0.88, 0, 1)
		var size: float = slot.radius * (0.25 + sqrt(progress) * 0.9)
		ring.scale = Vector3(size, 1, size)
		ring.position.y = layer * 0.025
		(ring.material_override as ShaderMaterial).set_shader_parameter("opacity", pow(1 - progress, 2) * 0.75)
	for i: int in range(SHARDS):
		var angle: float = TAU * float(i) / SHARDS + i * 0.37
		var speed: float = (1.0 + (i % 5) * 0.32) * slot.radius
		var point: Vector3 = Vector3(cos(angle) * speed * slot.age, (2.0 + i % 4) * slot.power * slot.age - 4 * slot.age * slot.age, sin(angle) * speed * slot.age)
		var rotation: Basis = Basis(Vector3(cos(angle), 0.2, sin(angle)).normalized(), slot.age * 5 + i)
		slot.batch.set_instance_transform(i, Transform3D(rotation.scaled(Vector3.ONE * (1 - t)), point))

func clear() -> void:
	for slot: Dictionary in bursts:
		slot.age = LIFETIME
		slot.root.hide()
		slot.batch.visible_instance_count = 0
	_recoil = 0
	_lean = 0
	if is_instance_valid(_model) and actor.hero_profile != "wizard":
		_model.transform = _model_rest
	set_process(false)
