# Combat spectacle — 2026-10-03

Visual-only upgrade requested by the user; damage, energy, cooldowns, targeting,
physical projectiles and cast durations retain their existing rules.

## Presentation
- Knight: blended forward body pose on Shield Charge/Sky Dive; moving three-arc
  blade shader for C; decorated gold targeting circle, tapered descending wake,
  layered landing shock and flying sparks for the giant sword. Existing clips remain.
- Archer: cached bone/rest data and smooth two-bone arm posing for bow draw;
  body/bow draw and release recoil, without a casting circle in front of the bow; curved spiral
  trails remain on their physical paths. T-rex entry/bites emit shock effects;
  jaw close and body recoil synchronize to the existing three bite timestamps.
- Wizard: animated fireball surface, decorated rotating palm/ground/shield sigils,
  slight upper-body casting recoil, controlled channel hover/hand motion; 12-segment
  zigzag lightning with bright core/soft halo and ground electric shock bursts.
  Sky still fades in/out over first/last1s of the5s channel. Confirm restores valid
  blue zone color even when the mouse last hovered over invalid ground.
- Shader sigils use mixed transparency for readability on bright ground, no external
  textures or screen-space glow dependency. Works in Godot4.3 OpenGL Compatibility.

## Fixed budgets and batching
- CombatSpectacle:6 preallocated burst slots per actor; each has2 ring planes and
  one24-instance spark MultiMesh. Maximum144 spark instances per actor. Saturation
  replaces the oldest slot; no growing node count. Geometry is shared, shaders cached.
- Burst lifetime0.75s; no physics queries/colliders. World effects remain fixed when
  actor moves. Pool sleeps when idle; death/CC/round reset clears it and restores pose.
- Spiral arrow:28 history transforms rendered by one MultiMesh per arrow rather than
  28 separate trail nodes. Existing12-arrow cap and cleanup remain.
- Giant sword debris:32 transforms in one MultiMesh instead of32 mesh nodes.
- Lightning:12 core and12 halo instances in two MultiMeshes, cached mesh/materials,
  instead of24 separate segment nodes/draw submissions per bolt. Warning/bolt lifetime
  and20 strikes in5s unchanged. No extra shadow-casting lights.
- Magical mesh and cloud/debris shadows disabled; physical character/sword/terrain
  shadows retained. No large textures, new models or renderer changes.

## Verification
- Full50/50 regression suites PASS, exit0, no SCRIPT/parse errors:
  scratch/spectacle_full_regression.log. This run started before the final batching/
  pose adjustments; affected suites were rerun separately afterwards.
- Final targeted spectacle23/23 headless and OpenGL Compatibility PASS; renderer
  stderr empty. Viewed actual lightning, spiral paths, sword fall/impact and T-rex frames.
- Latest affected reruns: Knight Z27/27, X63/63, V60/60; Archer basic44/44,
  defense36/36, spiral11/11, Ultimate37/37; Wizard C/V67/67. Wizard presentation26/26
  OpenGL PASS. Syntax and diff checks pass. Runner now contains51 suites.
- Logs: spectacle_release_headless.log, spectacle_release_verified_render.log,
  spectacle_knight_z.log, spectacle_knight_x.log, spectacle_knight_v_verified.log,
  spectacle_archer_basic.log, spectacle_archer_defense.log, spectacle_archer_spiral.log,
  spectacle_archer_ultimate.log, spectacle_wizard_cv_verified.log.
- Six active pool slots CPU microbenchmark about0.4–0.5ms/update on this host. This
  measures this visual component only, not full-match FPS, GPU time or low-end devices.
  Render draw counters captured as diagnostics; differing frames are not an A/B FPS test.
- Headless retains known dummy-renderer null-mesh teardown noise. Initial test failures
  are preserved in scratch: renderer arrow sampling timing and old debris.visible
  assertion after replacing nodes with batched transforms; final tests use actual phases
  and batch visibility. Do not claim high-poly/final art or guaranteed60FPS.
- Needs user playtest: impact strength, effect density/readability, animation feel and FPS.
