"""Run in Blender through MCP; builds only its own separate scene and exports to this checkout."""
import bpy
import math
import re
from pathlib import Path
from mathutils import Vector, Quaternion

ROOT = Path(__file__).resolve().parents[1]
scene_name = 'Archer_Hawk_Z_V3'
if bpy.data.scenes.get(scene_name):
    raise RuntimeError('Scene already exists; inspect it before rebuilding.')
scene = bpy.data.scenes.new(scene_name)
bpy.context.window.scene = scene
scene.render.fps = 30
collection = bpy.data.collections.new('Hawk_Z_Assets')
scene.collection.children.link(collection)

def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Roughness'].default_value = .8
    return mat

brown = material('Hawk_Z_WarmBrown', (.22, .09, .035))
cream = material('Hawk_Z_ChestCream', (.85, .65, .35))
dark = material('Hawk_Z_FeatherTips', (.055, .033, .02))
gold = material('Hawk_Z_BeakTalons', (.95, .5, .07))
eye = material('Hawk_Z_Eyes', (.015, .012, .009))
silver = material('Hawk_Z_FishSilver', (.36, .7, .72))
belly = material('Hawk_Z_FishBelly', (.8, .94, .84))
wood = material('Hawk_Z_ArrowWood', (.26, .12, .055))

def link(obj):
    for old in list(obj.users_collection): old.objects.unlink(obj)
    collection.objects.link(obj)
    return obj

def ellipsoid(name, pos, scale, mat, segments=10, rings=5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=pos)
    obj = link(bpy.context.object)
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj

def prism(name, outline, thickness, mat):
    verts = [(x,y,z-thickness/2) for x,y,z in outline] + [(x,y,z+thickness/2) for x,y,z in outline]
    n = len(outline)
    faces = [tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    mesh.materials.append(mat)
    return obj

arm = bpy.data.armatures.new('ForestHawkArmature')
rig = bpy.data.objects.new('ForestHawkRig', arm)
collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name)
    b.head, b.tail = head, tail
    if parent: b.parent = arm.edit_bones[parent]
bone('root',(0,0,-.1),(0,0,.15))
bone('chest',(0,0,0),(0,.4,.06),'root')
bone('neck',(0,.4,.06),(0,.62,.25),'chest')
bone('head',(0,.62,.25),(0,.95,.25),'neck')
bone('tail',(0,-.35,0),(0,-1.1,-.08),'root')
for sign, side in [(1,'L'),(-1,'R')]:
    bone('wing_upper.'+side,(sign*.23,.03,.05),(sign*1.0,-.06,.04),'chest')
    bone('wing_lower.'+side,(sign*1.0,-.06,.04),(sign*1.8,-.12,.02),'wing_upper.'+side)
    bone('wing_tip.'+side,(sign*1.8,-.12,.02),(sign*2.65,-.25,0),'wing_lower.'+side)
    bone('feathers.'+side,(sign*2.0,-.12,.02),(sign*2.5,-.55,0),'wing_tip.'+side)
    bone('thigh.'+side,(sign*.19,0,-.18),(sign*.22,.03,-.46),'root')
    bone('shin.'+side,(sign*.22,.03,-.46),(sign*.27,.16,-.75),'thigh.'+side)
    bone('foot.'+side,(sign*.27,.16,-.75),(sign*.27,.4,-.82),'shin.'+side)
    bone('talon_front.'+side,(sign*.27,.36,-.82),(sign*.27,.5,-1.02),'foot.'+side)
    bone('talon_back.'+side,(sign*.27,.09,-.8),(sign*.27,-.12,-1.0),'foot.'+side)
bpy.ops.object.mode_set(mode='OBJECT')
rig.select_set(False)

def bind(obj, name):
    obj.parent = rig
    group = obj.vertex_groups.new(name=name)
    group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod = obj.modifiers.new('HawkSkin','ARMATURE')
    mod.object = rig
    return obj


# Lens-shaped tapered feathers, rather than rectangular wing panels.
def feather(name, start, end, width, mat, bone_name):
    start, end = Vector(start), Vector(end)
    axis=(end-start).normalized()
    cross=Vector((-axis.y,axis.x,0)).normalized()
    verts=[]
    for u,w in [(0,.45),(.5,1),(1,.08)]:
        c=start.lerp(end,u)
        verts.extend([c-cross*width*w/2,c+Vector((0,0,.035*w)),c+cross*width*w/2,c-Vector((0,0,.018*w))])
    faces=[(3,2,1,0),(8,9,10,11)]
    for j in range(2):
        for k in range(4): faces.append((j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj);mesh.materials.append(mat)
    return bind(obj,bone_name)

rust=material('Hawk_Z_RussetCoverts',(.34,.145,.065))
light=material('Hawk_Z_FeatherEdges',(.58,.34,.15))
ivory=material('Hawk_Z_Ivory',(.9,.8,.57))
bind(ellipsoid('HawkBody',(0,-.02,.02),(.38,.67,.35),brown,14,7),'root')
bind(ellipsoid('HawkCreamChest',(0,.13,-.11),(.30,.48,.29),cream,12,6),'chest')
bind(ellipsoid('HawkNeck',(0,.45,.21),(.23,.30,.23),rust,12,6),'neck')
bind(ellipsoid('HawkHead',(0,.70,.33),(.23,.28,.22),brown,12,6),'head')
bind(ellipsoid('HawkFace',(0,.84,.28),(.18,.18,.14),cream,12,5),'head')
bind(prism('HookedBeak',[(-.09,.92,.31),(.09,.92,.31),(.075,1.13,.24),(0,1.18,.10),(-.06,1.08,.18)],.11,gold),'head')
bind(prism('BeakTip',[(-.045,1.11,.22),(.045,1.11,.22),(.02,1.18,.10),(0,1.13,.055),(-.025,1.11,.10)],.055,dark),'head')
for sign,side in [(1,'L'),(-1,'R')]:
    bind(ellipsoid('EyeGold.'+side,(sign*.207,.81,.36),(.026,.048,.048),gold,10,5),'head')
    bind(ellipsoid('EyePupil.'+side,(sign*.229,.829,.365),(.009,.026,.029),eye,8,4),'head')
    bind(ellipsoid('EyeHighlight.'+side,(sign*.237,.842,.378),(.006,.008,.008),ivory,6,3),'head')
    feather('Brow.'+side,(sign*.12,.63,.47),(sign*.235,.89,.41),.085,dark,'head')
    # Continuous wing surface, with soft blend weights between elbow/wrist joints.
    sections=[(.26,.18,-.35,.11),(.95,.17,-.63,.085),(1.72,.02,-.64,.055),(2.45,-.25,-.62,.02)]
    verts=[]
    for x,front,back,thick in sections:
        mid=(front+back)/2
        verts.extend([(sign*x,front,.045),(sign*x,mid,.045+thick),(sign*x,back,.025),(sign*x,mid,.005-thick*.3)])
    faces=[(3,2,1,0),(12,13,14,15)]
    for j in range(3):
        for k in range(4):
            f=(j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k)
            faces.append(tuple(reversed(f)) if sign<0 else f)
    mesh=bpy.data.meshes.new('WingSurface.'+side);mesh.from_pydata(verts,[],faces);mesh.update()
    wing=bpy.data.objects.new('WingSurface.'+side,mesh);collection.objects.link(wing);mesh.materials.append(rust);wing.parent=rig
    groups=[wing.vertex_groups.new(name=n+'.'+side) for n in ['wing_upper','wing_lower','wing_tip']]
    for j,weights in enumerate([(1,0,0),(.45,.55,0),(0,.4,.6),(0,0,1)]):
        for group,weight in zip(groups,weights):
            if weight: group.add(list(range(j*4,j*4+4)),weight,'REPLACE')
    mod=wing.modifiers.new('HawkSkin','ARMATURE');mod.object=rig
    # Long slotted primaries create an organic, fingered silhouette.
    for i in range(8):
        x=1.30+i*.18
        feather('Primary%d.%s'%(i,side),(sign*x,-.24,.045),(sign*(x+.26+i*.025),-1.10+i*.075,-.045),.26,dark if i%3 else brown,'feathers.'+side if i>2 else 'wing_lower.'+side)
    for i in range(6):
        x=.52+i*.17
        feather('Secondary%d.%s'%(i,side),(sign*x,-.12,.095),(sign*(x+.06),-.85,-.02),.23,brown,'wing_upper.'+side if x<.9 else 'wing_lower.'+side)
    for i in range(7):
        x=.40+i*.22
        feather('Covert%d.%s'%(i,side),(sign*x,.08,.13),(sign*(x+.10),-.48,.075),.25,light if i%3==0 else rust,'wing_upper.'+side if x<1 else 'wing_lower.'+side)
    bind(ellipsoid('Thigh.'+side,(sign*.2,0,-.30),(.105,.15,.19),cream,10,5),'thigh.'+side)
    bind(ellipsoid('Shin.'+side,(sign*.25,.12,-.60),(.044,.055,.18),gold,8,4),'shin.'+side)
    # Curved toes with narrow black hooks; front and rear close around the ankle.
    for i in range(3):
        x=sign*(.27+(i-1)*.06)
        bind(prism('Toe%d.%s'%(i,side),[(x-.02,.21,-.77),(x+.02,.21,-.77),(x+.025,.42,-.81),(x+.012,.49,-.92),(x,.46,-1.015),(x-.014,.40,-.91)],.04,gold),'talon_front.'+side)
        bind(prism('ClawTip%d.%s'%(i,side),[(x-.015,.45,-.90),(x+.015,.45,-.90),(x+.008,.47,-1.025),(x,.43,-1.075),(x-.012,.41,-1.0)],.025,dark),'talon_front.'+side)
    bind(prism('RearClaw.'+side,[(sign*.24,.1,-.78),(sign*.30,.1,-.78),(sign*.29,-.12,-.86),(sign*.27,-.16,-.99),(sign*.25,-.09,-1.04)],.04,gold),'talon_back.'+side)
    socket=bpy.data.objects.new('GrabSocket.'+side,None);collection.objects.link(socket)
    socket.parent=rig;socket.parent_type='BONE';socket.parent_bone='foot.'+side;socket.location=(0,0,0)
    for i in range(5):
        x=sign*(.08+(i%2)*.11); y=.10-i*.095
        feather('ChestMark%d.%s'%(i,side),(x,y,-.37),(x*.85,y-.11,-.375),.042,brown,'chest')
for i in range(7):
    x=(i-3)*.09
    feather('TailFeather%d'%i,(x*.45,-.32,-.03),(x*1.65,-1.32+abs(i-3)*.045,-.13),.21,brown if i%2 else dark,'tail')
    feather('TailBand%d'%i,(x*1.3,-1.07,-.095),(x*1.52,-1.18,-.11),.17,light,'tail')

# One skinned mesh, shared material slots, instead of dozens of draw objects.
meshes=[o for o in collection.objects if o.type=='MESH' and o.parent==rig]
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes: obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.object.join()
bpy.context.object.name='ForestHawkSkin'

def local_rotation(pb, world_axis, angle):
    axis=pb.bone.matrix_local.to_3x3().inverted() @ Vector(world_axis)
    pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion(axis,angle)

clips={'dive':.35,'grab':.35,'lift':.7,'carry_flap':.85,'release':.45,'exit':.7}
rig.animation_data_create()
for name,seconds in clips.items():
    action=bpy.data.actions.new(name);rig.animation_data.action=action
    end=round(seconds*30)
    for frame in range(end+1):
        u=frame/max(1,end); phase=u*math.tau
        for pb in rig.pose.bones:
            pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion((1,0,0,0))
        for sign,side in [(1,'L'),(-1,'R')]:
            # Shoulder power stroke, delayed elbow/wrist/feathers, and a gentler recovery.
            flap=.52*math.cos(phase)+.08*math.cos(phase*2)
            if name=='dive': flap=.95*(1-u)+.05
            elif name=='grab': flap=.12+math.sin(u*math.pi)*.50
            elif name=='lift': flap=.7*math.cos(phase)
            elif name=='release': flap=.15+u*.4
            local_rotation(rig.pose.bones['wing_upper.'+side],(0,1,0),-sign*flap)
            local_rotation(rig.pose.bones['wing_lower.'+side],(0,1,0),-sign*.24*math.cos(phase-.45))
            local_rotation(rig.pose.bones['wing_tip.'+side],(0,1,0),-sign*.18*math.cos(phase-.9))
            local_rotation(rig.pose.bones['feathers.'+side],(1,0,0),.10*math.sin(phase-1.1))
            close=.48 if name!='dive' else .05
            if name=='grab': close=u*.48
            elif name=='release': close=(1-u)*.48
            local_rotation(rig.pose.bones['talon_front.'+side],(1,0,0),close)
            local_rotation(rig.pose.bones['talon_back.'+side],(1,0,0),-close)
            local_rotation(rig.pose.bones['shin.'+side],(1,0,0),.10 if name in ['lift','carry_flap'] else 0)
        local_rotation(rig.pose.bones['tail'],(1,0,0),.06*math.sin(phase-.6))
        local_rotation(rig.pose.bones['neck'],(1,0,0),-.035*math.cos(phase))
        local_rotation(rig.pose.bones['head'],(1,0,0),.035*math.cos(phase))
        for pb in rig.pose.bones: pb.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=pb.name)
    action.use_fake_user=True
    track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,0,action);track.mute=True
rig.animation_data.action=None
for pb in rig.pose.bones: pb.rotation_quaternion=Quaternion((1,0,0,0))

fish_root=bpy.data.objects.new('HunterFishArrow',None)
collection.objects.link(fish_root)
fish_parts=[]
fish_parts.append(ellipsoid('FishBody',(0,0,0),(.09,.27,.14),silver,10,5))
fish_parts.append(ellipsoid('FishBelly',(0,.03,-.045),(.075,.21,.095),belly,8,4))
fish_parts.append(prism('FishTail',[(-.005,-.24,0),(-.005,-.4,.15),(-.005,-.34,0),(-.005,-.4,-.15)],.04,silver))
fish_parts.append(prism('FishDorsal',[(-.005,.10,.09),(-.005,-.08,.24),(-.005,-.15,.09)],.025,silver))
for sign in [-1,1]:
    fish_parts.append(ellipsoid('FishEye',(sign*.082,.17,.045),(.016,.025,.025),eye,8,4))
    fish_parts.append(ellipsoid('ArrowClamp',(sign*.10,0,0),(.022,.06,.09),gold,8,4))
bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.018,depth=.85,location=(0,0,-.18))
shaft=link(bpy.context.object)
shaft.name='FishArrowShaft'
shaft.rotation_euler.x=math.pi/2
shaft.data.materials.append(wood)
fish_parts.append(shaft)
fish_parts.append(prism('FishArrowPoint',[(-.07,.55,-.18),(0,.73,-.18),(.07,.55,-.18)],.035,gold))
for obj in fish_parts: obj.parent=fish_root

def triangles(objects):
    result=0
    for obj in objects:
        if obj.type=='MESH':
            obj.data.calc_loop_triangles()
            result+=len(obj.data.loop_triangles)
    return result

def export(name, objects, animate=False):
    # Blender keeps older revision scenes; export stable names without their numeric suffixes.
    for obj in objects:
        canonical=re.sub(r'\.\d{3}$','',obj.name)
        old=bpy.data.objects.get(canonical)
        if old and old!=obj: old.name='Archived_Z_'+old.name
        obj.name=canonical
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    opts={'filepath':str(ROOT/'assets/models'/name),'export_format':'GLB','use_selection':True,'use_active_scene':True,'export_animations':animate,'export_yup':True}
    prop=bpy.ops.export_scene.gltf.get_rna_type().properties.get('export_animation_mode')
    if animate and prop:
        valid={i.identifier for i in prop.enum_items}
        if 'NLA_TRACKS' in valid:
            opts['export_animation_mode']='NLA_TRACKS'
            for track in rig.animation_data.nla_tracks: track.mute=False
    bpy.ops.export_scene.gltf(**opts)
hawk_objects=[rig]+[o for o in collection.objects if o.parent==rig]
hawk_tris=triangles(hawk_objects)
fish_tris=triangles(fish_parts)
assert hawk_tris<3000,hawk_tris
assert fish_tris<500,fish_tris
export('forest_hawk.glb',hawk_objects,True)
export('hunter_fish_arrow.glb',[fish_root]+fish_parts)
for track in rig.animation_data.nla_tracks: track.mute=True
fish_root.location=(3.5,0,0)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
scene.frame_set(0)
for pb in rig.pose.bones: pb.rotation_quaternion=Quaternion((1,0,0,0))
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/archer_hawk_z.blend'))
print({'hawk_triangles':hawk_tris,'fish_triangles':fish_tris,'bones':len(arm.bones),'clips':list(clips),'export_root':str(ROOT)})
