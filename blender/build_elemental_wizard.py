"""Derive a separate forest hunter from the project's existing rigged body.
Run through Blender MCP; does not alter the Knight or environment scenes.
"""
import bpy, bmesh, math, json
from mathutils import Vector

scene = bpy.data.scenes.get('Elemental_Wizard_Work') or bpy.data.scenes.new('Elemental_Wizard_Work')
# Retry only this tool-created work scene after an interrupted build.
for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.context.window.scene = scene
bpy.ops.import_scene.gltf(filepath='D:/Game 3D/Game_3D/assets/models/player_character.glb')
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
body = next(o for o in scene.objects if o.type == 'MESH')
rig.name = 'ElementalWizardRig'
body.name = 'ElementalWizardBody'
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
colors = [(0.65,0.48,0.32,1),(0.08,0.12,0.3,1),(0.14,0.065,0.03,1),(0.1,0.16,0.4,1),(0.3,0.32,0.3,1),(0.06,0.08,0.18,1),(0.65,0.45,0.12,1)]
for i, old in enumerate(list(body.data.materials)):
    mat = old.copy(); mat.name = 'Wizard_' + old.name
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

green = material('Wizard_Hood', (.065,.16,.035,1))
wood = material('Wizard_YewWood', (.3,.13,.035,1))
ivory = material('Wizard_Fletching', (.75,.68,.38,1))
steel = material('Wizard_Arrowhead', (.38,.43,.43,1))

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


blue=material('Wizard_Robe',(.075,.12,.32,1))
silver=material('Wizard_Beard',(.8,.82,.76,1))
gold=material('Wizard_Trim',(.72,.47,.12,1))
def cone(name, rings, mat, bone):
    verts=[];faces=[];sides=10
    for z,r,cy in rings:
        for i in range(sides):
            a=i*math.tau/sides
            verts.append((math.cos(a)*r,cy+math.sin(a)*r,z))
    for j in range(len(rings)-1):
        for i in range(sides):
            a=j*sides+i;b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    obj=mesh_object(name,verts,faces,mat);bind(obj,bone);return obj
robe=cone('WizardRobe',[(.22,.34,0),(.85,.24,0),(1.36,.27,0)],blue,'hips')
hat=cone('WizardHat',[(1.72,.32,0),(1.77,.32,0),(1.8,.19,0),(2.14,.09,-.03),(2.27,.005,-.10)],blue,'head')
band=cone('HatGoldBand',[(1.79,.195,0),(1.85,.18,0)],gold,'head')
beard=mesh_object('LongSilverBeard',[(-.13,.12,1.62),(.13,.12,1.62),(-.12,.23,1.48),(.12,.23,1.48),(0,.25,1.18),(0,.29,1.45)],[(0,1,3,2),(2,3,5),(2,5,4),(3,4,5),(0,2,4),(1,4,3)],silver);bind(beard,'head')
brows=mesh_object('SilverBrows',[(-.14,.145,1.70),(-.02,.17,1.69),(-.02,.17,1.72),(-.14,.145,1.73),(.02,.17,1.69),(.14,.145,1.7),(.14,.145,1.73),(.02,.17,1.72)],[(0,1,2,3),(4,5,6,7)],silver);bind(brows,'head')
def branch(name,points,r):
    verts=[];faces=[]
    for x,y,z in points:
        for i in range(7):
            a=i*math.tau/7;verts.append((x+math.cos(a)*r,y+math.sin(a)*r,z))
    for j in range(len(points)-1):
        for i in range(7):
            a=j*7+i;b=j*7+(i+1)%7;faces.append((a,b,b+7,a+7))
    faces.extend([tuple(range(6,-1,-1)),tuple((len(points)-1)*7+i for i in range(7))])
    return mesh_object(name,verts,faces,wood)
staff=branch('AncientBranchStaff',[(0,0,-.75),(.025,0,-.2),(-.035,0,.4),(.04,0,.9),(.12,0,1.18),(.02,0,1.3)],.042)
fork=branch('StaffFork',[(.02,0,.7),(-.15,0,1.02),(-.12,0,1.2)],.025)
def export(objects,path,animations=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=animations,export_animation_mode='NLA_TRACKS')
character=[rig,body,robe,hat,band,beard,brows]
export(character,'D:/Game 3D/Game_3D/assets/models/elemental_wizard.glb',True)
export([staff,fork],'D:/Game 3D/Game_3D/assets/models/wizard_staff.glb')
staff.hide_set(True);fork.hide_set(True)
bpy.data.libraries.write('D:/Game 3D/Game_3D/tools/blender_sources/elemental_wizard.blend',{scene},fake_user=True,compress=True)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_distance=3.6
        area.spaces.active.region_3d.view_location=Vector((0,0,1.1))
print(json.dumps({'scene':scene.name,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in character if o.type=='MESH'),'staff_triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in [staff,fork])}))
