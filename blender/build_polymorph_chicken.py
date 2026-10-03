import bpy, math, json
from mathutils import Vector
scene=bpy.data.scenes.new('Wizard_Chicken_Work')
bpy.context.window.scene=scene
def mat(name,col):
 m=bpy.data.materials.new(name);m.use_nodes=True
 n=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 n.inputs['Base Color'].default_value=col;n.inputs['Roughness'].default_value=.9;m.diffuse_color=col
 return m
white=mat('Chicken_Ivory',(0.88,0.81,0.57,1));red=mat('Chicken_Comb',(.72,.03,.025,1));gold=mat('Chicken_FeetBeak',(1,.49,.035,1));black=mat('Chicken_Eyes',(.01,.01,.01,1))
parts=[]
def ellipsoid(name,pos,size,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=1,location=pos)
 o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(material);parts.append(o);return o
ellipsoid('ChickenBody',(0,0,.38),(.28,.34,.25),white)
ellipsoid('ChickenHead',(0,.23,.69),(.16,.16,.19),white)
for x in [-.155,.155]:
 ellipsoid('Eye',(x,.29,.73),(.023,.028,.028),black)
 ellipsoid('Wing',(x*1.85,-.03,.4),(.07,.19,.14),white)
for y,z in [(.15,.89),(.24,.91),(.33,.87)]:
 ellipsoid('Comb',(0,y,z),(.035,.055,.075),red)
ellipsoid('Wattle',(0,.34,.59),(.04,.045,.09),red)
ellipsoid('Beak',(0,.42,.69),(.075,.11,.045),gold)
for x in [-.11,.11]:
 ellipsoid('Leg',(x,0,.12),(.025,.025,.11),gold)
 ellipsoid('Foot',(x,.06,.027),(.085,.13,.027),gold)
for x in [-.08,0,.08]:
 o=ellipsoid('Tail',(x,-.31,.57),(.055,.09,.22),white);o.rotation_euler.x=.5
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
o=bpy.context.object;o.name='PolymorphChicken'
bpy.context.scene.cursor.location=(0,0,0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.export_scene.gltf(filepath='D:/Game 3D/Game_3D/assets/models/polymorph_chicken.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
bpy.data.libraries.write('D:/Game 3D/Game_3D/tools/blender_sources/polymorph_chicken.blend',{scene},fake_user=True,compress=True)
for a in bpy.context.screen.areas:
 if a.type=='VIEW_3D':
  a.spaces.active.region_3d.view_location=Vector((0,0,.45));a.spaces.active.region_3d.view_distance=2
  a.tag_redraw()
print(json.dumps({'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'objects':len(scene.objects)}))
