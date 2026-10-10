extends Node

const ArcherDashBuilder = preload("res://scripts/ArcherDashBuilder.gd")

## Presentation controller for Elf Archer's agile hunter dash (phím Q / Dodge).
## Matches Knight's core dodge mechanics while providing sleek, acrobatic hunter animations & forest leaf wind VFX.

const FADE := 0.08
const ENTRY_BLEND := 0.03
const MOVEMENT_BLEND := 0.12
const CLIPS: Array[StringName] = [&"dash_forward", &"dash_back", &"dash_left", &"dash_right"]

var player: PlayerController
var model: Node3D
var animations: AnimationPlayer
var active := false
var tail_active := false
var selected_clip: StringName = &""
var _heading := 0.0
var _base_rotation := Vector3.ZERO
var _restore: Tween
var movement_blend_remaining := 0.0

var _leaf_particles: CPUParticles3D

func _ready() -> void:
	process_priority = 1
	call_deferred("_bind")

func _bind() -> void:
	player = get_parent() as PlayerController
	if not player or player.hero_profile != "archer" or not player.anim_player or not player.dodge_controller:
		set_process(false)
		set_physics_process(false)
		return

	model = player.visuals.get_node_or_null("CharacterModel") as Node3D
	animations = player.anim_player
	if not model or not animations:
		return

	_base_rotation = model.rotation

	# Register custom agile archer dash animations into AnimationLibrary
	var library: AnimationLibrary = animations.get_animation_library("")
	if library:
		var clips_dict: Dictionary = ArcherDashBuilder.build_library()
		for clip_name in clips_dict:
			if library.has_animation(clip_name):
				library.remove_animation(clip_name)
			library.add_animation(clip_name, clips_dict[clip_name])

	for clip in CLIPS:
		if animations.has_animation(clip):
			animations.get_animation(clip).loop_mode = Animation.LOOP_NONE

	player.dodge_controller.dodge_started.connect(_on_started)
	player.state_changed.connect(_on_state_changed)
	if player.has_signal("ability_action_started"):
		player.ability_action_started.connect(_on_cast_started)
	animations.animation_finished.connect(_on_animation_finished)

	_setup_leaf_vfx()

func _setup_leaf_vfx() -> void:
	_leaf_particles = CPUParticles3D.new()
	_leaf_particles.name = "ArcherDashLeafVFX"
	_leaf_particles.emitting = false
	_leaf_particles.one_shot = true
	_leaf_particles.explosiveness = 0.85
	_leaf_particles.lifetime = 0.45
	_leaf_particles.amount = 16

	# Green leaf material
	var mat := StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.28, 0.72, 0.36, 0.95)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var quad := QuadMesh.new()
	quad.size = Vector2(0.10, 0.06)
	quad.material = mat
	_leaf_particles.mesh = quad

	_leaf_particles.direction = Vector3(0, 0.5, 1)
	_leaf_particles.spread = 45.0
	_leaf_particles.initial_velocity_min = 2.5
	_leaf_particles.initial_velocity_max = 5.0
	_leaf_particles.gravity = Vector3(0, -3.0, 0)

	player.add_child(_leaf_particles)

func select_clip(world_direction: Vector3, facing: Basis) -> StringName:
	var local_direction := facing.orthonormalized().inverse() * world_direction
	if absf(local_direction.z) >= absf(local_direction.x):
		return &"dash_forward" if local_direction.z <= 0.0 else &"dash_back"
	return &"dash_left" if local_direction.x < 0.0 else &"dash_right"

func _on_started(_direction: DodgeController.Direction, world_direction: Vector3) -> void:
	print("ArcherDashPresentation._on_started called! world_dir=", world_direction)
	_clear_movement_blend()
	if not model or not animations:
		print("ArcherDashPresentation: model or animations null!")
		return
	if is_instance_valid(_restore):
		_restore.kill()
	model.rotation = _base_rotation
	selected_clip = select_clip(world_direction, player.visuals.global_basis)
	if not animations.has_animation(selected_clip):
		selected_clip = &"dash_forward"

	_heading = model.global_rotation.y
	active = true
	tail_active = false
	animations.speed_scale = 1.0
	animations.play(selected_clip, ENTRY_BLEND)
	animations.seek(0.0, true)

	# Trigger emerald leaf swoosh
	if _leaf_particles:
		_leaf_particles.global_position = player.global_position + Vector3(0, 0.6, 0)
		_leaf_particles.direction = -world_direction + Vector3(0, 0.4, 0)
		_leaf_particles.restart()

func _on_state_changed(_old: int, next: int) -> void:
	if not active:
		if next not in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN]:
			_clear_movement_blend()
		return
	if next == PlayerController.CombatState.IDLE and not player.dodge_controller.is_dodging and not _has_move_input():
		tail_active = true
	elif next != PlayerController.CombatState.DODGE:
		_finish(&"run" if next == PlayerController.CombatState.RUN else &"idle", MOVEMENT_BLEND if next == PlayerController.CombatState.RUN else FADE)

func _on_cast_started(_slot: String, _ability: AbilityData) -> void:
	_clear_movement_blend()
	if tail_active:
		_finish()

func _on_animation_finished(clip: StringName) -> void:
	if active and clip == selected_clip:
		_finish()

func _has_move_input() -> bool:
	if player.external_controlled:
		return player.external_move_direction.length_squared() > 0.0001
	return absf(Input.get_axis("move_left", "move_right")) > 0.01 or absf(Input.get_axis("move_forward", "move_backward")) > 0.01

func hold_locomotion() -> bool:
	if not active:
		return false
	if player.combat_state == PlayerController.CombatState.DODGE:
		return true
	if player.combat_state == PlayerController.CombatState.IDLE and not _has_move_input() and not player.is_control_impaired() and player.controls_enabled and not (player.active_ability_action and player.active_ability_action.is_active()) and animations.current_animation == selected_clip:
		tail_active = true
		return true
	_finish(&"run" if _has_move_input() else &"idle", MOVEMENT_BLEND if _has_move_input() else FADE)
	return false

func _physics_process(_delta: float) -> void:
	if active and model:
		model.global_rotation.y = _heading
	elif movement_blend_remaining > 0.0 and model:
		var amount := clampf(1.0 - movement_blend_remaining / MOVEMENT_BLEND, 0.0, 1.0)
		amount = amount * amount * (3.0 - 2.0 * amount)
		model.global_rotation.y = lerp_angle(_heading, player.visuals.global_rotation.y + _base_rotation.y, amount)

func _process(delta: float) -> void:
	if movement_blend_remaining > 0.0:
		if player and (player.is_control_impaired() or not player.controls_enabled):
			_clear_movement_blend()
		else:
			movement_blend_remaining = maxf(0.0, movement_blend_remaining - delta)
			if movement_blend_remaining == 0.0 and model:
				model.rotation = _base_rotation
	if not active or not player:
		return
	if player.combat_state == PlayerController.CombatState.DEAD or player.is_control_impaired() or not player.controls_enabled:
		_finish()
	elif animations.current_animation != selected_clip:
		_finish()
	elif tail_active:
		hold_locomotion()

func _unhandled_input(event: InputEvent) -> void:
	if not tail_active and movement_blend_remaining <= 0.0:
		return
	for action in [&"move_left", &"move_right", &"move_forward", &"move_backward", &"attack", &"block", &"dodge", &"skill_1", &"skill_2", &"skill_3", &"ultimate"]:
		if event.is_action_pressed(action):
			var moving: bool = action in [&"move_left", &"move_right", &"move_forward", &"move_backward"]
			if not moving:
				_clear_movement_blend()
			_finish(&"run" if moving else &"idle", MOVEMENT_BLEND if moving else FADE)
			break

func _finish(fallback: StringName = &"idle", blend: float = FADE) -> void:
	if not active:
		return
	active = false
	tail_active = false
	if animations and animations.current_animation == selected_clip and animations.has_animation(fallback):
		animations.speed_scale = 1.0
		animations.play(fallback, blend)
	if animations and animations.current_animation == &"run" and fallback == &"run":
		movement_blend_remaining = blend
	if is_instance_valid(_restore):
		_restore.kill()
	if model and is_inside_tree() and movement_blend_remaining <= 0.0:
		_restore = create_tween()
		_restore.tween_property(model, "rotation", _base_rotation, FADE)

func _clear_movement_blend() -> void:
	if movement_blend_remaining <= 0.0:
		return
	movement_blend_remaining = 0.0
	if is_instance_valid(_restore):
		_restore.kill()
	if model:
		model.rotation = _base_rotation

func _exit_tree() -> void:
	if is_instance_valid(_restore):
		_restore.kill()
	if is_instance_valid(model):
		model.rotation = _base_rotation
