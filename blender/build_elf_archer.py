"""Complete low-poly stylized elf archer generator for Blender.
Refined with continuous anatomy (upper arms, seamless neck/cowl),
exact faceted styling, and export to Godot character model.
"""
import bpy
import bmesh
import math
from mathutils import Vector, Matrix

def hex_to_linear(hex_str):
    hex_str = hex_str.lstrip('#')
    r = int(hex_str[0:2], 16) / 255.0
    g = int(hex_str[2:4], 16) / 255.0
    b = int(hex_str[4:6], 16) / 255.0
    def s2l(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (s2l(r), s2l(g), s2l(b), 1.0)

PALETTE = {
    'Hood_Main': hex_to_linear('2F5D3A'),
    'Hood_Lit': hex_to_linear('6F8F4E'),
    'Hood_Shadow': hex_to_linear('1F3F44'),
    'Interior_Dark': hex_to_linear('0A1A1A'),
    'Skin': hex_to_linear('F59A4B'),
    'Skin_Light': hex_to_linear('F7B26A'),
    'Eye_Dark': hex_to_linear('1F3F44'),
    'Ear_Orange': hex_to_linear('F47F2A'),
    'Hair_Blond': hex_to_linear('F1DFAF'),
    'Cowl_Green': hex_to_linear('4E7A45'),
    'Cream_Trim': hex_to_linear('E8D3A0'),
    'Tunic_Green': hex_to_linear('4E7A45'),
    'Tunic_Light': hex_to_linear('7A9A58'),
    'Bracer_Dark': hex_to_linear('3A3330'),
    'Leather_Brown': hex_to_linear('6B4226'),
    'Hand_Orange': hex_to_linear('F47F2A'),
    'Buckle_Cream': hex_to_linear('C9B68A'),
    'Cape_Green': hex_to_linear('244A32'),
    'Quiver_Dark': hex_to_linear('4A2E1E'),
    'Arrow_Wood': hex_to_linear('8A5A32'),
    'Fletching_Black': hex_to_linear('1F1F24'),
    'Legs_DarkBrown': hex_to_linear('4A2E1E'),
    'BootCuff_Tan': hex_to_linear('C9A56B'),
    'Bow_Wood1': hex_to_linear('B8753F'),
    'Bow_Wood2': hex_to_linear('D79A5E'),
    'BowString': hex_to_linear('E8D3A0'),
}

_mat_cache = {}

def get_mat(name, color_key):
    if name in _mat_cache and _mat_cache[name].name in bpy.data.materials:
        return _mat_cache[name]
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    rgba = PALETTE[color_key]
    bsdf.inputs['Base Color'].default_value = rgba
    bsdf.inputs['Roughness'].default_value = 0.9
    bsdf.inputs['Metallic'].default_value = 0.0
    if 'Specular IOR Level' in bsdf.inputs:
        bsdf.inputs['Specular IOR Level'].default_value = 0.1
    elif 'Specular' in bsdf.inputs:
        bsdf.inputs['Specular'].default_value = 0.1
    mat.diffuse_color = rgba
    _mat_cache[name] = mat
    return mat

def create_obj(name, verts, faces, mat_list, scene):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    for p in mesh.polygons:
        p.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    if isinstance(mat_list, list):
        for m in mat_list:
            obj.data.materials.append(m)
    else:
        obj.data.materials.append(mat_list)
    return obj

def make_box(name, c, s, mat, scene, r=None):
    cx, cy, cz = c
    sx, sy, sz = s[0]*0.5, s[1]*0.5, s[2]*0.5
    v = [
        (-sx, -sy, -sz),
        ( sx, -sy, -sz),
        ( sx,  sy, -sz),
        (-sx,  sy, -sz),
        (-sx, -sy,  sz),
        ( sx, -sy,  sz),
        ( sx,  sy,  sz),
        (-sx,  sy,  sz),
    ]
    f = [
        (0, 1, 2, 3), # -Z
        (4, 7, 6, 5), # +Z
        (0, 4, 5, 1), # -Y
        (2, 6, 7, 3), # +Y
        (0, 3, 7, 4), # -X
        (1, 5, 6, 2), # +X
    ]
    obj = create_obj(name, v, f, mat, scene)
    obj.location = c
    if r:
        obj.rotation_euler = r
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
    return obj

def make_tube(name, points, r, sides, mat, scene):
    v = []
    f = []
    for p in points:
        for i in range(sides):
            ang = i * math.tau / sides
            v.append((p[0] + math.cos(ang)*r, p[1] + math.sin(ang)*r, p[2]))
    for j in range(len(points) - 1):
        for i in range(sides):
            a = j * sides + i
            b = j * sides + (i + 1) % sides
            f.append((a, b, b + sides, a + sides))
    f.append(tuple(range(sides - 1, -1, -1)))
    f.append(tuple((len(points) - 1) * sides + i for i in range(sides)))
    return create_obj(name, v, f, mat, scene)

def build_elf_archer(scene_name="Elf_Archer_Work"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    scene = bpy.context.scene

    created_objects = []

    # 1. HEAD & FACE
    # Angular stylized head inside the hood
    head_verts = [
        (-0.08, -0.09, 1.48), # 0 chin left
        ( 0.08, -0.09, 1.48), # 1 chin right
        ( 0.10, -0.01, 1.56), # 2 cheek right
        (-0.10, -0.01, 1.56), # 3 cheek left
        (-0.07,  0.07, 1.52), # 4 back left
        ( 0.07,  0.07, 1.52), # 5 back right
        (-0.08, -0.08, 1.63), # 6 brow left
        ( 0.08, -0.08, 1.63), # 7 brow right
        ( 0.09,  0.01, 1.65), # 8 temple right
        (-0.09,  0.01, 1.65), # 9 temple left
        (-0.06,  0.07, 1.65), # 10 crown back left
        ( 0.06,  0.07, 1.65), # 11 crown back right
        ( 0.00, -0.10, 1.54), # 12 nose tip
    ]
    head_faces = [
        (0, 1, 12), (0, 12, 3), (1, 2, 12), # jaw / chin
        (3, 12, 6), (12, 7, 2), (12, 6, 7), # face front
        (6, 7, 8, 9), # forehead
        (0, 3, 9, 4), (1, 5, 8, 2), # sides
        (4, 9, 10), (5, 11, 8), (4, 10, 11, 5), # back
        (9, 8, 11, 10), # top
        (0, 4, 5, 1), # bottom
    ]
    mat_skin = get_mat("Mat_Skin", "Skin")
    mat_skin_light = get_mat("Mat_Skin_Light", "Skin_Light")
    head_obj = create_obj("Head", head_verts, head_faces, [mat_skin, mat_skin_light], scene)
    for p_idx in [0, 1, 3, 4, 5]:
        head_obj.data.polygons[p_idx].material_index = 1
    created_objects.append(head_obj)

    # Neck bridging head and body seamlessly
    neck_obj = make_box("Neck", (0, 0, 1.44), (0.12, 0.12, 0.10), mat_skin, scene)
    created_objects.append(neck_obj)

    # 2. EYES
    mat_eye = get_mat("Mat_Eye", "Eye_Dark")
    eye_l_verts = [(0.025, -0.093, 1.565), (0.065, -0.083, 1.578), (0.055, -0.083, 1.562)]
    eye_l = create_obj("Eye_L", eye_l_verts, [(0, 1, 2)], mat_eye, scene)
    created_objects.append(eye_l)
    eye_r_verts = [(-0.025, -0.093, 1.565), (-0.055, -0.083, 1.562), (-0.065, -0.083, 1.578)]
    eye_r = create_obj("Eye_R", eye_r_verts, [(0, 1, 2)], mat_eye, scene)
    created_objects.append(eye_r)

    # 3. EARS (Ear_L, Ear_R)
    mat_ear = get_mat("Mat_Ear", "Ear_Orange")
    ear_l_verts = [
        (0.09, -0.01, 1.55), (0.10, 0.04, 1.54),
        (0.10, 0.03, 1.60), (0.09, -0.01, 1.61),
        (0.24, 0.14, 1.70)
    ]
    ear_l_faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 3, 2, 1)]
    ear_l = create_obj("Ear_L", ear_l_verts, ear_l_faces, mat_ear, scene)
    created_objects.append(ear_l)

    ear_r_verts = [
        (-0.09, -0.01, 1.55), (-0.09, -0.01, 1.61),
        (-0.10, 0.03, 1.60), (-0.10, 0.04, 1.54),
        (-0.24, 0.14, 1.70)
    ]
    ear_r_faces = [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (0, 3, 2, 1)]
    ear_r = create_obj("Ear_R", ear_r_verts, ear_r_faces, mat_ear, scene)
    created_objects.append(ear_r)

    # 4. HAIR
    mat_hair = get_mat("Mat_Hair", "Hair_Blond")
    hair_verts = [
        (0.07, -0.085, 1.64), (0.09, -0.075, 1.63), (0.08, -0.075, 1.48),
        (0.08, -0.065, 1.62), (0.10, -0.055, 1.61), (0.095, -0.06, 1.45),
        (0.05, -0.095, 1.65), (0.07, -0.092, 1.64), (0.06, -0.09, 1.52),
        (-0.07, -0.085, 1.64), (-0.08, -0.075, 1.48), (-0.09, -0.075, 1.63),
        (-0.08, -0.065, 1.62), (-0.095, -0.06, 1.45), (-0.10, -0.055, 1.61),
        (-0.05, -0.095, 1.65), (-0.06, -0.09, 1.52), (-0.07, -0.092, 1.64),
        (0.01, -0.095, 1.65), (-0.01, -0.095, 1.65), (0.00, -0.098, 1.58),
    ]
    hair_faces = [
        (0, 1, 2), (3, 4, 5), (6, 7, 8),
        (9, 10, 11), (12, 13, 14), (15, 16, 17),
        (18, 19, 20)
    ]
    hair_obj = create_obj("Hair", hair_verts, hair_faces, mat_hair, scene)
    created_objects.append(hair_obj)

    # 5. HOOD
    mat_hood_main = get_mat("Mat_Hood_Main", "Hood_Main")
    mat_hood_lit = get_mat("Mat_Hood_Lit", "Hood_Lit")
    mat_hood_shadow = get_mat("Mat_Hood_Shadow", "Hood_Shadow")
    mat_hood_dark = get_mat("Mat_Hood_Inside", "Interior_Dark")
    
    hood_verts = [
        (-0.16, -0.11, 1.43), # 0 base lowered
        ( 0.16, -0.11, 1.43), # 1
        ( 0.18,  0.16, 1.44), # 2
        (-0.18,  0.16, 1.44), # 3
        (-0.14, -0.12, 1.45), # 4 face hole
        ( 0.14, -0.12, 1.45), # 5
        ( 0.15, -0.10, 1.67), # 6
        (-0.15, -0.10, 1.67), # 7
        ( 0.00, -0.12, 1.73), # 8 brow peak
        ( 0.00,  0.22, 1.81), # 9 peak leaning backward
        (-0.15,  0.15, 1.70), # 10
        ( 0.15,  0.15, 1.70), # 11
        ( 0.00,  0.06, 1.60), # 12 inside back
    ]
    hood_faces = [
        (0, 4, 7), (1, 6, 5),
        (7, 8, 9), (8, 6, 9),
        (0, 7, 10), (10, 9, 7),
        (1, 11, 6), (6, 11, 9),
        (2, 9, 11), (3, 10, 9), (2, 3, 9),
        (0, 3, 2, 1),
        (4, 5, 12), (4, 12, 7), (5, 6, 12), (7, 12, 6),
    ]
    hood_obj = create_obj("Hood", hood_verts, hood_faces, [mat_hood_main, mat_hood_lit, mat_hood_shadow, mat_hood_dark], scene)
    for f_idx in [2, 3]:
        hood_obj.data.polygons[f_idx].material_index = 1
    for f_idx in [4, 6]:
        hood_obj.data.polygons[f_idx].material_index = 2
    for f_idx in [12, 13, 14, 15]:
        hood_obj.data.polygons[f_idx].material_index = 3
    created_objects.append(hood_obj)

    # 6. COWL / SCARF (Upgraded elven ranger scarf with elegant neck wrap, faceted folds & long drape)
    mat_cowl_main = get_mat("Mat_Cowl_Main", "Hood_Main")
    mat_cowl_lit = get_mat("Mat_Cowl_Lit", "Hood_Lit")
    mat_cowl_shadow = get_mat("Mat_Cowl_Shadow", "Hood_Shadow")
    mat_cowl_trim = get_mat("Mat_Cowl_Trim", "Cream_Trim")

    cowl_verts = [
        # Top collar rim (Z = 1.45) - wraps snugly under the hood
        (-0.17, -0.11, 1.45), # v0  front right rim
        (-0.06, -0.12, 1.45), # v1  front right-mid
        ( 0.06, -0.12, 1.45), # v2  front left-mid
        ( 0.17, -0.11, 1.45), # v3  front left rim
        ( 0.19,  0.15, 1.45), # v4  back left rim
        (-0.19,  0.15, 1.45), # v5  back right rim

        # Shoulder rim (Z = 1.37) - drapes over clavicles and connects to Cape seam
        (-0.21, -0.12, 1.37), # v6  right shoulder
        (-0.08, -0.135, 1.36), # v7  right lapel fold
        ( 0.04, -0.140, 1.36), # v8  scarf drape base inner
        ( 0.15, -0.135, 1.36), # v9  scarf drape base outer
        ( 0.21, -0.12, 1.37), # v10 left shoulder
        ( 0.23,  0.15, 1.37), # v11 back left base
        (-0.23,  0.15, 1.37), # v12 back right base

        # Center neck knot fold
        (-0.02, -0.148, 1.32), # v13 center knot tip

        # Elongated stylish scarf drape (vạt khăn quàng dài rủ xuống ngực trái)
        ( 0.03, -0.146, 1.18), # v14 drape mid inner
        ( 0.14, -0.140, 1.18), # v15 drape mid outer
        ( 0.04, -0.138, 1.05), # v16 drape lower inner
        ( 0.13, -0.132, 1.05), # v17 drape lower outer
        ( 0.085, -0.135, 0.98), # v18 drape chevron tip near belt!
    ]
    cowl_faces = [
        # Collar ring
        (0, 1, 7, 6),   # 0: right front panel (Shadow)
        (1, 2, 8, 7),   # 1: center neck panel (Main)
        (2, 9, 8),      # 2: left collar tri (Lit)
        (2, 3, 10, 9),  # 3: left front panel (Main)
        (3, 4, 11, 10), # 4: left shoulder panel (Lit)
        (4, 5, 12, 11), # 5: back collar panel (Main)
        (5, 0, 6, 12),  # 6: right shoulder panel (Shadow)

        # Center knot fold
        (7, 8, 13),     # 7: knot fold (Lit)

        # Long scarf drape
        (8, 9, 15, 14),   # 8: drape upper panel (Lit)
        (14, 15, 17, 16), # 9: drape mid panel (Main)
        (16, 17, 18),     # 10: drape chevron tip (Cream Trim)

        # Top collar seal
        (0, 5, 4, 3),     # 11: back inner seal
        (0, 3, 2, 1),     # 12: front inner seal
    ]
    cowl_obj = create_obj("Cowl", cowl_verts, cowl_faces, [mat_cowl_main, mat_cowl_lit, mat_cowl_shadow, mat_cowl_trim], scene)
    for f_idx in [0, 6]:
        cowl_obj.data.polygons[f_idx].material_index = 2
    for f_idx in [2, 4, 7, 8]:
        cowl_obj.data.polygons[f_idx].material_index = 1
    cowl_obj.data.polygons[10].material_index = 3
    created_objects.append(cowl_obj)

    # 7. SHOULDER PADS
    mat_cream = get_mat("Mat_Cream", "Cream_Trim")
    pad_l_verts = [(0.20, -0.06, 1.37), (0.28, 0.00, 1.36), (0.20, 0.06, 1.37), (0.23, 0.00, 1.41)]
    pad_l_faces = [(0, 1, 3), (1, 2, 3), (2, 0, 3), (0, 2, 1)]
    pad_l = create_obj("ShoulderPad_L", pad_l_verts, pad_l_faces, mat_cream, scene)
    created_objects.append(pad_l)

    pad_r_verts = [(-0.20, -0.06, 1.37), (-0.20, 0.06, 1.37), (-0.28, 0.00, 1.36), (-0.23, 0.00, 1.41)]
    pad_r_faces = [(0, 1, 3), (1, 2, 3), (2, 0, 3), (0, 2, 1)]
    pad_r = create_obj("ShoulderPad_R", pad_r_verts, pad_r_faces, mat_cream, scene)
    created_objects.append(pad_r)

    # 8. TORSO & TUNIC
    mat_tunic = get_mat("Mat_Tunic", "Tunic_Green")
    mat_tunic_lit = get_mat("Mat_Tunic_Lit", "Tunic_Light")
    torso_verts = [
        (-0.17, -0.10, 1.36), ( 0.17, -0.10, 1.36),
        ( 0.16,  0.10, 1.36), (-0.16,  0.10, 1.36),
        ( 0.00, -0.12, 1.25),
        (-0.13, -0.08, 0.98), ( 0.13, -0.08, 0.98),
        ( 0.13,  0.08, 0.98), (-0.13,  0.08, 0.98),
        ( 0.00, -0.09, 0.98),
        (-0.14, -0.09, 0.88), ( 0.00, -0.10, 0.86), ( 0.14, -0.09, 0.88),
        ( 0.00,  0.09, 0.87),
        (-0.25, -0.08, 1.32), (-0.24,  0.08, 1.32), (-0.25,  0.00, 1.22),
        ( 0.25, -0.08, 1.32), ( 0.24,  0.08, 1.32), ( 0.25,  0.00, 1.22),
    ]
    torso_faces = [
        (0, 4, 9, 5), (4, 1, 6, 9), (0, 1, 4),
        (2, 3, 8, 7),
        (0, 5, 8, 3), (1, 2, 7, 6),
        (0, 3, 2, 1),
        (5, 9, 11, 10), (9, 6, 12, 11),
        (8, 7, 13),
        (0, 14, 16, 5), (3, 15, 16, 8), (14, 15, 16),
        (1, 6, 19, 17), (2, 7, 19, 18), (17, 18, 19),
    ]
    torso_obj = create_obj("Torso", torso_verts, torso_faces, [mat_tunic, mat_tunic_lit, mat_cream], scene)
    torso_obj.data.polygons[1].material_index = 1
    created_objects.append(torso_obj)

    trim_verts = [
        (-0.145, -0.095, 0.875), (0.00, -0.105, 0.855), (0.145, -0.095, 0.875),
        (-0.14, -0.09, 0.89), (0.00, -0.098, 0.87), (0.14, -0.09, 0.89),
    ]
    trim_faces = [(0, 1, 4, 3), (1, 2, 5, 4)]
    trim_obj = create_obj("TunicTrim", trim_verts, trim_faces, mat_cream, scene)
    created_objects.append(trim_obj)

    # 9. BELT & BUCKLE
    mat_leather = get_mat("Mat_Leather", "Leather_Brown")
    mat_buckle = get_mat("Mat_Buckle", "Buckle_Cream")
    belt_obj = make_box("Belt", (0, 0, 0.97), (0.28, 0.18, 0.06), mat_leather, scene)
    created_objects.append(belt_obj)

    buckle_verts = [
        (-0.04, -0.098, 0.94), ( 0.04, -0.098, 0.94),
        ( 0.04, -0.098, 1.00), (-0.04, -0.098, 1.00),
        (-0.02, -0.098, 0.955), ( 0.02, -0.098, 0.955),
        ( 0.02, -0.098, 0.985), (-0.02, -0.098, 0.985),
    ]
    buckle_faces = [
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)
    ]
    buckle_obj = create_obj("Buckle", buckle_verts, buckle_faces, mat_buckle, scene)
    created_objects.append(buckle_obj)

    strap_obj = make_box("BeltStrap", (0.02, -0.096, 0.87), (0.025, 0.015, 0.14), mat_leather, scene)
    created_objects.append(strap_obj)

    # 10. CHEST STRAP (Contoured 3-segment harness over chest, eliminating clipping & sitting proud)
    chest_strap_verts = [
        # Front outer face (contours nicely over pectoral curvature)
        (-0.16, -0.112, 1.36), (-0.11, -0.112, 1.36), # v0, v1 Top right shoulder
        (-0.04, -0.138, 1.18), ( 0.01, -0.138, 1.18), # v2, v3 Mid chest apex
        ( 0.07, -0.108, 0.98), ( 0.12, -0.108, 0.98), # v4, v5 Bottom left hip
        # Inner back face (thickness ~0.014)
        (-0.16, -0.098, 1.36), (-0.11, -0.098, 1.36), # v6, v7
        (-0.04, -0.124, 1.18), ( 0.01, -0.124, 1.18), # v8, v9
        ( 0.07, -0.094, 0.98), ( 0.12, -0.094, 0.98), # v10, v11
    ]
    chest_strap_faces = [
        (0, 1, 3, 2), # Front upper quad
        (2, 3, 5, 4), # Front lower quad
        (7, 6, 8, 9), # Back upper quad
        (9, 8, 10, 11), # Back lower quad
        (0, 2, 8, 6), (2, 4, 10, 8), # Right outer rim
        (1, 7, 9, 3), (3, 9, 11, 5), # Left inner rim
        (0, 6, 7, 1), # Top shoulder rim
        (4, 5, 11, 10), # Bottom hip rim
    ]
    chest_strap = create_obj("ChestStrap", chest_strap_verts, chest_strap_faces, mat_leather, scene)
    created_objects.append(chest_strap)

    # 11. CAPE ── Elongated Heroic Elven Ranger Cloak (5 Rows, Iconic Swallowtail Hem)
    mat_cape = get_mat("Mat_Cape", "Cape_Green")
    cape_verts = [
        # Row 0: Collar seam (Z = 1.35) - tucked neatly under Cowl (Y = 0.14)
        (-0.17, 0.138, 1.35), # v0  right shoulder
        ( 0.00, 0.138, 1.35), # v1  center neck
        ( 0.17, 0.138, 1.35), # v2  left shoulder

        # Row 1: Upper back (Z = 1.20) - smooth drape behind shoulder blades
        (-0.20, 0.144, 1.20), # v3  right edge
        (-0.10, 0.146, 1.20), # v4  right inner
        ( 0.00, 0.146, 1.20), # v5  center spine
        ( 0.10, 0.146, 1.20), # v6  left inner
        ( 0.20, 0.144, 1.20), # v7  left edge

        # Row 2: Mid back / Waist (Z = 1.05) - lumbar taper
        (-0.22, 0.155, 1.05), # v8  right edge
        (-0.11, 0.158, 1.05), # v9  right inner
        ( 0.00, 0.158, 1.05), # v10 center spine
        ( 0.11, 0.158, 1.05), # v11 left inner
        ( 0.22, 0.155, 1.05), # v12 left edge

        # Row 3: Pelvis / Upper Thigh (Z = 0.88) - flaring backward naturally
        (-0.24, 0.178, 0.88), # v13 right edge
        (-0.12, 0.182, 0.88), # v14 right inner
        ( 0.00, 0.182, 0.88), # v15 center spine
        ( 0.12, 0.182, 0.88), # v16 left inner
        ( 0.24, 0.178, 0.88), # v17 left edge

        # Row 4: Long Swallowtail Hem (Z = 0.68 - 0.74) - mid-thigh / knee level!
        (-0.26, 0.198, 0.74), # v18 right outer corner
        (-0.13, 0.208, 0.68), # v19 right swallowtail chevron tip!
        ( 0.00, 0.208, 0.74), # v20 center chevron notch
        ( 0.13, 0.208, 0.68), # v21 left swallowtail chevron tip!
        ( 0.26, 0.198, 0.74), # v22 left outer corner
    ]
    cape_faces = [
        # Panel 0 -> 1: Collar to Upper back
        (0, 3, 4),      # right tri
        (0, 4, 5, 1),   # right center quad
        (1, 5, 6, 2),   # left center quad
        (2, 6, 7),      # left tri

        # Panel 1 -> 2: Upper back to Mid back
        (3, 4, 9, 8),   # right outer quad
        (4, 5, 10, 9),  # right inner quad
        (5, 6, 11, 10), # left inner quad
        (6, 7, 12, 11), # left outer quad

        # Panel 2 -> 3: Mid back to Pelvis/Upper Thigh
        (8, 9, 14, 13),   # right outer quad
        (9, 10, 15, 14),  # right inner quad
        (10, 11, 16, 15), # left inner quad
        (11, 12, 17, 16), # left outer quad

        # Panel 3 -> 4: Pelvis to Long Swallowtail Hem
        (13, 14, 19, 18), # right outer swallowtail quad
        (14, 15, 20, 19), # right inner notch quad
        (15, 16, 21, 20), # left inner notch quad
        (16, 17, 22, 21), # left outer swallowtail quad
    ]
    cape_obj = create_obj("Cape", cape_verts, cape_faces, mat_cape, scene)
    created_objects.append(cape_obj)

    # 12. QUIVER & ARROWS (Mounted cleanly outside the cape with zero intersection)
    mat_quiver = get_mat("Mat_Quiver", "Quiver_Dark")
    mat_arrow_wood = get_mat("Mat_Arrow_Wood", "Arrow_Wood")
    mat_fletch = get_mat("Mat_Fletch", "Fletching_Black")
    # Natural subtle angle: pitch -3°, yaw -6°, roll 10°
    q_rot = (math.radians(-3), math.radians(-6), math.radians(10))
    # Center at (-0.15, 0.215, 1.24): inner face at Y >= 0.160 everywhere, giving 1.5cm clearance outside cape (Y=0.145)
    quiver_obj = make_box("Quiver", (-0.15, 0.215, 1.24), (0.09, 0.09, 0.40), mat_quiver, scene, q_rot)
    created_objects.append(quiver_obj)

    for idx, (ox, oy, oz) in enumerate([(-0.17, 0.225, 1.50), (-0.14, 0.245, 1.54), (-0.12, 0.215, 1.52)]):
        arr_shaft = make_box("Arrow_%d" % (idx + 1), (ox, oy, oz), (0.014, 0.014, 0.24), mat_arrow_wood, scene, q_rot)
        created_objects.append(arr_shaft)
        fletch = make_box("Fletching_%d" % (idx + 1), (ox, oy, oz + 0.09), (0.04, 0.01, 0.06), mat_fletch, scene, q_rot)
        created_objects.append(fletch)

    # 13. ARMS & HANDS (Connecting smoothly in neutral A-pose with baked transforms)
    mat_bracer = get_mat("Mat_Bracer", "Bracer_Dark")
    mat_hand = get_mat("Mat_Hand", "Hand_Orange")

    # Upper Arms
    upper_l = make_box("UpperArm_L", (0.23, 0.0, 1.23), (0.075, 0.075, 0.18), mat_tunic, scene, (0, math.radians(-14), 0))
    created_objects.append(upper_l)

    upper_r = make_box("UpperArm_R", (-0.23, 0.0, 1.23), (0.075, 0.075, 0.18), mat_tunic, scene, (0, math.radians(14), 0))
    created_objects.append(upper_r)

    # Forearms & Bracers
    forearm_l = make_box("Forearm_L", (0.29, -0.01, 1.05), (0.07, 0.07, 0.22), mat_cream, scene, (0, math.radians(-12), 0))
    created_objects.append(forearm_l)
    bracer_l = make_box("Bracer_L", (0.295, -0.01, 1.05), (0.088, 0.088, 0.14), mat_bracer, scene, (0, math.radians(-12), 0))
    created_objects.append(bracer_l)
    strap_l = make_box("BracerStrap_L", (0.295, -0.01, 1.05), (0.092, 0.092, 0.03), mat_leather, scene, (0, math.radians(-12), 0))
    created_objects.append(strap_l)
    hand_l = make_box("Hand_L", (0.32, -0.01, 0.91), (0.06, 0.06, 0.08), mat_hand, scene)
    created_objects.append(hand_l)

    forearm_r = make_box("Forearm_R", (-0.29, -0.01, 1.05), (0.07, 0.07, 0.22), mat_cream, scene, (0, math.radians(12), 0))
    created_objects.append(forearm_r)
    bracer_r = make_box("Bracer_R", (-0.295, -0.01, 1.05), (0.088, 0.088, 0.14), mat_bracer, scene, (0, math.radians(12), 0))
    created_objects.append(bracer_r)
    strap_r = make_box("BracerStrap_R", (-0.295, -0.01, 1.05), (0.092, 0.092, 0.03), mat_leather, scene, (0, math.radians(12), 0))
    created_objects.append(strap_r)
    hand_r = make_box("Hand_R", (-0.32, -0.01, 0.91), (0.06, 0.06, 0.08), mat_hand, scene)
    created_objects.append(hand_r)

    # 14. LEGS & BOOTS
    mat_legs = get_mat("Mat_Legs", "Legs_DarkBrown")
    mat_cuffs = get_mat("Mat_BootCuff", "BootCuff_Tan")

    # Left Leg
    leg_l = make_box("Leg_L", (0.08, 0.0, 0.58), (0.085, 0.09, 0.65), mat_legs, scene)
    created_objects.append(leg_l)
    cuff_l_verts = [
        (0.03, -0.06, 0.22), (0.13, -0.06, 0.22),
        (0.13,  0.06, 0.22), (0.03,  0.06, 0.22),
        (0.02, -0.07, 0.30), (0.08, -0.07, 0.33),
        (0.14, -0.07, 0.30), (0.14,  0.07, 0.30), (0.02,  0.07, 0.30),
    ]
    cuff_l_faces = [
        (0, 1, 6, 5), (0, 5, 4), (1, 2, 7, 6), (2, 3, 8, 7), (3, 0, 4, 8),
        (0, 3, 2, 1)
    ]
    cuff_l = create_obj("BootCuff_L", cuff_l_verts, cuff_l_faces, mat_cuffs, scene)
    created_objects.append(cuff_l)
    boot_l_verts = [
        (0.035, -0.05, 0.0), (0.125, -0.05, 0.0),
        (0.125,  0.05, 0.0), (0.035,  0.05, 0.0),
        (0.035, -0.16, 0.0), (0.125, -0.16, 0.0),
        (0.035, -0.05, 0.22), (0.125, -0.05, 0.22),
        (0.125,  0.05, 0.22), (0.035,  0.05, 0.22),
        (0.04,  -0.15, 0.08), (0.12,  -0.15, 0.08),
    ]
    boot_l_faces = [
        (0, 4, 5, 1), (0, 1, 2, 3),
        (4, 10, 11, 5), (10, 6, 7, 11),
        (6, 7, 8, 9), (2, 8, 9, 3),
        (0, 3, 9, 6), (1, 7, 8, 2),
        (0, 6, 10, 4), (1, 5, 11, 7)
    ]
    boot_l = create_obj("Boot_L", boot_l_verts, boot_l_faces, mat_leather, scene)
    created_objects.append(boot_l)
    strap_boot_l = make_box("BootStrap_L", (0.08, -0.01, 0.12), (0.10, 0.11, 0.03), mat_legs, scene)
    created_objects.append(strap_boot_l)

    # Right Leg
    leg_r = make_box("Leg_R", (-0.08, 0.0, 0.58), (0.085, 0.09, 0.65), mat_legs, scene)
    created_objects.append(leg_r)
    cuff_r_verts = [
        (-0.13, -0.06, 0.22), (-0.03, -0.06, 0.22),
        (-0.03,  0.06, 0.22), (-0.13,  0.06, 0.22),
        (-0.14, -0.07, 0.30), (-0.08, -0.07, 0.33),
        (-0.02, -0.07, 0.30), (-0.02,  0.07, 0.30), (-0.14,  0.07, 0.30),
    ]
    cuff_r_faces = [
        (0, 1, 6, 5), (0, 5, 4), (1, 2, 7, 6), (2, 3, 8, 7), (3, 0, 4, 8),
        (0, 3, 2, 1)
    ]
    cuff_r = create_obj("BootCuff_R", cuff_r_verts, cuff_r_faces, mat_cuffs, scene)
    created_objects.append(cuff_r)
    boot_r_verts = [
        (-0.125, -0.05, 0.0), (-0.035, -0.05, 0.0),
        (-0.035,  0.05, 0.0), (-0.125,  0.05, 0.0),
        (-0.125, -0.16, 0.0), (-0.035, -0.16, 0.0),
        (-0.125, -0.05, 0.22), (-0.035, -0.05, 0.22),
        (-0.035,  0.05, 0.22), (-0.125,  0.05, 0.22),
        (-0.12,  -0.15, 0.08), (-0.04,  -0.15, 0.08),
    ]
    boot_r_faces = [
        (0, 4, 5, 1), (0, 1, 2, 3),
        (4, 10, 11, 5), (10, 6, 7, 11),
        (6, 7, 8, 9), (2, 8, 9, 3),
        (0, 3, 9, 6), (1, 7, 8, 2),
        (0, 6, 10, 4), (1, 5, 11, 7)
    ]
    boot_r = create_obj("Boot_R", boot_r_verts, boot_r_faces, mat_leather, scene)
    created_objects.append(boot_r)
    strap_boot_r = make_box("BootStrap_R", (-0.08, -0.01, 0.12), (0.10, 0.11, 0.03), mat_legs, scene)
    created_objects.append(strap_boot_r)

    # 15. BOW & BOWSTRING
    # Held securely in character's left hand at (0.32, -0.01, 0.91)
    mat_bow1 = get_mat("Mat_Bow1", "Bow_Wood1")
    mat_bow2 = get_mat("Mat_Bow2", "Bow_Wood2")
    mat_string = get_mat("Mat_BowString", "BowString")

    bow_verts = [
        # Grip in palm
        (0.31, -0.03, 0.91), (0.33, -0.03, 0.91),
        (0.33,  0.01, 0.91), (0.31,  0.01, 0.91),
        # Upper limb tip forward
        (0.31, -0.12, 1.42), (0.33, -0.12, 1.42),
        (0.33, -0.10, 1.42), (0.31, -0.10, 1.42),
        # Lower limb tip forward
        (0.31, -0.12, 0.36), (0.33, -0.12, 0.36),
        (0.33, -0.10, 0.36), (0.31, -0.10, 0.36),
    ]
    bow_faces = [
        (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7),
        (0, 1, 9, 8), (1, 2, 10, 9), (2, 3, 11, 10), (3, 0, 8, 11), (8, 9, 10, 11),
    ]
    bow_obj = create_obj("Bow", bow_verts, bow_faces, [mat_bow1, mat_bow2], scene)
    created_objects.append(bow_obj)

    string_verts = [
        (0.318, -0.10, 0.37), (0.322, -0.10, 0.37),
        (0.322, -0.10, 1.41), (0.318, -0.10, 1.41),
        (0.318, -0.102, 0.37), (0.322, -0.102, 0.37),
        (0.322, -0.102, 1.41), (0.318, -0.102, 1.41),
    ]
    string_faces = [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (2, 6, 7, 3), (0, 3, 7, 4), (1, 5, 6, 2)
    ]
    bow_string_obj = create_obj("BowString", string_verts, string_faces, mat_string, scene)
    created_objects.append(bow_string_obj)

    total_tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in created_objects)
    print(f"TOTAL CHARACTER TRIANGLES: {total_tris} (Budget: < 2500)")

    return scene, created_objects

def export_to_game(created_objects, scene):
    # 1. Import base armature from player_character.glb
    base_path = 'D:/Game 3D/Game_3D/assets/models/player_character.glb'
    bpy.ops.import_scene.gltf(filepath=base_path)
    rig = next(o for o in bpy.context.selected_objects if o.type == 'ARMATURE')
    old_body = next((o for o in bpy.context.selected_objects if o.type == 'MESH'), None)
    if old_body:
        bpy.data.objects.remove(old_body, do_unlink=True)
    
    rig.name = 'Gladiator_Armature'
    # Keep only standard locomotion/death animation tracks
    if rig.animation_data:
        for track in list(rig.animation_data.nla_tracks):
            if track.name not in ['idle', 'run', 'dead']:
                rig.animation_data.nla_tracks.remove(track)
        rig.animation_data.action = None

    def bind_bone(obj, bone_name, weight=1.0):
        group = obj.vertex_groups.get(bone_name) or obj.vertex_groups.new(name=bone_name)
        group.add(list(range(len(obj.data.vertices))), weight, 'REPLACE')
        obj.parent = rig
        mod = obj.modifiers.get('Armature') or obj.modifiers.new('Armature', 'ARMATURE')
        mod.object = rig

    # Bind character parts to corresponding bones
    bone_map = {
        'Head': [('head', 1.0)],
        'Eye_L': [('head', 1.0)],
        'Eye_R': [('head', 1.0)],
        'Ear_L': [('head', 1.0)],
        'Ear_R': [('head', 1.0)],
        'Hair': [('head', 1.0)],
        'Hood': [('head', 1.0)],
        'Neck': [('neck', 1.0)],
        'Cowl': [('neck', 0.6), ('chest', 0.4)],
        'ShoulderPad_L': [('chest', 0.5), ('upper_arm.L', 0.5)],
        'ShoulderPad_R': [('chest', 0.5), ('upper_arm.R', 0.5)],
        'Torso': [('chest', 0.7), ('spine', 0.3)],
        'TunicTrim': [('chest', 0.6), ('spine', 0.4)],
        'Belt': [('hips', 1.0)],
        'Buckle': [('hips', 1.0)],
        'BeltStrap': [('hips', 1.0)],
        'ChestStrap': [('chest', 0.8), ('spine', 0.2)],
        'Quiver': [('chest', 0.70), ('spine', 0.30)],
        'Arrow_1': [('chest', 0.70), ('spine', 0.30)],
        'Arrow_2': [('chest', 0.70), ('spine', 0.30)],
        'Arrow_3': [('chest', 0.70), ('spine', 0.30)],
        'Fletching_1': [('chest', 0.70), ('spine', 0.30)],
        'Fletching_2': [('chest', 0.70), ('spine', 0.30)],
        'Fletching_3': [('chest', 0.70), ('spine', 0.30)],
        'UpperArm_L': [('upper_arm.L', 1.0)],
        'UpperArm_R': [('upper_arm.R', 1.0)],
        'Forearm_L': [('forearm.L', 1.0)],
        'Forearm_R': [('forearm.R', 1.0)],
        'Bracer_L': [('forearm.L', 1.0)],
        'Bracer_R': [('forearm.R', 1.0)],
        'BracerStrap_L': [('forearm.L', 1.0)],
        'BracerStrap_R': [('forearm.R', 1.0)],
        'Hand_L': [('hand.L', 1.0)],
        'Hand_R': [('hand.R', 1.0)],
        'Leg_L': [('thigh.L', 0.6), ('shin.L', 0.4)],
        'Leg_R': [('thigh.R', 0.6), ('shin.R', 0.4)],
        'BootCuff_L': [('foot.L', 1.0)],
        'BootCuff_R': [('foot.R', 1.0)],
        'Boot_L': [('foot.L', 1.0)],
        'Boot_R': [('foot.R', 1.0)],
        'BootStrap_L': [('foot.L', 1.0)],
        'BootStrap_R': [('foot.R', 1.0)],
    }

    character_parts = []
    for obj in created_objects:
        if obj.name in ['Bow', 'BowString']:
            continue
        if obj.name in bone_map:
            for b_name, w in bone_map[obj.name]:
                bind_bone(obj, b_name, w)
        character_parts.append(obj)

    # Bind Cape with anatomically matched per-vertex weights to eliminate clipping
    cape_obj = next((o for o in created_objects if o.name == 'Cape'), None)
    if cape_obj:
        cape_obj.parent = rig
        mod = cape_obj.modifiers.get('Armature') or cape_obj.modifiers.new('Armature', 'ARMATURE')
        mod.object = rig

        vg_neck = cape_obj.vertex_groups.get('neck') or cape_obj.vertex_groups.new(name='neck')
        vg_chest = cape_obj.vertex_groups.get('chest') or cape_obj.vertex_groups.new(name='chest')
        vg_spine = cape_obj.vertex_groups.get('spine') or cape_obj.vertex_groups.new(name='spine')
        vg_hips = cape_obj.vertex_groups.get('hips') or cape_obj.vertex_groups.new(name='hips')

        # Row 0: verts [0, 1, 2] (Z = 1.35) - Collar follows neck & chest (seamless under Cowl)
        for vi in [0, 1, 2]:
            vg_neck.add([vi], 0.40, 'REPLACE')
            vg_chest.add([vi], 0.60, 'REPLACE')

        # Row 1: verts [3, 4, 5, 6, 7] (Z = 1.20) - Upper back exactly matches Torso and Quiver
        for vi in [3, 4, 5, 6, 7]:
            vg_chest.add([vi], 0.70, 'REPLACE')
            vg_spine.add([vi], 0.30, 'REPLACE')

        # Row 2: verts [8, 9, 10, 11, 12] (Z = 1.05) - Mid/lower back smooth lumbar transition
        for vi in [8, 9, 10, 11, 12]:
            vg_chest.add([vi], 0.20, 'REPLACE')
            vg_spine.add([vi], 0.50, 'REPLACE')
            vg_hips.add([vi], 0.30, 'REPLACE')

        # Row 3: verts [13, 14, 15, 16, 17] (Z = 0.88) - Pelvis drape follows hips & spine
        for vi in [13, 14, 15, 16, 17]:
            vg_spine.add([vi], 0.15, 'REPLACE')
            vg_hips.add([vi], 0.85, 'REPLACE')

        # Row 4: verts [18, 19, 20, 21, 22] (Z = 0.68 - 0.74) - Long swallowtail hem follows hips motion
        for vi in [18, 19, 20, 21, 22]:
            vg_spine.add([vi], 0.10, 'REPLACE')
            vg_hips.add([vi], 0.90, 'REPLACE')

    # Export forest_archer.glb (Armature + Character Parts)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    for p in character_parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = rig
    
    char_export_path = 'D:/Game 3D/Game_3D/assets/models/forest_archer.glb'
    bpy.ops.export_scene.gltf(
        filepath=char_export_path,
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_animations=True,
        export_animation_mode='NLA_TRACKS'
    )
    print("Exported character to:", char_export_path)

    # 2. Standalone Hunter Bow
    mat_bow1 = get_mat("Mat_Bow1", "Bow_Wood1")
    mat_bow2 = get_mat("Mat_Bow2", "Bow_Wood2")
    mat_string = get_mat("Mat_BowString", "BowString")
    
    bow_pts = [(0, -0.08, -0.55), (0, 0, -0.15), (0, 0, 0.15), (0, -0.08, 0.55)]
    standalone_bow = make_tube("HunterBowMesh", bow_pts, 0.024, 4, [mat_bow1, mat_bow2], scene)
    str_pts = [(0, -0.07, -0.54), (0, -0.07, 0.54)]
    standalone_str = make_tube("HunterBowString", str_pts, 0.003, 4, mat_string, scene)
    
    bpy.ops.object.select_all(action='DESELECT')
    standalone_bow.select_set(True)
    standalone_str.select_set(True)
    bpy.context.view_layer.objects.active = standalone_bow
    
    bow_export_path = 'D:/Game 3D/Game_3D/assets/models/hunter_bow.glb'
    bpy.ops.export_scene.gltf(
        filepath=bow_export_path,
        export_format='GLB',
        use_selection=True,
        export_yup=True
    )
    print("Exported bow to:", bow_export_path)
    bpy.data.objects.remove(standalone_bow, do_unlink=True)
    bpy.data.objects.remove(standalone_str, do_unlink=True)

    # 3. Standalone Hunter Arrow
    mat_shaft = get_mat("Mat_Arrow_Wood", "Arrow_Wood")
    mat_tip = get_mat("Mat_Arrow_Tip", "Bracer_Dark")
    mat_fletch = get_mat("Mat_Fletch", "Fletching_Black")

    arrow_shaft = make_box("ArrowShaft", (0, 0.34, 0), (0.016, 0.68, 0.016), mat_shaft, scene)
    # Tip points +Y
    tip_v = [(-0.035, 0.65, 0), (0.035, 0.65, 0), (0, 0.65, 0.025), (0, 0.65, -0.025), (0, 0.80, 0)]
    tip_f = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (0, 3, 1, 2)]
    arrow_tip = create_obj("ArrowTip", tip_v, tip_f, mat_tip, scene)
    arrow_fletch = make_box("ArrowFletch", (0, 0.08, 0), (0.08, 0.12, 0.01), mat_fletch, scene)

    bpy.ops.object.select_all(action='DESELECT')
    arrow_shaft.select_set(True)
    arrow_tip.select_set(True)
    arrow_fletch.select_set(True)
    bpy.context.view_layer.objects.active = arrow_shaft
    
    arrow_export_path = 'D:/Game 3D/Game_3D/assets/models/hunter_arrow.glb'
    bpy.ops.export_scene.gltf(
        filepath=arrow_export_path,
        export_format='GLB',
        use_selection=True,
        export_yup=True
    )
    print("Exported arrow to:", arrow_export_path)
    bpy.data.objects.remove(arrow_shaft, do_unlink=True)
    bpy.data.objects.remove(arrow_tip, do_unlink=True)
    bpy.data.objects.remove(arrow_fletch, do_unlink=True)

    print("ALL ASSETS EXPORTED SUCCESSFULLY FOR GODOT!")


if __name__ == '__main__':
    scene, created_objects = build_elf_archer()
    export_to_game(created_objects, scene)


