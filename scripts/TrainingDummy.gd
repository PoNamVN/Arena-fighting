class_name TrainingDummy
extends StaticBody3D

## Configuration
@export var normal_color: Color = Color(0.85, 0.45, 0.25, 1.0)
@export var hit_color: Color = Color(1.0, 0.2, 0.2, 1.0)
@export var block_flash_color: Color = Color(0.3, 0.6, 1.0, 1.0) # Blue flash when blocked
@export var defeated_color: Color = Color(0.35, 0.35, 0.4, 1.0)
@export var is_blocking: bool = false
@export var block_damage_reduction: float = 0.85
@export var block_cone_deg: float = 120.0
@export var shield_max_durability: float = 100.0
@export var normal_attack_shield_damage: float = 15.0
@export var shield_recovery_delay: float = 2.0
@export var auto_reset_on_death: bool = true
@export var reset_delay: float = 1.5

## Task 5.7: Hit Reaction & Knockback Tuning
@export var hit_reaction_duration: float = 0.15
@export var hit_knockback_distance: float = 0.40
@export var hit_knockback_duration: float = 0.10
@export var block_recoil_distance: float = 0.08

var hawk_carry: HawkCarryEffect
var frost: FreezeEffect
var polymorph: PolymorphEffect
var _knockback_tween: Tween = null
var _flinch_tween: Tween = null
var _hit_reaction_count: int = 0

const NO_ATTACKER_POS: Vector3 = Vector3(99999.0, 99999.0, 99999.0)

var shield_durability: float = 100.0
var is_shield_broken: bool = false
var _shield_recovery_timer: float = 0.0
var _last_hit_was_blocked: bool = false

var max_hp: float:
	get:
		return health_component.max_health if health_component else 100.0
	set(value):
		if health_component:
			health_component.max_health = value
			health_component.current_health = minf(health_component.current_health, value)

var current_hp: float:
	get:
		return health_component.current_health if health_component else 0.0
	set(value):
		if health_component:
			health_component.current_health = value
			_update_health_bar(health_component.current_health, health_component.max_health)

func is_alive() -> bool:
	return health_component != null and not health_component.is_dead()

func is_dead() -> bool:
	return health_component == null or health_component.is_dead()

func is_targetable() -> bool:
	return is_alive()

signal shield_durability_changed(current: float, maximum: float)
signal shield_broken()
signal shield_restored()
signal hit_reacted(is_blocked: bool, hit_dir: Vector3)
signal respawned()

## Node References
@onready var health_component: HealthComponent = $HealthComponent
@onready var body_mesh: MeshInstance3D = $Visuals/BodyMesh
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/ProgressBar") as ProgressBar
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite") as Sprite3D

## Internal State
var _mesh_material: StandardMaterial3D
var _hit_tween: Tween
var _reset_tween: Tween
var _initial_transform: Transform3D


func _ready() -> void:
	hawk_carry = HawkCarryEffect.new()
	hawk_carry.actor = self
	add_child(hawk_carry)
	polymorph = PolymorphEffect.new()
	polymorph.actor = self
	add_child(polymorph)
	frost = FreezeEffect.new()
	frost.actor = self
	add_child(frost)
	add_to_group("enemies")
	add_to_group("training_dummy")
	_initial_transform = global_transform
	# Ensure dummy has an independent material instance for hit flash
	_setup_material()
	_setup_health_bar()

	# Wire health signals
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
		_update_health_bar(health_component.current_health, health_component.max_health)


func _setup_health_bar() -> void:
	var viewport: SubViewport = get_node_or_null("HealthBarViewport") as SubViewport
	if not viewport:
		viewport = SubViewport.new()
		viewport.name = "HealthBarViewport"
		viewport.transparent_bg = true
		viewport.size = Vector2i(140, 22)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)

		var bar: ProgressBar = ProgressBar.new()
		bar.name = "ProgressBar"
		bar.custom_minimum_size = Vector2(140, 22)
		bar.anchors_preset = Control.PRESET_FULL_RECT
		bar.show_percentage = true
		bar.max_value = max_hp
		bar.value = current_hp
		viewport.add_child(bar)
		progress_bar = bar
	else:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.transparent_bg = true
		if not progress_bar and viewport.has_node("ProgressBar"):
			progress_bar = viewport.get_node("ProgressBar") as ProgressBar

	if not health_bar_sprite:
		health_bar_sprite = get_node_or_null("HealthBarSprite") as Sprite3D
	if not health_bar_sprite:
		health_bar_sprite = Sprite3D.new()
		health_bar_sprite.name = "HealthBarSprite"
		add_child(health_bar_sprite)

	health_bar_sprite.position = Vector3(0, 2.65, 0)
	health_bar_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_bar_sprite.no_depth_test = true
	health_bar_sprite.render_priority = 10
	health_bar_sprite.pixel_size = 0.008
	health_bar_sprite.texture = viewport.get_texture()
	health_bar_sprite.visible = true

	if progress_bar:
		var fill_style: StyleBox = progress_bar.get_theme_stylebox("fill")
		if fill_style:
			progress_bar.add_theme_stylebox_override("fill", fill_style.duplicate())


func _process(delta: float) -> void:
	if is_shield_broken:
		if _shield_recovery_timer > 0.0:
			_shield_recovery_timer -= delta
			if _shield_recovery_timer <= 0.0:
				restore_shield()


func take_damage(amount: float, attacker_pos: Vector3 = NO_ATTACKER_POS, was_blocked: bool = false) -> void:
	if health_component and health_component.is_dead():
		return

	var will_die: bool = (health_component and health_component.current_health - amount <= 0.0)
	var blocked: bool = was_blocked or (amount < 20.0 and amount > 0.0)
	_last_hit_was_blocked = blocked

	if health_component:
		health_component.take_damage(amount)

	if not will_die and attacker_pos != NO_ATTACKER_POS and not hawk_carry.active():
		var to_me: Vector3 = global_position - attacker_pos
		to_me.y = 0.0
		var hit_dir: Vector3 = to_me.normalized() if to_me.length_squared() > 0.0001 else Vector3.BACK
		_apply_dummy_reaction(hit_dir, blocked)


func _apply_dummy_reaction(hit_dir: Vector3, is_blocked_hit: bool) -> void:
	_hit_reaction_count += 1
	var kb_dist: float = block_recoil_distance if is_blocked_hit else hit_knockback_distance

	# Procedural visual recoil and tilt on Visuals (springs back cleanly to baseline)
	var visuals: Node3D = get_node_or_null("Visuals") as Node3D
	if visuals:
		if _flinch_tween and _flinch_tween.is_valid():
			_flinch_tween.kill()
		_flinch_tween = create_tween()
		var tilt_mag: float = deg_to_rad(4.0) if is_blocked_hit else deg_to_rad(12.0)
		var visual_offset: Vector3 = hit_dir * (kb_dist * 0.5)
		# Flinch back & tilt
		_flinch_tween.tween_property(visuals, "position", visual_offset, 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_flinch_tween.parallel().tween_property(visuals, "rotation:x", -tilt_mag, 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Spring back to baseline
		_flinch_tween.tween_property(visuals, "position", Vector3.ZERO, hit_reaction_duration - 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_flinch_tween.parallel().tween_property(visuals, "rotation:x", 0.0, hit_reaction_duration - 0.05)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

	hit_reacted.emit(is_blocked_hit, hit_dir)


func apply_shield_damage(amount: float) -> void:
	if is_shield_broken:
		return
	var prev_durability: float = shield_durability
	shield_durability = maxf(0.0, shield_durability - amount)
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	if prev_durability > 0.0 and shield_durability <= 0.0:
		break_shield()


func break_shield() -> void:
	if is_shield_broken:
		return
	is_shield_broken = true
	shield_durability = 0.0
	_shield_recovery_timer = shield_recovery_delay
	shield_durability_changed.emit(0.0, shield_max_durability)
	shield_broken.emit()


func restore_shield() -> void:
	if not is_shield_broken:
		return
	is_shield_broken = false
	_shield_recovery_timer = 0.0
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)
	shield_restored.emit()


func reset_shield_durability() -> void:
	is_shield_broken = false
	_shield_recovery_timer = 0.0
	shield_durability = shield_max_durability
	shield_durability_changed.emit(shield_durability, shield_max_durability)


func _on_damaged(_amount: float) -> void:
	if not _last_hit_was_blocked:
		_flash_hit_effect()


func _on_health_changed(new_health: float, max_hp: float) -> void:
	_update_health_bar(new_health, max_hp)


func _on_died() -> void:
	if frost:
		frost.clear()
	if polymorph:
		polymorph.clear()
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	if _mesh_material:
		_mesh_material.albedo_color = defeated_color

	_update_health_bar(0.0, max_hp)

	if auto_reset_on_death:
		if _reset_tween and _reset_tween.is_valid():
			_reset_tween.kill()
		_reset_tween = create_tween()
		_reset_tween.tween_interval(reset_delay)
		_reset_tween.tween_callback(reset_dummy)


func reset_dummy() -> void:
	if hawk_carry: hawk_carry.clear()
	if frost:
		frost.clear()
	if polymorph:
		polymorph.clear()
	if _reset_tween and _reset_tween.is_valid():
		_reset_tween.kill()
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()
	if _knockback_tween and _knockback_tween.is_valid():
		_knockback_tween.kill()
	if _flinch_tween and _flinch_tween.is_valid():
		_flinch_tween.kill()

	var visuals: Node3D = get_node_or_null("Visuals") as Node3D
	if visuals:
		visuals.position = Vector3.ZERO
		visuals.rotation = Vector3.ZERO

	if health_component:
		health_component.reset_health()
		_update_health_bar(health_component.current_health, health_component.max_health)

	reset_shield_durability()
	_last_hit_was_blocked = false

	if _mesh_material:
		_mesh_material.albedo_color = normal_color

	respawned.emit()


var is_flashing_hit: bool:
	get:
		return _hit_tween != null and _hit_tween.is_valid()


func flash_hit() -> void:
	_flash_hit_effect()


func _flash_hit_effect() -> void:
	if not _mesh_material or (health_component and health_component.is_dead()):
		return
	if _hit_tween and _hit_tween.is_valid():
		_hit_tween.kill()

	_mesh_material.albedo_color = hit_color
	_hit_tween = create_tween()
	_hit_tween.tween_property(_mesh_material, "albedo_color", normal_color, 0.18)


func _update_health_bar(current: float, max_hp_val: float) -> void:
	if not progress_bar:
		return
	progress_bar.max_value = max_hp_val
	progress_bar.value = clampf(current, 0.0, max_hp_val)

	var ratio: float = current / max_hp_val if max_hp_val > 0.0 else 0.0
	var fill_style: StyleBoxFlat = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if ratio > 0.5:
			fill_style.bg_color = Color(0.2, 0.85, 0.35, 1.0)
		elif ratio > 0.25:
			fill_style.bg_color = Color(0.95, 0.75, 0.2, 1.0)
		else:
			fill_style.bg_color = Color(0.9, 0.25, 0.2, 1.0)


func _setup_material() -> void:
	if body_mesh:
		var existing_mat: Material = body_mesh.get_surface_override_material(0)
		if not existing_mat and body_mesh.mesh:
			existing_mat = body_mesh.mesh.material
		if existing_mat is StandardMaterial3D:
			_mesh_material = existing_mat.duplicate() as StandardMaterial3D
		else:
			_mesh_material = StandardMaterial3D.new()
			_mesh_material.albedo_color = normal_color
			_mesh_material.roughness = 0.6
		body_mesh.set_surface_override_material(0, _mesh_material)
