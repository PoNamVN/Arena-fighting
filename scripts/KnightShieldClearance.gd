extends RefCounted
## Cache eight rigid bone-space bounds once. Fit the visual shield, never the actor.
var skeleton:Skeleton3D
var bones:PackedInt32Array
var bounds:Array[AABB]=[]
var panel:AABB
var prepared:=false
var last_shift:=0.0
func prepare(sk:Skeleton3D,body:MeshInstance3D,shield:MeshInstance3D) -> void:
 skeleton=sk
 var boxes:Dictionary={}
 for surface in body.mesh.get_surface_count():
  var arrays:=body.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  for v in vertices.size():
   for j in 4:
    if weights[v*4+j]<.5:continue
    var bind:=indices[v*4+j]
    var name:String=body.skin.get_bind_name(bind)
    if name not in ["hand.R","forearm.R","hand.L","forearm.L","head","chest","upper_arm.R","upper_arm.L"]:continue
    var bone:=sk.find_bone(name)
    var point:Vector3=body.skin.get_bind_pose(bind)*vertices[v]
    boxes[bone]=boxes[bone].expand(point) if boxes.has(bone) else AABB(point,Vector3.ZERO)
 for bone:int in boxes:
  bones.append(bone);bounds.append(boxes[bone])
 var first:=true
 for surface in shield.mesh.get_surface_count():
  var material:=shield.mesh.surface_get_material(surface)
  if not material or ("Bronze" not in material.resource_name and "Steel" not in material.resource_name):continue
  var vertices:PackedVector3Array=shield.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
  for vertex in vertices:
   var point:Vector3=shield.transform*vertex
   panel=AABB(point,Vector3.ZERO) if first else panel.expand(point)
   first=false
 prepared=not first and bones.size()>0
func fit(root:Node3D) -> float:
 last_shift=0
 if not prepared or not root.visible or root.scale.x<1.1:return 0.0
 var inverse:=root.global_transform.affine_inverse()*skeleton.global_transform
 var scale:=root.global_basis.z.length()
 # Keep room for the measured glove, rear grip and the short impact recoil.
 var rear:=panel.position.z-.16/scale
 var shift:=0.0
 for i in bones.size():
  var box:AABB=(inverse*skeleton.get_bone_global_pose(bones[i]))*bounds[i]
  if box.end.x<panel.position.x or box.position.x>panel.end.x or box.end.y<panel.position.y or box.position.y>panel.end.y:continue
  shift=maxf(shift,box.end.z-rear)
 if shift>.000001:
  root.global_position+=root.global_basis.z*shift
  last_shift=shift*scale
 return last_shift
