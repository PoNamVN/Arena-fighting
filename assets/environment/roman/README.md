# Roman Colosseum theme

`res://scenes/environments/RomanArenaVisual.tscn` contains only scenery, with eight baked mesh surfaces. The main and practice arenas instance it; collision and actor spawning remain in their original scenes.

Style: travertine stone, warm sand, three arcade levels, twelve seating rows, four closed wooden gates, imperial viewing pavilion, bronze guardians, legion eagle banners, partial linen velarium and distant hills. Spectators are static decorative geometry, with no AI or hurtboxes.

To build another arena, create a separate theme scene and palette; keep the common arena collision/spawns. No map selector has been added yet.

Authoring source: `res://tools/environment/build_roman_arena.gd`. Run it with Godot headless from the project root to regenerate this theme's `.res` meshes and packed scene. It writes only the Roman theme assets; back up manual edits to those assets before regenerating.

Ground colour is exposed to skill VFX through `FloorCollision` metadata. Flags inherit the world's pause and stop during ultimate cutscenes. No SSAO, SSR, SDFGI or volumetric fog is enabled by this theme.
