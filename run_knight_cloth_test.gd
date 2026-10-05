extends SceneTree
var count := 0
func check(ok: bool, label: String) -> void:
 count += 1
 if not ok:
  push_error(label)
  assert(ok, label)
func _init() -> void: call_deferred("run")
func make_actor() -> Node:
 var actor: Node = load("res://scenes/Player.tscn").instantiate()
 actor.external_controlled = true
 root.add_child(actor)
 return actor
func run() -> void:
 var actor := make_actor()
 var second := make_actor()
 await process_frame
 await process_frame
 actor.process_mode = Node.PROCESS_MODE_DISABLED
 second.process_mode = Node.PROCESS_MODE_DISABLED
 var cloth: Node = actor.get_node("KnightClothMotion")
 var other: Node = second.get_node("KnightClothMotion")
 check(cloth.material != null and other.material != null, "Both actors bind cloth")
 check(cloth.material != other.material, "Actor spring uniforms are independent")
 var shader: ShaderMaterial = cloth.material
 check(shader.resource_name == "Mat_Gladiator_Tunic.001", "Original material name retained")
 var nodes := get_node_count()
 var initial_bones: Array[Transform3D] = []
 for i in cloth.skeleton.get_bone_count(): initial_bones.append(cloth.skeleton.get_bone_pose(i))
 var root_transform: Transform3D = actor.transform
 var velocity: Vector3 = actor.velocity
 var results := []
 for fps in [30, 60, 144]:
  cloth.reset_motion()
  for frame in fps * 2:
   cloth.step_spring(Vector3(0, 0, -5), Vector3.ZERO, 0, 1.0 / fps)
   check(cloth.hem_offset.length() <= 0.090001, "Swing stays bounded")
  results.append(cloth.hem_offset)
  check(cloth.hem_offset.y > 0.04, "Moving forward drags hem backward")
  for frame in fps * 3: cloth.step_spring(Vector3.ZERO, Vector3.ZERO, 0, 1.0 / fps)
  check(cloth.hem_offset.length() < 0.0001 and cloth.hem_speed.length() < 0.001, "Hem settles after stopping")
 check(results[0].distance_to(results[1]) < 0.001 and results[1].distance_to(results[2]) < 0.001, "Spring comparable across FPS")
 for frame in 2000:
  cloth.step_spring(Vector3(20, -20, -20), Vector3(80, 80, 80), 20, .08)
  check(is_finite(cloth.hem_offset.x) and is_finite(cloth.hem_offset.y) and cloth.hem_offset.length() <= .090001, "Extreme dash remains finite and bounded")
 check(other.hem_offset == Vector2.ZERO, "Other actor does not inherit spring")
 check(get_node_count() == nodes, "No node allocation during spring updates")
 check(actor.transform == root_transform and actor.velocity == velocity, "Actor movement untouched")
 for i in initial_bones.size(): check(initial_bones[i] == cloth.skeleton.get_bone_pose(i), "Bone animation untouched")
 cloth.motion_enabled = false
 cloth._process(1.0 / 60.0)
 check(cloth.hem_offset == Vector2.ZERO and not bool(shader.get_shader_parameter("cloth_enabled")), "Disable resets and bypasses deformation")
 cloth.motion_enabled = true
 cloth._process(1.0 / 60.0)
 cloth.hem_offset = Vector2(.07, .03)
 actor.position += Vector3(100, 0, 0)
 cloth._process(1.0 / 60.0)
 check(cloth.hem_offset == Vector2.ZERO, "Teleport resets spring")
 var masked := 0
 var anchored := 0
 for surface in cloth.body.mesh.get_surface_count():
  var arrays: Array = cloth.body.mesh.surface_get_arrays(surface)
  var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
  var mat: Material = cloth.body.mesh.surface_get_material(surface)
  for color in colors:
   if color.a > .001:
    masked += 1
    check("Tunic" in mat.resource_name, "Only cloth vertices carry a mask")
   else: anchored += 1
 check(masked > 0 and anchored > masked, "Cloth mask leaves waist/body anchored")
 var ap: AnimationPlayer = actor.get_node("Visuals/CharacterModel/AnimationPlayer")
 var samples := 0
 for clip in ap.get_animation_list():
  ap.play(clip)
  for ratio in [0.0, .2, .4, .6, .8, 1.0]:
   ap.seek(ap.get_animation(clip).length * ratio, true)
   cloth.skeleton.force_update_all_bone_transforms()
   cloth._update_uniforms()
   check(cloth._starts.size() == 4 and cloth._ends.size() == 4, "Four leg capsules updated")
   for i in 4: check(cloth._starts[i].is_finite() and cloth._ends[i].is_finite(), "Capsules stay valid in every pose")
   samples += 1
 actor.queue_free(); second.queue_free()
 await process_frame
 print("CLOTH TEST PASS ", count, " checks; ", samples, " poses")
 quit()

