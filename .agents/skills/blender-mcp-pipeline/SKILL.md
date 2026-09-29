---
name: blender-mcp-pipeline
description: Workflow for generating, inspecting, and exporting low-poly 3D models using Blender MCP into Godot 4.
---

# Blender MCP 3D Asset Pipeline

## Workflow Steps

### Step 1: Pre-Execution Inspection
1. Call `get_addon_status()` to ensure the server and addon are active.
2. Call `get_scene_info()` to read existing scene objects so you do not accidentally overwrite or corrupt current work.

### Step 2: Generation / Modeling (Low-Poly Priority)
1. Write clean, modular Python scripts using `bpy`.
2. Keep topology minimal (characters < 3000 triangles, props < 500 triangles).
3. Ensure origin is set to base/feet:
   ```python
   # Example: Place origin at minimum Z (ground)
   import bpy
   obj = bpy.context.active_object
   bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
   ```
4. Assign simple, unlit or flat materials using vertex colors or a compact color palette texture.

### Step 3: Visual Inspection
1. Call `get_viewport_screenshot()` to inspect the output from the camera or 3D viewport.
2. Verify proportions, normals, and shading.

### Step 4: Export to Godot
1. Export directly to the Godot project asset folder:
   - Target path: `D:/Game 3D/Game_3D/assets/models/<asset_name>.glb`
   - Settings: glTF format (`.glb`), export selected objects only, include materials, ensure `+Y Up` is checked.
