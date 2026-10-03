"""Derive a separate forest hunter from the project's existing rigged body.
Run through Blender MCP; does not alter the Knight or environment scenes.
"""
import bpy, bmesh, math, json
from mathutils import Vector

scene = bpy.data.scenes.get('Forest_Archer_Work') or bpy.data.scenes.new('Forest_Archer_Work')
# Retry only this tool-created work scene after an interrupted build.
for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.context.window.scene = scene
bpy.ops.import_scene.gltf(filepath='D:/Game 3D/Game_3D/assets/models/player_character.glb')
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
body = next(o for o in scene.objects if o.type == 'MESH')
rig.name = 'ForestHunterRig'
body.name = 'ForestHunterBody'
for track in list(rig.animation_data.nla_tracks):
    if track.name not in ['idle','run','dead']:
        rig.animation_data.nla_tracks.remove(track)
rig.animation_data.action = None
# Imported GLB has split normals/vertices. Filter weapon faces by material and
# hand weights rather than spatial deletion, preserving the hands themselves.
bm = bmesh.new(); bm.from_mesh(body.data)
deform = bm.verts.layers.deform.active
hand_groups = {body.vertex_groups[n].index for n in ['hand.L', 'hand.R', 'forearm.L']}
remove = []
for f in bm.faces:
    material_name = body.data.materials[f.material_index].name
    weapon_hand = deform and any(any(g in hand_groups for g in v[deform].keys()) for v in f.verts)
    helmet = 'Bronze' in material_name and min(v.co.z for v in f.verts) > 1.50
    if 'Steel' in material_name or 'Crest' in material_name or helmet or (weapon_hand and ('Bronze' in material_name or 'Gold' in material_name)):
        remove.append(f)
bmesh.ops.delete(bm, geom=remove, context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(body.data); bm.free()
# Give each material its own datablock so the Knight palette stays intact.
colors = [(0.61,0.39,0.23,1),(0.09,0.22,0.07,1),(0.18,0.095,0.035,1),(0.12,0.28,0.08,1),(0.3,0.32,0.3,1),(0.05,0.12,0.03,1),(0.62,0.4,0.1,1)]
for i, old in enumerate(list(body.data.materials)):
    mat = old.copy(); mat.name = 'Hunter_' + old.name
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = colors[i]
    node.inputs['Metallic'].default_value = 0.0
    node.inputs['Roughness'].default_value = 0.85
    mat.diffuse_color = colors[i]
    body.data.materials[i] = mat

def material(name, color):
    mat = bpy.data.materials.new(name); mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = color
    node.inputs['Roughness'].default_value = .8
    mat.diffuse_color = color
    return mat

green = material('Hunter_Hood', (.065,.16,.035,1))
wood = material('Hunter_YewWood', (.3,.13,.035,1))
ivory = material('Hunter_Fletching', (.75,.68,.38,1))
steel = material('Hunter_Arrowhead', (.38,.43,.43,1))

def mesh_object(name, verts, faces, mat):
    mesh = bpy.data.meshes.new(name); mesh.from_pydata(verts, [], faces); mesh.update()
    obj = bpy.data.objects.new(name, mesh); scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

def bind(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    obj.parent = rig
    mod = obj.modifiers.new('HunterSkin', 'ARMATURE'); mod.object = rig

# Open-front angular hood and short cape, kept separate from the source body.
hood = mesh_object('HunterHood', [(-.17,-.14,1.48),(.17,-.14,1.48),(-.17,.16,1.5),(.17,.16,1.5),(-.17,-.14,1.76),(.17,-.14,1.76),(-.17,.16,1.76),(.17,.16,1.76),(0,-.03,1.9)], [(0,4,5,1),(0,2,6,4),(1,5,7,3),(4,8,5),(4,6,8),(5,8,7),(6,7,8)], green)
bind(hood,'head')
cape = mesh_object('HunterCape',[(-.25,-.16,1.43),(.25,-.16,1.43),(-.30,-.23,.83),(.30,-.23,.83),(0,-.30,.77)],[(0,2,4),(0,4,1),(1,4,3)],green)
bind(cape,'chest')

def tube(name, points, radius, mat):
    verts=[]; faces=[]
    for p in points:
        for i in range(6):
            a=i*math.tau/6; verts.append((p[0]+math.cos(a)*radius,p[1]+math.sin(a)*radius,p[2]))
    for j in range(len(points)-1):
        for i in range(6):
            a=j*6+i;b=j*6+(i+1)%6;faces.append((a,b,b+6,a+6))
    faces.extend([tuple(range(5,-1,-1)),tuple((len(points)-1)*6+i for i in range(6))])
    return mesh_object(name,verts,faces,mat)

quiver=tube('HunterQuiver',[(.12,-.22,1.0),(.12,-.24,1.55)],.07,wood);bind(quiver,'chest')
for i in range(3):
    feather=tube('QuiverArrow'+str(i),[(.08+i*.04,-.24,1.40),(.08+i*.04,-.24,1.73)],.012,ivory);bind(feather,'chest')

# Simple weapon props are exported independently, with the grip at the origin.
bow=tube('HunterBow',[(0,-.10,-.58),(0,.06,-.40),(0,0,-.18),(0,0,.18),(0,.06,.40),(0,-.10,.58)],.027,wood)
# Arrow points along Blender +Y, which becomes Godot -Z.
shaft=mesh_object('ArrowShaft',[(-.012,0,-.012),(.012,0,-.012),(.012,0,.012),(-.012,0,.012),(-.012,.68,-.012),(.012,.68,-.012),(.012,.68,.012),(-.012,.68,.012)],[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(0,3,2,1),(4,5,6,7)],wood)
tip=mesh_object('ArrowTip',[(-.045,.65,0),(.045,.65,0),(0,.65,.025),(0,.65,-.025),(0,.80,0)],[(0,2,4),(2,1,4),(1,3,4),(3,0,4),(0,3,1,2)],steel)
feathers=mesh_object('ArrowFeathers',[(-.055,.04,0),(0,0,0),(0,.18,0),(.055,.04,0),(0,.04,.055)],[(0,1,2),(1,3,2),(1,4,2)],ivory)

def export(objects,path,animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=animations,export_animation_mode='NLA_TRACKS')

character=[rig,body,hood,cape,quiver]+[o for o in scene.objects if o.name.startswith('QuiverArrow')]
export(character,'D:/Game 3D/Game_3D/assets/models/forest_archer.glb',True)
export([bow],'D:/Game 3D/Game_3D/assets/models/hunter_bow.glb')
export([shaft,tip,feathers],'D:/Game 3D/Game_3D/assets/models/hunter_arrow.glb')
for obj in [bow,shaft,tip,feathers]:obj.hide_set(True)
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=3.4
        area.spaces.active.region_3d.view_location=Vector((0,0,1))
print(json.dumps({'scene':scene.name,'character_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in character if o.type=='MESH'),'bow_triangles':sum(len(p.vertices)-2 for p in bow.data.polygons)}))
