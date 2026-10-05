extends RefCounted
## Legacy rig suffixes are reversed relative to gameplay forward (-Z).
## Correct equipment and arm motion once at ready; never alter bone rests or
## shared imported resources. Cached resources are reused by Knight instances.
static var _equipment: Dictionary = {}
static var _animations: Dictionary = {}

static func opposite(name: String) -> String:
 if name in ["upper_arm.L","forearm.L","hand.L","thigh.L","shin.L","foot.L"]:return name.trim_suffix(".L")+".R"
 if name in ["upper_arm.R","forearm.R","hand.R","thigh.R","shin.R","foot.R"]:return name.trim_suffix(".R")+".L"
 return name

static func apply(model: Node3D, player: AnimationPlayer) -> void:
 if model.has_meta("right_handed_knight"):return
 var skeleton:=model.get_node("Gladiator_Armature/Skeleton3D") as Skeleton3D
 if not skeleton:return
 for name in ["Gladiator_Sword","Gladiator_Shield"]:
  var instance:=skeleton.get_node(name) as MeshInstance3D
  var id:=instance.mesh.get_instance_id()
  if not _equipment.has(id):
   _equipment[id]=_mirror_equipment(instance,skeleton)
  instance.mesh=_equipment[id].mesh
  instance.skin=_equipment[id].skin
 var original:=player.get_animation_library("")
 var library:=AnimationLibrary.new()
 for clip in original.get_animation_list():
  # Mirroring the opposite lateral dash preserves its requested world direction.
  var source:=original.get_animation("dash_right" if clip=="dash_left" else "dash_left" if clip=="dash_right" else clip)
  var id:=source.get_instance_id()
  if not _animations.has(id):_animations[id]=_mirror_pose(source)
  library.add_animation(clip,_animations[id])
 player.remove_animation_library("")
 player.add_animation_library("",library)
 model.set_meta("right_handed_knight",true)

static func _mirror_equipment(instance: MeshInstance3D,skeleton: Skeleton3D) -> Dictionary:
 var mirror:=Transform3D(Basis.from_scale(Vector3(-1,1,1)),Vector3.ZERO)
 var local:=instance.global_transform.affine_inverse()*skeleton.global_transform*mirror*skeleton.global_transform.affine_inverse()*instance.global_transform
 var built:=ArrayMesh.new()
 built.resource_name=instance.mesh.resource_name+"_RightHanded"
 for surface in instance.mesh.get_surface_count():
  var arrays:=instance.mesh.surface_get_arrays(surface).duplicate(true)
  var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  for i in positions.size():positions[i]=local*positions[i]
  arrays[Mesh.ARRAY_VERTEX]=positions
  var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
  for i in normals.size():normals[i]=(local.basis.inverse().transposed()*normals[i]).normalized()
  arrays[Mesh.ARRAY_NORMAL]=normals
  var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
  for i in range(0,tangents.size(),4):
   var tangent:Vector3=(local.basis*Vector3(tangents[i],tangents[i+1],tangents[i+2])).normalized()
   tangents[i]=tangent.x;tangents[i+1]=tangent.y;tangents[i+2]=tangent.z;tangents[i+3]=-tangents[i+3]
  arrays[Mesh.ARRAY_TANGENT]=tangents
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for i in range(0,indices.size(),3):
   var swap:=indices[i+1];indices[i+1]=indices[i+2];indices[i+2]=swap
  arrays[Mesh.ARRAY_INDEX]=indices
  built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  built.surface_set_material(surface,instance.mesh.surface_get_material(surface))
 var skin:=instance.skin.duplicate() as Skin
 for i in skin.get_bind_count():
  var old_name:=String(skin.get_bind_name(i))
  var old_index:=skeleton.find_bone(old_name) if not old_name.is_empty() else skin.get_bind_bone(i)
  var target_name:=opposite(skeleton.get_bone_name(old_index))
  var target_index:=skeleton.find_bone(target_name)
  var old_rest:=skeleton.get_bone_global_rest(old_index)
  var target_rest:=skeleton.get_bone_global_rest(target_index)
  skin.set_bind_pose(i,target_rest.affine_inverse()*mirror*old_rest*skin.get_bind_pose(i)*local.affine_inverse())
  skin.set_bind_name(i,target_name)
  skin.set_bind_bone(i,target_index)
 return {"mesh":built,"skin":skin}

static func _mirror_pose(source: Animation) -> Animation:
 var result:=source.duplicate(true) as Animation
 for track in result.get_track_count():
  var path:=result.track_get_path(track)
  var bone:=String(path.get_concatenated_subnames())
  var target:=opposite(bone)
  if not String(path.get_concatenated_names()).ends_with("Skeleton3D"):continue
  result.track_set_path(track,NodePath(String(path.get_concatenated_names())+":"+target))
  for key in result.track_get_key_count(track):
   var type:=result.track_get_type(track)
   if type==Animation.TYPE_ROTATION_3D:
    var rotation:Quaternion=result.track_get_key_value(track,key)
    result.track_set_key_value(track,key,Quaternion(rotation.x,-rotation.y,-rotation.z,rotation.w))
   elif type==Animation.TYPE_POSITION_3D:
    var position:Vector3=result.track_get_key_value(track,key)
    position.x=-position.x
    result.track_set_key_value(track,key,position)
 return result
