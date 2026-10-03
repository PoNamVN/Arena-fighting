class_name GiantSwordUltimate
extends Node

const TARGET_DISTANCE: float = 24.0
const ZOOM_DURATION: float = 0.45
var aiming: bool = false
var _presentation_active: bool = false
var target_valid: bool = false
var target_position: Vector3 = Vector3.ZERO
var cinematic_camera: Camera3D
var player: PlayerController
var _previous_camera: Camera3D
var _previous_mouse_mode: int
var _previous_capture: bool
var _elapsed: float = 0.0
var _entry_frame: int = -1
var _click_armed: bool = false
var _camera_start: Transform3D
var _camera_goal: Transform3D
var _fall_camera_start: Transform3D
var _cast_origin: Vector3
var _label: Label
var _hud: CanvasLayer
var _shake_timer: float = 0.0
var _shake_elapsed: float = 0.0


func _ready() -> void:
	player = get_parent() as PlayerController
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "UltimateCamera"
	cinematic_camera.top_level = true
	cinematic_camera.fov = 75.0
	cinematic_camera.far = 300.0
	add_child(cinematic_camera)
	_hud = CanvasLayer.new()
	_hud.layer = 12
	add_child(_hud)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_label.offset_top = -85
	_label.offset_bottom = -25
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_label)
	_hud.hide()


func begin() -> void:
	_presentation_active = true
	aiming = true
	target_valid = false
	_elapsed = 0.0
	_shake_timer = 0.0
	_entry_frame = Engine.get_physics_frames()
	_click_armed = not Input.is_action_pressed("attack")
	_previous_camera = player.get_viewport().get_camera_3d()
	_previous_mouse_mode = Input.mouse_mode
	_previous_capture = player._is_mouse_captured
	_cast_origin = player.global_position
	_camera_start = _previous_camera.global_transform if _previous_camera else player.camera.global_transform
	cinematic_camera.global_transform = _camera_start
	var back: Vector3 = Basis(Vector3.UP, player._camera_yaw).z
	cinematic_camera.global_position = _cast_origin + back * 24.0 + Vector3.UP * 25.0
	cinematic_camera.look_at(_cast_origin - back * 4.0)
	_camera_goal = cinematic_camera.global_transform
	cinematic_camera.global_transform = _camera_start
	cinematic_camera.make_current()
	player._is_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_hud.show()
	_label.text = "CHỌN ĐIỂM RƠI   •   CHUỘT TRÁI: TRIỆU HỒI   •   ESC: HỦY"
	if player.anim_player:
		player.anim_player.play("Knight_V_GiantSword")
		player.anim_player.seek(0.65, true)
		player.anim_player.pause()
	if player._skeleton:
		for bone: int in [player._head_bone_idx, player._neck_bone_idx]:
			if bone >= 0:
				player._skeleton.set_bone_pose_scale(bone, Vector3.ONE)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		# Selection cancellation returns the reservation; committed casts do not.
		if aiming and player.stamina_component:
			player.stamina_component.add_stamina(player.active_ability_action.data.stamina_cost)
		player.active_ability_action.cancel()
		return
	if not aiming:
		return
	if event.is_action_released("attack"):
		_click_armed = true
	if event.is_action_pressed("attack") and not event.is_echo() and _click_armed and Engine.get_physics_frames() > _entry_frame and _elapsed >= ZOOM_DURATION:
		var mouse_position: Vector2 = event.position if event is InputEventMouseButton else player.get_viewport().get_mouse_position()
		update_target(mouse_position)
		if target_valid:
			_confirm_target()


func update_target(screen_position: Vector2) -> void:
	var from: Vector3 = cinematic_camera.project_ray_origin(screen_position)
	var end: Vector3 = from + cinematic_camera.project_ray_normal(screen_position) * 250.0
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, end, 1)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	target_valid = not hit.is_empty()
	if target_valid:
		target_position = hit.position
		var difference: Vector3 = target_position - _cast_origin
		target_valid = hit.normal.y >= 0.7 and Vector2(difference.x, difference.z).length() <= TARGET_DISTANCE and absf(difference.y) <= 4.0
	if player.combat and player.combat.giant_sword_vfx:
		player.combat.giant_sword_vfx.show_target(target_position, player.active_ability_action.data.range, target_valid)
	_label.text = "CHỌN ĐIỂM RƠI   •   CHUỘT TRÁI: TRIỆU HỒI   •   ESC: HỦY" if target_valid else "CHỌN MẶT ĐẤT TRONG 24m   •   ESC: HỦY"


func _confirm_target() -> void:
	aiming = false
	var action: AbilityAction = player.active_ability_action
	action.custom_data["impact_origin"] = target_position
	action.phase_timer = action.data.startup_duration
	_fall_camera_start = cinematic_camera.global_transform
	var back: Vector3 = Basis(Vector3.UP, player._camera_yaw).z
	cinematic_camera.global_position = target_position + back * 42.0 + Vector3.UP * 28.0
	cinematic_camera.look_at(target_position + Vector3.UP * 14.0)
	_camera_goal = cinematic_camera.global_transform
	cinematic_camera.global_transform = _fall_camera_start
	_label.text = "THIÊN KIẾM GIÁNG THẾ"
	player.combat.giant_sword_vfx.begin(target_position, action.data.range)
	if player.anim_player:
		player.anim_player.play("Knight_V_GiantSword", 0.05)
		player.anim_player.seek(0.0, true)
		player.anim_player.speed_scale = 0.7 / action.data.startup_duration


func tick(delta: float, action: AbilityAction) -> void:
	if aiming:
		_elapsed += delta
		var progress: float = smoothstep(0, 1, clampf(_elapsed / ZOOM_DURATION, 0, 1))
		cinematic_camera.global_transform = _camera_start.interpolate_with(_camera_goal, progress)
		if not Input.is_action_pressed("attack"):
			_click_armed = true
		update_target(player.get_viewport().get_mouse_position())
		return
	var vfx: GiantSwordVFX = player.combat.giant_sword_vfx
	if action.current_phase == AbilityAction.Phase.STARTUP:
		var progress: float = clampf(1.0 - action.phase_timer / action.data.startup_duration, 0, 1)
		cinematic_camera.global_transform = _fall_camera_start.interpolate_with(_camera_goal, smoothstep(0, 1, clampf(progress * 3.0, 0, 1)))
		vfx.update_startup(action.phase_timer, action.data.startup_duration)
	elif action.current_phase == AbilityAction.Phase.RECOVERY:
		vfx.update_recovery(action.phase_timer, action.data.recovery_duration)
		# Ease back to the original gameplay camera only after seeing the impact.
		var remaining: float = action.phase_timer
		if remaining < 0.45 and is_instance_valid(_previous_camera):
			cinematic_camera.global_transform = _camera_goal.interpolate_with(_previous_camera.global_transform, smoothstep(0, 1, 1 - remaining / 0.45))
		else:
			cinematic_camera.global_transform = _camera_goal
	vfx.update_impact(delta)
	if _shake_timer > 0:
		_shake_timer = maxf(0, _shake_timer - delta)
		_shake_elapsed += delta
		var strength: float = _shake_timer / 0.65 * 0.65
		cinematic_camera.h_offset = sin(_shake_elapsed * 87) * strength
		cinematic_camera.v_offset = cos(_shake_elapsed * 71) * strength * 0.7
	else:
		cinematic_camera.h_offset = 0
		cinematic_camera.v_offset = 0


func impact() -> void:
	_shake_timer = 0.65
	_shake_elapsed = 0
	_label.text = ""
	if player.anim_player:
		player.anim_player.speed_scale = 1.0


func stop() -> void:
	if not _presentation_active:
		return
	_presentation_active = false
	aiming = false
	target_valid = false
	_hud.hide()
	cinematic_camera.h_offset = 0
	cinematic_camera.v_offset = 0
	_shake_timer = 0
	cinematic_camera.clear_current(false)
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	player._update_head_visibility()
	player._is_mouse_captured = _previous_capture
	Input.mouse_mode = _previous_mouse_mode
	if player.combat and player.combat.giant_sword_vfx:
		player.combat.giant_sword_vfx.stop()


func _exit_tree() -> void:
	# Scene changes must not leave the cursor in targeting mode.
	if _presentation_active:
		Input.mouse_mode = _previous_mouse_mode
		_presentation_active = false
