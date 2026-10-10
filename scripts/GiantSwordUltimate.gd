class_name GiantSwordUltimate
extends Node

signal finisher_frame_ready(frame: Texture2D)

const TARGET_DISTANCE: float = 24.0
const ZOOM_DURATION: float = 0.45
const CAMERA_CLEARANCE: float = 1.0
const CLOUD_REVEAL_SECONDS: float = 0.8
const DESCENT_PLAYBACK: float = 0.65
const HANDOFF_SECONDS: float = 0.65
var _coronation: Node3D
var _coronation_active: bool = false
var _coronation_entry: Transform3D
var _finisher_frame_requested: bool = false
var _victory_camera_held: bool = false
var _coronation_orbit_angle: float = .56
var _coronation_shot_height: float = 5.0
var _coronation_path_ready: bool = false
var _column_visual_layers: Dictionary = {}
const CORONATION_COLUMN_LAYER: int = 1 << 19
var _cloud_reveal_remaining: float = 0.0
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
var _cast_origin: Vector3
var _label: Label
var _hud: CanvasLayer
var _shake_timer: float = 0.0
var _shake_elapsed: float = 0.0
var _cinematic: Node
var _frozen: bool = false
var _bars: Array[ColorRect] = []
var _shot_back: Vector3 = Vector3.BACK
var _shot_distance_scale: float = 1.0
var _camera_shape: SphereShape3D = SphereShape3D.new()
var _camera_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
var _camera_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	player = get_parent() as PlayerController
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cinematic = get_node("/root/UltimateCinematic")
	_coronation = preload("res://scripts/KnightCoronation.gd").new()
	_coronation.name = "KnightCoronation"
	add_child(_coronation)
	_camera_query.shape = _camera_shape
	_camera_query.collision_mask = 1
	_camera_query.margin = 0.01
	_camera_ray.collision_mask = 1
	cinematic_camera = Camera3D.new()
	cinematic_camera.name = "UltimateCamera"
	cinematic_camera.top_level = true
	cinematic_camera.fov = 75.0
	cinematic_camera.far = 300.0
	add_child(cinematic_camera)
	_hud = CanvasLayer.new()
	_hud.layer = 100
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
	for bottom: bool in [false, true]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar.anchor_top = .94 if bottom else 0.0
		bar.anchor_bottom = 1.0 if bottom else .06
		_hud.add_child(bar)
		bar.hide()
		_bars.append(bar)
	_hud.hide()


func begin() -> void:
	release_victory_camera()
	_restore_coronation_columns()
	_coronation_path_ready = false
	_finisher_frame_requested = false
	_coronation_active = false
	_coronation.stop()
	_presentation_active = true
	cinematic_camera.fov = 75.0
	for bar in _bars:
		bar.hide()
		bar.color.a = 1.0
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
	if not _cinematic.begin(self, _hud):
		return
	_frozen = true
	_cloud_reveal_remaining = CLOUD_REVEAL_SECONDS
	for bar in _bars: bar.show()
	aiming = false
	_label.text = ""
	var action: AbilityAction = player.active_ability_action
	action.custom_data["impact_origin"] = target_position
	action.phase_timer = action.data.startup_duration
	_select_camera_shot()
	if player.combat.radial_ability_can_finish(action.data, target_position):
		_select_coronation_shot()
		_exclude_coronation_columns()
		_coronation_active = true
		action.custom_data["ultimate_finisher"] = true
		action.phase_timer = _coronation.SWORD_HIT
		_cloud_reveal_remaining = 0.0
		cinematic_camera.global_position = target_position + _shot_back * 22.0 * _shot_distance_scale + Vector3.UP * _coronation_shot_height
		cinematic_camera.look_at(target_position + Vector3.UP * 68.0)
		_coronation_entry = cinematic_camera.global_transform
		_coronation.begin(target_position, player.combat.giant_sword_vfx)
		return
	var back: Vector3 = _shot_back
	cinematic_camera.global_position = target_position + back * 14.0 * _shot_distance_scale + Vector3.UP * 26.0
	cinematic_camera.look_at(target_position + Vector3.UP * 46.0)
	cinematic_camera.fov = _shot_fov(48.0)
	_camera_goal = cinematic_camera.global_transform
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
		var previous: Vector3 = cinematic_camera.global_position
		cinematic_camera.global_transform = _camera_start.interpolate_with(_camera_goal, progress)
		cinematic_camera.global_position = _safe_camera_motion(previous, cinematic_camera.global_position, 0.12)
		if not Input.is_action_pressed("attack"):
			_click_armed = true
		update_target(player.get_viewport().get_mouse_position())
		return
	var vfx: GiantSwordVFX = player.combat.giant_sword_vfx
	if _coronation_active:
		_tick_coronation(delta, action)
		return
	if action.current_phase == AbilityAction.Phase.STARTUP:
		var progress: float = clampf(1.0 - action.phase_timer / action.data.startup_duration, 0, 1)
		var back: Vector3 = _shot_back
		vfx.update_startup(action.phase_timer, action.data.startup_duration)
		var height: float = lerpf(26.0, 2.8, smoothstep(0.0, .82, progress))
		var desired: Vector3 = target_position + back * lerpf(14.0, 22.0, progress) * _shot_distance_scale + Vector3.UP * height
		cinematic_camera.global_position = _safe_camera_motion(cinematic_camera.global_position, desired, CAMERA_CLEARANCE)
		cinematic_camera.fov = _shot_fov(lerpf(48.0, 68.0, smoothstep(0, 1, progress)))
		var focus_y: float = maxf(9.0, vfx.sword.position.y + lerpf(0.0, 11.0, progress))
		cinematic_camera.look_at(target_position + Vector3.UP * focus_y)
		_camera_goal = cinematic_camera.global_transform
	elif action.current_phase == AbilityAction.Phase.ACTIVE:
		cinematic_camera.fov = _shot_fov(68.0)
		var back: Vector3 = _shot_back
		cinematic_camera.global_position = target_position + back * 22.0 * _shot_distance_scale + Vector3.UP * 3.2
		cinematic_camera.look_at(target_position + Vector3.UP * 9.0)
		_camera_goal = cinematic_camera.global_transform
	elif action.current_phase == AbilityAction.Phase.RECOVERY:
		vfx.update_recovery(action.phase_timer, action.data.recovery_duration)
		# Hold the impact shot through the travelling front and settling dust.
		var remaining: float = action.phase_timer
		for bar in _bars: bar.color.a = smoothstep(0.0, HANDOFF_SECONDS, remaining)
		if remaining < HANDOFF_SECONDS and is_instance_valid(_previous_camera):
			var previous: Vector3 = cinematic_camera.global_position
			cinematic_camera.global_transform = _camera_goal.interpolate_with(_previous_camera.global_transform, smoothstep(0, 1, 1 - remaining / HANDOFF_SECONDS))
			cinematic_camera.global_position = _safe_camera_motion(previous, cinematic_camera.global_position, lerpf(CAMERA_CLEARANCE, 0.12, smoothstep(0, 1, 1 - remaining / HANDOFF_SECONDS)))
			cinematic_camera.fov = lerpf(_shot_fov(68.0), _previous_camera.fov, smoothstep(0, 1, 1 - remaining / HANDOFF_SECONDS))
		else:
			cinematic_camera.global_transform = _camera_goal
			cinematic_camera.look_at(target_position + Vector3.UP * lerpf(9.0, 6.5, smoothstep(.3, 1.8, vfx._impact_elapsed)))
			_camera_goal = cinematic_camera.global_transform
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
	if vfx._impact_elapsed >= 0:
		var distance: float = Vector2(cinematic_camera.global_position.x - target_position.x, cinematic_camera.global_position.z - target_position.z).length()
		var arrival: float = vfx.wind_arrival_time(distance)
		var pulse: float = exp(-pow((vfx._impact_elapsed - arrival) / .16, 2.0)) * .22
		cinematic_camera.h_offset += sin(vfx._impact_elapsed * 39.0) * pulse
		cinematic_camera.v_offset += cos(vfx._impact_elapsed * 31.0) * pulse * .65



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
	_coronation_active = false
	_coronation.stop()
	_restore_coronation_columns()
	_frozen = false
	if _cinematic:
		_cinematic.end(self)
	aiming = false
	target_valid = false
	_hud.hide()
	cinematic_camera.h_offset = 0
	cinematic_camera.v_offset = 0
	_shake_timer = 0
	if not _victory_camera_held:
		cinematic_camera.clear_current(false)
		if is_instance_valid(_previous_camera): _previous_camera.make_current()
	player._update_head_visibility()
	player._is_mouse_captured = false if _victory_camera_held else _previous_capture
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _victory_camera_held else _previous_mouse_mode
	if player.combat and player.combat.giant_sword_vfx:
		player.combat.giant_sword_vfx.stop()


func _exit_tree() -> void:
	_restore_coronation_columns()
	release_victory_camera()
	if is_instance_valid(_cinematic):
		_cinematic.end(self)
	# Scene changes must not leave the cursor in targeting mode.
	if _presentation_active:
		Input.mouse_mode = _previous_mouse_mode
		_presentation_active = false


func cinematic_timeout_seconds() -> float:
	return 14.0 if _coronation_active else 12.0

func _physics_process(delta: float) -> void:
	if not _frozen or not _cinematic.owns(self) or not get_tree().paused:
		return
	var action: AbilityAction = player.active_ability_action
	if not action or action.data.id != "giant_sword_ultimate" or not action.is_active():
		stop()
		return
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	if _coronation_active:
		# Advance presentation before the action: its sword contact and damage occur together.
		_tick_coronation(real_delta, action)
		var previous_phase: int = action.current_phase
		action.update(real_delta)
		if player.active_ability_action == action and action.is_active() and previous_phase != AbilityAction.Phase.RECOVERY and action.current_phase == AbilityAction.Phase.RECOVERY:
			action.phase_timer = maxf(.001, _coronation.DURATION - _coronation.elapsed)
		return
	player.combat.giant_sword_vfx.update_cloud_hold(real_delta)
	# Presentation-only reveal; the action clock and all other actors remain frozen.
	if _cloud_reveal_remaining > 0:
		_cloud_reveal_remaining = maxf(0, _cloud_reveal_remaining - real_delta)
		return
	var cast_delta: float = real_delta * DESCENT_PLAYBACK if action.current_phase == AbilityAction.Phase.STARTUP else real_delta
	action.update(cast_delta)
	if player.active_ability_action != action or not action.is_active():
		return
	tick(real_delta, action)
	if player.anim_player and player.anim_player.is_playing():
		player.anim_player.advance(cast_delta)

func _unhandled_input(event: InputEvent) -> void:
	if _frozen and _cinematic.owns(self):
		handle_input(event)
		get_viewport().set_input_as_handled()

func cancel_cinematic() -> void:
	if player.active_ability_action:
		player.active_ability_action.cancel()
	else:
		stop()

func _point_clear(point: Vector3, radius: float) -> bool:
	_camera_shape.radius = radius
	_camera_query.transform = Transform3D(Basis.IDENTITY, point)
	_camera_query.motion = Vector3.ZERO
	return player.get_world_3d().direct_space_state.intersect_shape(_camera_query, 1).is_empty()


func _impact_visible(point: Vector3) -> bool:
	_camera_ray.from = point
	_camera_ray.to = target_position + Vector3.UP * 0.6
	return player.get_world_3d().direct_space_state.intersect_ray(_camera_ray).is_empty()


func _select_camera_shot() -> void:
	var preferred: Vector3 = Basis(Vector3.UP, player._camera_yaw).z.rotated(Vector3.UP, -0.4)
	_shot_back = preferred
	_shot_distance_scale = 1.0
	# Prefer another full-distance azimuth over squeezing the camera against a wall.
	for distance_scale: float in [1.0, 0.8, 0.6, 0.4, 0.25]:
		for angle: float in [0.0, PI/8, -PI/8, PI/4, -PI/4, 3*PI/8, -3*PI/8, PI/2, -PI/2, 5*PI/8, -5*PI/8, 3*PI/4, -3*PI/4, 7*PI/8, -7*PI/8, PI]:
			var back: Vector3 = preferred.rotated(Vector3.UP, angle)
			var start: Vector3 = target_position + back * 14.0 * distance_scale + Vector3.UP * 2.8
			var finish: Vector3 = target_position + back * 22.0 * distance_scale + Vector3.UP * 2.8
			if not _point_clear(start, CAMERA_CLEARANCE) or not _point_clear(finish, CAMERA_CLEARANCE):
				continue
			if not _impact_visible(start) or not _impact_visible(finish) or not _impact_visible(start.lerp(finish, 0.5)):
				continue
			_camera_query.transform.origin = start
			_camera_query.motion = finish - start
			var sweep: PackedFloat32Array = player.get_world_3d().direct_space_state.cast_motion(_camera_query)
			if sweep[0] < 1.0 or not _point_clear(finish + Vector3.UP * 0.4, CAMERA_CLEARANCE):
				continue
			_shot_back = back
			_shot_distance_scale = distance_scale
			return
	# Tight interiors: keep the camera on the target's side of the obstruction.
	var anchor: Vector3 = target_position + Vector3.UP * 2.8
	_shot_distance_scale = 0.25
	_shot_back = (player.global_position - target_position).normalized()
	_shot_back.y = 0
	if _shot_back.length_squared() < 0.01:
		_shot_back = preferred
	_shot_back = _shot_back.normalized()
	_camera_query.transform.origin = anchor
	_camera_query.motion = _shot_back * 22.0 * _shot_distance_scale
	var sweep: PackedFloat32Array = player.get_world_3d().direct_space_state.cast_motion(_camera_query)
	_shot_distance_scale *= maxf(0.05, sweep[0] - 0.04)


func _shot_fov(base: float) -> float:
	return minf(110.0, rad_to_deg(2.0 * atan(tan(deg_to_rad(base) * 0.5) / maxf(_shot_distance_scale, 0.05))))


func _safe_camera_motion(start: Vector3, desired: Vector3, radius: float) -> Vector3:
	var motion: Vector3 = desired - start
	if motion.length_squared() < 0.000001:
		return start
	_camera_shape.radius = radius
	_camera_query.transform = Transform3D(Basis.IDENTITY, start)
	_camera_query.motion = motion
	var sweep: PackedFloat32Array = player.get_world_3d().direct_space_state.cast_motion(_camera_query)
	var safe: Vector3 = start + motion * maxf(0.0, sweep[0] - 0.02 / motion.length()) if sweep[0] < 1.0 else desired
	# During the opening lift, climb along the wall instead of stalling below it.
	if sweep[0] < 1.0 and desired.y > safe.y:
		_camera_query.transform.origin = safe
		_camera_query.motion = Vector3.UP * (desired.y - safe.y)
		var vertical: PackedFloat32Array = player.get_world_3d().direct_space_state.cast_motion(_camera_query)
		safe += _camera_query.motion * vertical[0]
	return safe if _point_clear(safe, radius) else start


func finish_presentation_timeout_seconds() -> float:
	return 12.0 if _coronation_active else 8.0


func _is_coronation_column(node: Node) -> bool:
	while is_instance_valid(node):
		if node.name == "GreekArenaRuins": return true
		node = node.get_parent()
	return false


func _coronation_view_clear(point: Vector3) -> bool:
	for offset: Vector3 in [Vector3(0,3,0), Vector3(-5,4,0), Vector3(5,4,0), Vector3(0,14,0), Vector3(0,28,0)]:
		_camera_ray.from = point; _camera_ray.to = target_position + offset
		var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(_camera_ray)
		# Decorative columns are excluded from this camera's render layer.
		if not hit.is_empty() and not _is_coronation_column(hit.collider): return false
	return true


func _coronation_arc_clear(back: Vector3, scale: float, height: float, turn: float) -> bool:
	var previous: Vector3 = target_position + back * 22.0 * scale + Vector3.UP * height
	for sample in 25:
		var at: Vector3 = target_position + back.rotated(Vector3.UP, turn * sample / 24.0) * 22.0 * scale + Vector3.UP * height
		if not _point_clear(at, CAMERA_CLEARANCE + .15) or not _coronation_view_clear(at): return false
		_camera_query.transform.origin = previous; _camera_query.motion = at - previous
		if _camera_query.motion.length_squared() > .00001:
			var sweep: PackedFloat32Array = player.get_world_3d().direct_space_state.cast_motion(_camera_query)
			if sweep[0] < 1.0: return false
		previous = at
	return true


func _select_coronation_shot() -> void:
	var preferred: Vector3 = Basis(Vector3.UP, player._camera_yaw).z.rotated(Vector3.UP, -.4)
	for scale: float in [1.0, .85, .70, .55, .4]:
		for height: float in [5.0, 8.0, 11.0]:
			for angle: float in [0.0, PI/4, -PI/4, PI/2, -PI/2, 3*PI/4, -3*PI/4, PI]:
				var back: Vector3 = preferred.rotated(Vector3.UP, angle)
				for turn: float in [.56, -.56]:
					if not _coronation_arc_clear(back, scale, height, turn): continue
					_shot_back = back; _shot_distance_scale = scale
					_coronation_shot_height = height; _coronation_orbit_angle = turn
					_coronation_path_ready = true
					return
	# A cramped custom arena can retain the already validated stationary shot.
	_coronation_orbit_angle = 0.0
	_coronation_shot_height = lerpf(12, 5, smoothstep(.25, .65, _shot_distance_scale))
	_coronation_path_ready = false


func _exclude_coronation_columns() -> void:
	for visual: MeshInstance3D in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		if not _is_coronation_column(visual): continue
		_column_visual_layers[visual] = visual.layers
		visual.layers = CORONATION_COLUMN_LAYER
	cinematic_camera.cull_mask &= ~CORONATION_COLUMN_LAYER


func _restore_coronation_columns() -> void:
	for visual in _column_visual_layers:
		if is_instance_valid(visual): visual.layers = _column_visual_layers[visual]
	_column_visual_layers.clear()
	if is_instance_valid(cinematic_camera): cinematic_camera.cull_mask |= CORONATION_COLUMN_LAYER


func _tick_coronation(delta: float, _action: AbilityAction) -> void:
	var victory_sequence: bool = _action.custom_data.get("ultimate_kill_confirmed", false) and not finisher_frame_ready.get_connections().is_empty()
	_coronation.hold_revelation = victory_sequence
	_coronation.advance(delta)
	var t: float = _coronation.elapsed
	# Ease into a slow 32-degree orbit, then settle before showing Victory.
	var orbit_progress: float = clampf((t - 5.8) / 3.0, 0.0, 1.0)
	# Quintic easing has zero velocity and acceleration at both ends.
	var eased: float = orbit_progress * orbit_progress * orbit_progress * (orbit_progress * (orbit_progress * 6.0 - 15.0) + 10.0)
	var orbit: float = eased * _coronation_orbit_angle if victory_sequence else smoothstep(5.5, 8.4, t) * _coronation_orbit_angle * .32
	var back: Vector3 = _shot_back.rotated(Vector3.UP, orbit)
	var shot_height: float = _coronation_shot_height
	var desired: Vector3 = target_position + back * 22.0 * _shot_distance_scale + Vector3.UP * shot_height
	if t < .7: desired = _coronation_entry.origin.lerp(desired, smoothstep(0.0, .7, t))
	var previous: Vector3 = cinematic_camera.global_position
	cinematic_camera.global_position = desired if _coronation_path_ready else _safe_camera_motion(previous, desired, CAMERA_CLEARANCE)
	var focus: float = 14.0
	if t < _coronation.ROCK_HIT: focus = maxf(14.0, _coronation.rock.position.y + 4.0)
	elif t >= _coronation.SWORD_DROP and t < _coronation.SWORD_HIT: focus = maxf(14.0, player.combat.giant_sword_vfx.sword.position.y + 8.0)
	cinematic_camera.look_at(target_position + Vector3.UP * focus)
	cinematic_camera.fov = _shot_fov(74.0)
	var impact: float = exp(-pow((t - _coronation.ROCK_HIT) / .15, 2.0)) * .55 + exp(-pow((t - _coronation.SWORD_HIT) / .12, 2.0)) * .45
	cinematic_camera.h_offset = sin(t * 79) * impact
	cinematic_camera.v_offset = cos(t * 67) * impact * .7
	# Save the fully revealed tableau before the camera and light fade back to gameplay.
	if not _finisher_frame_requested and t >= _coronation.DURATION - .3 and victory_sequence:
		_finisher_frame_requested = true
		_capture_finisher_frame(_action)
	var remaining: float = maxf(0.0, _coronation.DURATION - t)
	for bar in _bars: bar.color.a = 1.0 if victory_sequence else smoothstep(0.0, HANDOFF_SECONDS, remaining)
	if not victory_sequence and remaining < HANDOFF_SECONDS and is_instance_valid(_previous_camera):
		var blend: float = smoothstep(0.0, HANDOFF_SECONDS, HANDOFF_SECONDS - remaining)
		var shot: Transform3D = cinematic_camera.global_transform
		cinematic_camera.global_transform = shot.interpolate_with(_previous_camera.global_transform, blend)
		cinematic_camera.global_position = _safe_camera_motion(previous, cinematic_camera.global_position, lerpf(CAMERA_CLEARANCE, .12, blend))
		cinematic_camera.fov = lerpf(_shot_fov(74.0), _previous_camera.fov, blend)


func _capture_finisher_frame(action: AbilityAction) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not _coronation_active or player.active_ability_action != action or not action.is_active(): return
	var picture: Image = player.get_viewport().get_texture().get_image()
	if picture and not picture.is_empty():
		finisher_frame_ready.emit(ImageTexture.create_from_image(picture))


func hold_victory_camera() -> void:
	if _coronation_active and _presentation_active:
		_victory_camera_held = true


func release_victory_camera() -> void:
	if not _victory_camera_held: return
	_victory_camera_held = false
	if is_instance_valid(cinematic_camera) and cinematic_camera.is_inside_tree(): cinematic_camera.clear_current(false)
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree(): _previous_camera.make_current()
