# Forest T-rex and bait source

forest_trex.blend contains only Archer_Trex_Ultimate_Work and dependencies.
Original low-poly geometry/materials, no third-party assets. Godot ignores this
folder via .gdignore; exported runtime GLBs live in assets/models.

T-rex2084 triangles,13 nodes,6 mesh groups; bait128 triangles,2 nodes.
Feet at base origin. Blender faces-Y -> Godot+Z; runtime model rotatesPI.
Head/Jaw/LegL/LegR/Tail pivots drive procedural animation. Base height4.78m;
runtime scale1.6. Export only selected hierarchy with use_active_scene=True,
export_yup=True, export_animations=False. Never export unrelated selected scenes.

## Elemental wizard
elemental_wizard.blend preserves only Elemental_Wizard_Work and dependencies.
Character627 triangles,25 GLB nodes,18 bones, idle/run/dead; branch staff118
triangles,2 nodes, grip origin. Derived from the project's own clean base rig,
separate materials/robe/hat/beard, no third-party asset or arena geometry.
Rebuild: blender/build_elemental_wizard.py through Blender MCP.
Runtime: assets/models/elemental_wizard.glb and wizard_staff.glb.

## Polymorph chicken
polymorph_chicken.blend contains isolated Wizard_Chicken_Work.
864 triangles,1 mesh/node, origin at feet, Blender+Y front -> Godot-Z; runtime
rotatesPI to match player visuals. Original low-poly palette, no external asset.
Rebuild: blender/build_polymorph_chicken.py; runtime assets/models/polymorph_chicken.glb.
