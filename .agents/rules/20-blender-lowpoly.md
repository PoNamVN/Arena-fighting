---
description: Blender 5.2 and Blender MCP low-poly asset creation and export standards
trigger: always_on
---

# Blender 5.2 & Low-Poly Asset Pipeline

1. **Polygon Budget & Optimization (Target 4GB VRAM)**:
   - Characters: < 3,000 triangles per model.
   - Arena props / obstacles: 50 - 500 triangles per object.
   - Total scene visible triangles: Target under 50,000 triangles.
   - Use flat shading or unified color-palette textures (e.g. 256x256 color swatch) to minimize texture memory and draw calls.

2. **Transform & Origin Standards**:
   - Model origin / pivot point must ALWAYS be placed at `(0, 0, 0)` at ground level (feet level for characters, base for props).
   - Apply all transforms (`Scale: 1, 1, 1`, `Rotation: 0, 0, 0`) before export.
   - Forward orientation: In Godot, `-Z` is forward and `+Y` is up. In Blender, `+Y` is forward and `+Z` is up. Ensure the glTF export uses `+Y Up` conversion.

3. **Blender MCP Discipline**:
   - Inspect first: Call `get_addon_status()` and `get_scene_info()` before executing geometry or material scripts.
   - Incremental execution: Run Blender Python scripts in small, modular chunks via `execute_blender_code()`.
   - Visual verification: Call `get_viewport_screenshot()` to visually confirm the model before saving or exporting.
   - Target export directory: Export final `.glb` directly to `res://assets/models/<name>.glb` in the Godot project.
