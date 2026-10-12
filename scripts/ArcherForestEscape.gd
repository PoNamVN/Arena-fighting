class_name ArcherForestEscape
extends Node3D

const ROLL_SECONDS := .5
const PATCHES := 128 # Enough for a five-second trail at sprint speed.
const BLADES := 12 # Tufts: seven folded leaves per instance.
const STEP_SPACING := .6
const REGION_RADIUS := 2.4
const GRASS_HOLD_SECONDS := 5.0
const GROW_SECONDS := .35
const FADE_SECONDS := .8
const SneakAnimations := preload("res://scripts/ArcherSneakAnimations.gd")
static var _tuft_mesh: ArrayMesh
var combat: ArcherCombat
var actor: PlayerController
var grass: MultiMeshInstance3D
var steps_spawned := 0
var _ages: Array[float] = []
var _idle_ages: Array[float] = []
var _points: Array[Vector3] = []
var _tufts: Array[Transform3D] = []
var _tuft_growth: Array[float] = []
var _rng := RandomNumberGenerator.new()
var _material: ShaderMaterial
var _travel := Vector3.FORWARD
var _bend_strength := 0.0
var _next := 0
var _last_step := Vector3.ZERO
var _was_owned := false
var _rest_rotations: Dictionary = {}
var _rest_positions: Dictionary = {}
var _skeleton_path := ""
var _walk_mode := false
var _walk_rate := 1.0
var _sneak_yaw := 0.0

func _ready() -> void:
	process_priority = 120
	preload("res://scripts/ArcherLegSkinFix.gd").apply(actor)
	_build_clips()
	grass = MultiMeshInstance3D.new()
	grass.name = "ForestFootstepGrass"
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.use_custom_data = true
	batch.mesh = _load_tuft_mesh()
	batch.instance_count = PATCHES * BLADES
	grass.multimesh = batch
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/archer_forest_grass.gdshader")
	grass.material_override = _material
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	grass.top_level = true
	grass.global_transform = Transform3D.IDENTITY
	_rng.seed = 3701
	for index in range(PATCHES):
		_ages.append(-1.0)
		_idle_ages.append(0.0)
		_points.append(Vector3.ZERO)
		for leaf in range(BLADES):
			_tufts.append(Transform3D.IDENTITY)
			_tuft_growth.append(0.0)
			batch.set_instance_transform(index * BLADES + leaf, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
			batch.set_instance_custom_data(index * BLADES + leaf, Color(_rng.randf() * TAU, 0, 0, 0))

func _load_tuft_mesh() -> ArrayMesh:
	if _tuft_mesh: return _tuft_mesh
	# Blender-exported triangle data also loads during runtime without an editor import.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/archer_tall_grass.mesh.json"))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for index in range(data.vertices.size()):
		var v: Array = data.vertices[index]
		var n: Array = data.normals[index]
		var c: Array = data.colors[index]
		vertices.append(Vector3(v[0], v[1], v[2]))
		normals.append(Vector3(n[0], n[1], n[2]))
		colors.append(Color(c[0], c[1], c[2], 1))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	_tuft_mesh = ArrayMesh.new()
	_tuft_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _tuft_mesh

func _build_clips() -> void:
	var library := actor.anim_player.get_animation_library("")
	var root := actor.anim_player.get_node(actor.anim_player.root_node)
	var path := String(root.get_path_to(actor._skeleton)) + ":"
	_skeleton_path = path
	var idle := actor.anim_player.get_animation("idle")
	for index in range(actor._skeleton.get_bone_count()):
		var bone := actor._skeleton.get_bone_name(index)
		var rotation_track := idle.find_track(NodePath(path + bone), Animation.TYPE_ROTATION_3D)
		var position_track := idle.find_track(NodePath(path + bone), Animation.TYPE_POSITION_3D)
		_rest_rotations[bone] = idle.rotation_track_interpolate(rotation_track, 0) if rotation_track >= 0 else actor._skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		_rest_positions[bone] = idle.position_track_interpolate(position_track, 0) if position_track >= 0 else actor._skeleton.get_bone_rest(index).origin
	for name: String in ["forest_roll"]:
		var animation := Animation.new()
		var rolling := name == "forest_roll"
		var walking := name == "forest_sneak_walk"
		animation.length = ROLL_SECONDS if rolling else .8
		animation.loop_mode = Animation.LOOP_NONE if rolling else Animation.LOOP_LINEAR
		for bone: String in ["hips", "chest", "thigh.L", "thigh.R", "shin.L", "shin.R"]:
			var index := actor._skeleton.find_bone(bone)
			if index < 0: continue
			var rotation := actor._skeleton.get_bone_pose_rotation(index)
			var idle_track := idle.find_track(NodePath(path + bone), Animation.TYPE_ROTATION_3D)
			if idle_track >= 0: rotation = idle.rotation_track_interpolate(idle_track, 0)
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(path + bone))
			for frame in range(17):
				var t := float(frame) / 16
				var swing := sin(t * TAU) * (.28 if walking else 0.0)
				var pitch := 0.0
				if bone == "hips": pitch = TAU * smoothstep(0, .82, t) if rolling else .22
				elif bone == "chest": pitch = .4
				elif bone.begins_with("thigh"): pitch = -.85 + (swing if bone.ends_with("L") else -swing)
				elif bone.begins_with("shin"): pitch = 1.25 + absf(swing) * .5
				animation.track_insert_key(track, animation.length * t, rotation * Quaternion(Vector3.RIGHT, pitch))
		var position_track := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position_track, NodePath(path + "hips"))
		for frame in range(17):
			var t := float(frame) / 16
			var height := .94 - (.94 - SneakAnimations.HIP_HEIGHT) * smoothstep(0, .25, t) + .6 * sin(t * PI)
			animation.track_insert_key(position_track, animation.length * t, Vector3(0, height, SneakAnimations.HIP_BACK * smoothstep(.82, 1, t)))
		# Roll also resets joints touched by the detailed sneak poses.
		for bone: String in _rest_rotations:
			if animation.find_track(NodePath(path + bone), Animation.TYPE_ROTATION_3D) >= 0: continue
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath(path + bone))
			animation.track_insert_key(track, 0, _rest_rotations[bone])
		var settle := SneakAnimations.pose(actor._skeleton, 0, false)
		for track in range(animation.get_track_count()):
			if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D: continue
			var bone := String(animation.track_get_path(track)).get_slice(":", 1)
			var keys: Array[Quaternion] = []
			for frame in range(17):
				var t := float(frame) / 16
				var source := animation.rotation_track_interpolate(track, animation.length * t)
				keys.append(source.slerp((settle[bone] as Basis).get_rotation_quaternion(), smoothstep(.82, 1, t)))
			while animation.track_get_key_count(track) > 0: animation.track_remove_key(track, 0)
			for frame in range(17): animation.track_insert_key(track, animation.length * frame / 16.0, keys[frame])
		if library.has_animation(name): library.remove_animation(name)
		library.add_animation(name, animation)
	for name: String in ["forest_sneak_idle", "forest_sneak_walk"]:
		if library.has_animation(name): library.remove_animation(name)
		library.add_animation(name, SneakAnimations.build(actor._skeleton, path, name == "forest_sneak_walk"))

func _restore_unkeyed_pose() -> void:
	var clip := actor.anim_player.get_animation(actor.anim_player.current_animation) if actor.anim_player.current_animation != "" else null
	for bone: String in _rest_rotations:
		var path := NodePath(_skeleton_path + bone)
		var index := actor._skeleton.find_bone(bone)
		if not clip or clip.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			actor._skeleton.set_bone_pose_rotation(index, _rest_rotations[bone])
		if not clip or clip.find_track(path, Animation.TYPE_POSITION_3D) < 0:
			actor._skeleton.set_bone_pose_position(index, _rest_positions[bone])

func owns_locomotion() -> bool:
	return combat.is_hidden() and actor.controls_enabled and not actor.is_dead and not actor.is_control_impaired() and not combat.charging and not combat.seeking_active and not combat.counter_active and not combat.hawk_skill.casting and not combat.bait_ultimate.input_busy() and actor.combat_state in [PlayerController.CombatState.IDLE, PlayerController.CombatState.RUN]

func begin() -> void:
	# Existing trails keep their own lifetime when C is recast, including with F2.
	_was_owned = false
	_last_step = actor.global_position
	_travel = combat.dash_direction
	actor.visuals.rotation.y = atan2(-_travel.x, -_travel.z)
	_sneak_yaw = actor.visuals.rotation.y
	actor.anim_player.speed_scale = 1.0
	actor.anim_player.play("forest_roll", .05)
	actor.anim_player.seek(0, true)
	_spawn_step()
	grass.visible = get_tree().root.get_node("VFXManager").enabled

func _process(delta: float) -> void:
	var owned := owns_locomotion()
	if owned:
		if not _was_owned: _sneak_yaw = actor.visuals.rotation.y
		var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
		if speed > .22: _walk_mode = true
		elif speed < .09: _walk_mode = false
		var clip := "forest_roll" if combat.dash_active else "forest_sneak_walk" if _walk_mode else "forest_sneak_idle"
		if actor.anim_player.current_animation != clip: actor.anim_player.play(clip, .16)
		_walk_rate = lerpf(_walk_rate, clampf(speed / SneakAnimations.NOMINAL_SPEED, .5, SneakAnimations.MAX_RATE), 1.0 - exp(-12.0 * delta))
		actor.anim_player.speed_scale = _walk_rate if clip == "forest_sneak_walk" else 1.0
		var direction := combat.dash_direction if combat.dash_active else Vector3(actor.velocity.x, 0, actor.velocity.z)
		if direction.length_squared() > .15:
			_travel = direction.normalized()
			var yaw := atan2(-_travel.x, -_travel.z)
			_sneak_yaw = yaw if combat.dash_active else lerp_angle(_sneak_yaw, yaw, 1.0 - exp(-14.0 * delta))
			actor.visuals.rotation.y = _sneak_yaw
	elif _was_owned:
		if actor.anim_player.current_animation.begins_with("forest_"):
			actor.anim_player.stop()
			actor._update_locomotion_animations()
		_restore_unkeyed_pose()
	_was_owned = owned
	if combat.is_hidden():
		if actor.is_on_floor():
			var distance := actor.global_position.distance_to(_last_step)
			if distance > 5.0: _spawn_step(actor.global_position) # Teleport: plant locally, no grass bridge.
			while actor.global_position.distance_to(_last_step) >= STEP_SPACING:
				var next := _last_step.move_toward(actor.global_position, STEP_SPACING)
				_spawn_step(next)
	_bend_strength = move_toward(_bend_strength, 1.0 if combat.is_hidden() else 0.0, delta * 5.0)
	_material.set_shader_parameter("hunter_position", actor.global_position)
	_material.set_shader_parameter("travel_direction", _travel)
	_material.set_shader_parameter("hunter_active", _bend_strength)
	var any_live := false
	var bounds := AABB()
	for patch in range(PATCHES):
		if _ages[patch] < 0: continue
		_ages[patch] += delta
		var offset := Vector2(_points[patch].x - actor.global_position.x, _points[patch].z - actor.global_position.z)
		var nearby := offset.length() <= REGION_RADIUS and absf(_points[patch].y - actor.global_position.y) < 1.5
		_idle_ages[patch] = 0.0 if nearby and combat.is_hidden() else _idle_ages[patch] + delta
		var birth := smoothstep(0, .18, _ages[patch])
		var remaining := 1.0 - smoothstep(GRASS_HOLD_SECONDS, GRASS_HOLD_SECONDS + FADE_SECONDS, _idle_ages[patch])
		var live := false
		for leaf in range(BLADES):
			var index := patch * BLADES + leaf
			var tuft := _tufts[index]
			var target := birth * remaining
			_tuft_growth[index] = move_toward(_tuft_growth[index], target, delta / GROW_SECONDS)
			var growth := _tuft_growth[index]
			live = live or growth > 0.0 or target > 0.0
			tuft.basis = tuft.basis.scaled(Vector3.ONE * growth)
			grass.multimesh.set_instance_transform(index, tuft)
		if not live:
			_ages[patch] = -1
		else:
			# The bounding box includes lingering grass behind the moving hunter.
			var patch_bounds := AABB(_points[patch] - Vector3(2.5, .5, 2.5), Vector3(5, 3, 5))
			bounds = bounds.merge(patch_bounds) if any_live else patch_bounds
			any_live = true
	grass.visible = get_tree().root.get_node("VFXManager").enabled and any_live
	if any_live: grass.custom_aabb = bounds

func _spawn_step(point: Vector3 = Vector3.INF) -> void:
	if point == Vector3.INF: point = actor.global_position
	# Reuse the same patch when walking back through existing grass.
	var patch := _next
	for index in range(PATCHES):
		if _ages[index] >= 0 and _points[index].distance_to(point) < STEP_SPACING * .8:
			_idle_ages[index] = 0.0
			_last_step = point
			return
	_ages[patch] = 0
	_idle_ages[patch] = 0
	_points[patch] = point
	var direction := Basis(Vector3.UP, atan2(-_travel.x, -_travel.z))
	for leaf in range(BLADES):
		var index := patch * BLADES + leaf
		var offset := Vector3(_rng.randf_range(-1.4, 1.4), .025, _rng.randf_range(-1.4, 1.4))
		var scale_y := _rng.randf_range(.9, 1.35)
		var scale_xz := _rng.randf_range(.65, 1.0)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(scale_xz, scale_y, scale_xz))
		var position := point + direction * offset
		var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 2, position - Vector3.UP * 3, 1)
		query.exclude = [actor.get_rid()]
		var ground := actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty(): position.y = ground.position.y + .015
		_tufts[index] = Transform3D(basis, position)
		_tuft_growth[index] = 0.0
		grass.multimesh.set_instance_color(index, Color(_rng.randf_range(.85, 1.15), _rng.randf_range(.85, 1.05), _rng.randf_range(.8, 1.1), 1))
	_next = (patch + 1) % PATCHES
	steps_spawned += 1
	_last_step = point

func clear() -> void:
	_next = 0
	_bend_strength = 0.0
	_was_owned = false
	for patch in range(_ages.size()): _ages[patch] = -1.0
	for patch in range(_idle_ages.size()): _idle_ages[patch] = 0.0
	for index in range(_tuft_growth.size()): _tuft_growth[index] = 0.0
	if grass:
		grass.visible = false
		for index in range(PATCHES * BLADES):
			grass.multimesh.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
