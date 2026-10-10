# AI Handoff Documentation

**Main project sync 2026-10-10:** Archer Z has now been merged into `D:/Game 3D/Game_3D`, the project actually launched by Godot. See [ARCHER_Z_MAIN_SYNC.md](ARCHER_Z_MAIN_SYNC.md) for verification and restart instructions.

## Latest checkpoint — 2026-10-10: Archer fish/hawk Z

Revision 4 supersedes the landing-only ragdoll below: ragdoll starts as soon as the hawk lifts the grabbed ankles. HawkGripBone pins both shins inside force integration, joints simulate other limbs; hawk talons align to physical ankle positions rather than SkeletonModifier's restored animation pose. Release unpins the legs without restarting simulation; carry suppresses the automatic recovery watchdog until landing. Cleanup stops ragdoll on cancellation. Updated files live in the main D:/Game 3D/Game_3D project. See ARCHER_Z_MAIN_SYNC.md for current tests.

Main-project revision 3: 5.5m radius / 2.2s orbit, 3.5m/s horizontal throw, physical ragdoll on landing and forced automatic get-up for Knight/Archer/Wizard. Get-up lasts the actual clip length (0.85s) and rejects HP/shield damage, freeze, polymorph, stun, knockback and re-ragdoll. Reuses KnightRagdoll and retargets the existing get_up clip lazily for other hero rigs. Restores camera offset after recovery. Total Z damage remains 24, energy 25, cooldown 24s. Dummy has no humanoid ragdoll rig. Current verification and main-root restart instructions are in ARCHER_Z_MAIN_SYNC.md; worktree gameplay files do not include the main project's newer Knight ragdoll infrastructure.

Archer Z now fires one homing fish arrow. Frontal block cancels capture; a direct hit triggers a rigged hawk dive, inverted ankle carry at 14m, full horizontal circle and physical drop (4 + up to 20 damage, 25 stamina, 24s cooldown). Shared carry locks hero/dummy controls, respects walls/bounds, and cleans up on death/reset/round end. Authored Blender source, two GLBs, six bird animations, pooled VFX and synthesized audio are included. Revision 2 rebuilds the hawk with 2,880 triangles, one skinned mesh and layered feathers; phased wing flaps use the existing 23-bone rig. Victim FPS rolls upside down during capture and restores on release/reset, excluding nearby geometry only in that camera.

See [ARCHER_Z_HAWK_IMPLEMENTATION.md](ARCHER_Z_HAWK_IMPLEMENTATION.md) for current validation and remaining playtest limits. Earlier checkpoints describe historical states.


## Latest checkpoint — 2026-10-03: Combat spectacle for all three heroes

User requested a much stronger animation/VFX upgrade with performance kept in mind.
Implemented Knight body anticipation/C arcs/giant-sword rune-wake-impact, Archer
smooth cached two-bone bow poses/recoil/batched spiral trails and synchronized T-rex
bite effects, Wizard animated fireball/sigils/channel pose/two-layer batched lightning.
CombatSpectacle uses6 fixed burst slots,2 wave planes+24 batched sparks each;
world-fixed,0.75s lifetime, no physics/gameplay changes, idle sleeping and round cleanup.
Arrow28 segments ->1 MultiMesh; sword32 debris ->1 MultiMesh; lightning24 segments
->2 MultiMeshes. Magic/cloud/debris shadows off; physical shadows retained.
Full50/50 suites passed, then final affected Knight/Archer/Wizard suites rerun PASS.
Targeted23/23 headless and OpenGL PASS; final renderer stderr empty. Six-slot CPU microbenchmark~0.4–0.5ms,
not a full-match FPS guarantee. Runner now51 suites. See combat_spectacle.md for
complete budgets, validation logs and limitations. Models remain draft; user feel/FPS
playtest needed before further expansion.


## Previous checkpoint — 2026-10-03: Wizard presentation polish

User approved beginning visual/animation polish with performance in mind.
- Added WizardPresentation: separate visual-only arm/staff poses for charge,
  release/Counter, guard, giant staff warning/fall, hex, ice glide and storm channel.
  Exponential blend, cached6 bone indices/rests, correct imported rig axes,
  forearm continuity and wooden staff grip following actual hand endpoint.
  Stops/clears on hit, polymorph/freeze, death/reset/round lock.
- Three pre-created reusable meshes: palm rune, ice/storm ground aura, staff glow.
  Ring geometry shared; materials cached; effects hidden when unused. No spawning
  inside presentation update, no new physics queries/colliders, no gameplay tuning.
  Magical orbs, shields, runes and beams no longer cast unnecessary shadows;
  physical staff and terrain retain shadows.
- Targeted26/26 headless and OpenGL PASS; foundation44/44 headless/OpenGL,
  Z/X46/46 and C/V67/67 headless PASS; model/map isolation17/17 PASS.
  Syntax exit0 and diff clean. Final renderer after shadow cleanup26/26 PASS,
  stderr empty (scratch/wizard_polish_final_render.log).
  Presentation microbenchmark ~0.02ms/update for1000 updates on this host;
  this measures CPU presentation only, not complete-match FPS or low-end hardware.
  Full49-suite pass belongs to previous C/V milestone; runner now includes50 suites.
- Viewed actual charge, guard, staff, hex, ice and storm frames. Model remains draft;
  new casting motion/game feel needs user playtest. Next polish: Knight and Archer,
  then three-hero balancing and AI before complete-match rules.



## Previous checkpoint — 2026-10-03: Wizard C/V

User accepted foundation and Z/X; implemented the remaining Wizard skills.
V follow-up: sky/light/clouds fade in over first1s and out over last1s of the5s
channel. Original sky mode retained; targeted67/67 headless/OpenGL PASS, renderer
stderr empty (scratch/wizard_storm_fade_render.log).
- C: held aimed ice glide,15 energy start +15/s,10s cooldown,10m/s,3s maximum.
  Upward aim builds solid ice ramps up to5m above start; tiles stay fixed in world,
  expire after4s and cap at55. Release/wall/hit/depletion stops movement.
- Contact freezes enemies0.8s and stops glide; guard/i-frame prevent CC. Frozen
  actors cannot move/fight or ride caster platforms. X/C share2s expiry resistance;
  cannot chain active CC. Death/reset/round exit restores platform layers and clears ice.
- V: full100 energy, zoomed mouse selection within24m/radius7, valid ground/LOS;
  fresh LMB after camera transition confirms, Esc/hit/8s timeout cancels free aim.
  Five-second stationary dark-sky channel,20 random warned lightning strikes,
  warning0.32s/radius2/damage24/shield20, normal guard/PD and roof LOS, no energy farm.
- Spherical shield blocks all damage, shield damage, knockback and CC during channel,
  including direct HealthComponent damage. Training invulnerability stays independent.
  Camera/cursor/environment/light restored and all effects cleared on finish/round exit.
- C/V targeted62/62 headless and OpenGL Compatibility PASS; renderer stderr empty.
  Full49/49 regression suites PASS, exit0, no SCRIPT/parse errors; syntax exit0,
  diff check clean. Active scene teardown and actual practice results restore cursor.
  Viewed actual ice mountain/storm frames. Logs: scratch/wizard_cv_exit_test.log,
  wizard_cv_verified_render.log, wizard_cv_full_regression.log.
  Headless retains known dummy-renderer null-mesh teardown noise only.
  Previous foundation/Z/X playtests accepted. New C/V game feel still needs user playtest.

## Previous checkpoint — 2026-10-03: Wizard Z/X

User accepted Wizard foundation and authorized the next milestone. Z/X implemented;
C held ice glide/mountain and V immune-channel lightning storm remain unimplemented.

- Z Đại trượng:30 energy/7s, fixed facing, 12.3m x2m strip,0.8s visible outline
  and growth then0.42s fall, one38 damage/30 shield impact. Unblocked living Player
  pushed1.4m. World wall clips the warning/model length and LOS excludes targets
  behind walls. Dust/deep impact audio, shrink cleanup. Hit/Q/guard/Esc can interrupt;
  no refund. Cannot overlap basic/X/Counter; slow casting movement.
- X Hóa gà:25 energy/9s,0.22s startup, physical purple beam26m/s/radius0.12/24m.
  Visible-target autoaim at commitment or free aim; fixed trajectory afterwards.
  Front guard costs15 shield and prevents transformation; real i-frame opens PD.
  No HP damage, no basic energy reward. Hit/Q/guard/Esc cancels startup, no refund.
- PolymorphEffect attached to PlayerController and TrainingDummy:1.5s chicken,
  original visual children hidden/restored, timer label and magic puff. Movement
  remains available; attack/guard/dodge/skills/jump blocked. Cancels pending combo/
  ability/Counter/dodge and Archer/Wizard casts; keeps HP/body collider/targetability.
  Chicken can take damage. Active transform cannot refresh;2s resistance on expiry.
  Practice AI retreats, cancels queued warning before snapshot, resumes after expiry.
  Death/dummy reset/new round/scene exit clear effect and resistance.
- Chicken GLB:864 triangles, one mesh/node, original palette and editable source,
  export active selected isolated scene, no arena or third-party assets.
- Targeted initial38/38 headless and OpenGL PASS; expanded46/46 headless PASS.
  Final46/46 headless and OpenGL PASS; renderer stderr empty. Full48/48 suites PASS,
  all exit0, no SCRIPT/parse errors (scratch/wizard_zx_full_regression.log).
  Final syntax exit0/diff clean; headless has known dummy-renderer null-mesh noise only.
  Viewed actual Godot warning/fall frames; Blender asset checked clean864 triangles/1 node.
  User playtest pending for Z timing and X readability.


## Latest checkpoint — 2026-10-03: Wizard foundation

User accepted Archer and the instruction-text cleanup. Wizard kit design agreed:
elder elemental wizard with branch staff; charged autoaim fireball, giant falling
staff Z, chicken polymorph X, held aimed ice glide/mountain C, targeted 5s
random lightning V with a full-damage-immunity sphere during channeling.
Current authorized milestone implements only the character/basic/guard/Counter;
Z/X/C/V are explicitly unavailable and marked in development.

- Separate WizardCombat, selected_hero="wizard", Arena Test third selector item;
  Practice/replay/return preserve selection, opponent stays Knight.
- Charge 1.6s, 24m, 10–34 damage, 18–28m/s, swept sphere radius 0.12–0.42m.
  Slow to 55% movement; cap, release one shot; front55-degree visible live autoaim.
  Splash0–1.5m does half damage, world LOS, caster excluded, primary not hit twice;
  one15-energy award for each successful basic projectile, no skill energy farming.
- RMB75% front guard, shared100 durability/break/recovery; no immunity from normal guard.
- Q shared Perfect Dodge; fresh LMB Counter45 damage/20 shield/40m/s/24m,
  3.2m retreat in0.32s with wall collision; consumes window and prior i-frame.
- Esc/hit/guard/dodge interrupts charge; death/round reset cleans projectiles,
  particles/audio/poses. Future spells do not fall through to Knight ability logic.
- Low-poly model627 triangles/25 nodes/18 bones, idle/run/dead; staff118/2 nodes.
  Separate editable Blender source, clean selection+active-scene export, no map meshes.
- Full agreed design and milestone tuning: docs/wizard_design.md.
- Verified: full47/47 regression suites PASS, all exit0, no SCRIPT/parse errors
  (scratch/wizard_full_regression.log); Wizard44/44 headless and OpenGL PASS
  (scratch/wizard_verified_headless.log, wizard_verified_render.log), renderer stderr empty.
  Final syntax exit0; git diff --check clean apart from existing LF/CRLF notices.
  Headless retains known dummy-renderer null-mesh noise; real renderer has none.
  Initial render43/44 splash fixture failure retained in wizard_final_render.log;
  diagnostic44/44 and final44/44 pass. Charge fixture now waits actual cap and resets
  time scale between actors. User playtest remains required for feel and draft visuals.



## Latest checkpoint — 2026-10-03: X triple helix and V T-rex bait

User accepted X/C, requested an intertwined circular X trajectory, then explicitly
authorized immediate careful Ultimate implementation. Both implemented; awaiting
user playtest for spectacle/feel/balance.

- X retains30 energy/8s cooldown/3x14 damage/8 shield per arrow/24m range.
  After0.28s startup, three arrows now launch together, same tracking guide,
  orbit phases120 degrees apart,2.4 rotations/s, radius0.95m. Expand smoothly
  over first1.6m and converge over final3.2m, zero radius within0.35m.
  Guide speed20m/s, heading limit110 degrees/s; target death/hiding/freeing never
  causes reacquisition. Actual curved positions swept at <=1/120s substeps for
  world/enemy collision. Bounded28 trail segments per arrow, freed with projectile.
- V Bữa săn T-rex equips only Archer:100 full energy, no reservation during aim,
  no extra cooldown; cannot repeat while summon active. V zooms out/free cursor,
  fresh LMB after0.35s chooses visible ground24m; ESC/timeout/hit/death cancels
  selection without spending (shared death rule resets energy). Commit spends100.
  Bait physically follows0.5s arc, walls stop it. Ground orange outline radius2.2m,
  lure window0.8s; only closest eligible opponent inside receives meat tag,
  caster excluded. No damage at tagging, no through-wall tag, real i-frame avoids tag.
- T-rex roughly7.65m tall/15.3m long, low-poly forest palette and movable jaw/legs.
  Runs at14m/s toward tagged opponent, max3.5s chase, world collision and line of
  sight; caster regains movement/actions after throw. Three bites30 each at
  0.42/0.66/0.90s during1.15s bite action;90 max damage/90 shield damage.
  Real block, dodge/Perfect Dodge and mouth-area escape work; no skill energy reward.
  No opponent tagged -> eats ground bait only, no unrelated/friendly damage.
  Jaw/body crouch, dust, original synthesized roar/crunch;1.2s leave/fade.
- Wide camera during chase/bite shows whole dinosaur (normal TPS/FPS initially
  showed only legs); interpolates back at end. Keeps perspective choice, allows
  movement after throw, respects cursor changes during showcase. Round/death/scene
  cleanup restores camera and frees bait/dinosaur/ring/trails; lethal bite integrates
  with Practice winner/result cursor. HUD names/status/full-energy requirement added.
- Blender MCP created separate Archer_Trex_Ultimate_Work, preserving hunter scene.
  Export explicitly uses selection + active scene: initial export included selected
  objects from other scenes, caught and re-exported cleanly. Verified13 nodes,
  2084 triangles,6 meshes for forest_trex.glb; bait2 nodes/128 triangles.
  Base origin at feet, Godot forward+Z corrected with model rotationPI.
  Editable isolated source tools/blender_sources/forest_trex.blend; .gdignore prevents
  auto-import. No changes to Knight model/map. Poly Pizza/Sketchfab disabled, so
  created original custom low-poly geometry. Assets have no external attribution.
- Verification: X spiral11/11 headless + OpenGL, existing X/C40/40 PASS.
  Full46-suite runner46/46 PASS, all exits0/no script/parse errors:
  scratch/archer_ultimate_full_regression.log (Ultimate32 at time of full run).
  Final camera + Practice lethality expanded Ultimate37/37 PASS headless and
  OpenGL; scratch/archer_ultimate_final_test.log / final_render.log, stderr empty.
  Reviewed spiral, aim/chase/bite/leave and actual Practice FPS/TPS captures;
  preview stderr empty. Final syntax check-only gate exits0; diff --check clean.
  Headless retains known dummy-renderer mesh teardown messages, actual render clean.
- Initial Ultimate25/28 failure was fixture expectation: standalone Player has100 HP,
  Practice200; shared death clears energy. Corrected fixture expectations without
  altering health/death rules; original scratch/archer_ultimate_initial_test.log kept.
- No commit/push; preserve all pre-existing dirty work. Next: user tests X appearance
  and V trúng/trượt/camera, then balance Archer versus Knight before hero3/match flow.

## Previous checkpoint — 2026-10-03: Archer X seeking arrows and C forest escape

User accepted guard/Counter and requested the two remaining regular skills.
X/C implemented; awaiting user playtest. V meat bait/T-rex remains future work.

- X: three physical arrows14 damage each,30 energy,8s cooldown,24m flight range,
  23m/s, startup0.28s, interval0.16s, recovery0.35s. Requires a live visible enemy
  in24m/front55 degrees before spending; cast locks that identity, never reacquires.
  Initial spread-10/0/+10 degrees, steering110 degrees/s. Blue trails and lock ring.
  Target death/stealth ends tracking; arrows continue current direction until impact/range.
  Physical walls, shields and i-frames work;8 shield damage per arrow, no energy reward.
- C:25 energy/10s cooldown;5m dash in0.25s, WASD direction relative to camera,
  forward when idle. CharacterBody wall collision, normal gravity,0.20s recovery.
  Can interrupt charge/Z/X/guard; cannot overlap dodge/Counter/hit or shield stun.
  Stealth2.5s from activation, readable22% alpha silhouette and leaf burst;
  no i-frame or damage immunity. Starting basic/Z/X/Counter or taking real damage
  reveals. Guard/Q retain stealth; timeout, death and round lock restore materials.
- Practice AI stops tracking/facing/chasing new positions and cancels pending skill
  warning while hidden, resumes when revealed. Already committed swings/AOE can hit.
  PlayerController.is_targetable also prevents autoaim/counter lock on hidden actor.
- OpenGL Compatibility ignores GeometryInstance transparency: observed opaque preview,
  fixed with cached per-surface alpha materials, preserving each original override.
  Material restoration tested; no model/Blender exports.
- Arena Test HUD and Practice controls include X/C names, costs and cooldowns.
  Shared AbilitySystem supports F1/F2; default test tools and match rules unchanged.
- Validation: run_archer_xc_test.gd40/40 PASS headless and actual OpenGL with empty
  stderr (scratch/archer_xc_final_headless.log, archer_xc_render.log/error.log).
  Covers real inputs, cost/cooldown, target cone, startup/exact count/damage,
  moving target/bounded steering, wall after lock, shield, cancellation/dead target,
  dash distance/wall, stealth expiry/reveal/alpha, AI loss/reacquisition, round/death,
  FPS and freed target. Headless retains known dummy-renderer teardown errors only.
  Targeted regression15/15 suites PASS (scratch/run_*_xc_regression.log): basic44,
  Z32, defense36, initial X/C33, practice27/navigation11/AI27, Knight Counter49,
  AbilitySystem28/combat49, Knight Z27/X63/C52/V60, map17.
  Expanded40-case X/C rerun after alpha and freed-target fixes passes both renderers.
  Freed Node cannot enter typed Node3D parameter; homing validity helper now accepts
  Variant and checks instance validity first. Original failing logs retained under
  scratch/before_target_fix_*. Final check-only gate exits0; diff --check clean.
  Previous full43-suite PASS belongs to prior defensive checkpoint; runner now44,
  full44 not rerun in this stage. No commit/push; preserve existing dirty work.
- Next: user checks feel/balance, then V meat bait with giant T-rex.

## Previous checkpoint — 2026-10-03: Archer bow guard and retreat Counter

Implemented at user request; awaiting user playtest for feel/balance. Basic and Z
were accepted. X/C/V remain future stages.

- RMB holds bow horizontally: front mitigation65%, shared100 durability and
  directional block rules; rear hits unmitigated. Depletion knocks guard down,
  stuns0.65s; existing repair rules retained. Guard cancels charge/Z without refund.
  HUD shows bow durability, break warning and controls.
- Real Perfect Dodge records attacker identity (AttackPayload.attacker set by
  Knight/Archer; legacy position-only attacks resolve source). Fresh LMB within
  existing0.6s window fires enlarged arrow at attacker:50 damage,20 shield damage,
  38m/s,24m range, fixed trajectory, gold trail; arrow scale3x3x2.4.
  Walls, shields and i-frames still use shared damage rules.
- Counter consumes window and ends dodge i-frame; backward hop3.2m/0.32s,
  initial vertical speed3.6m/s, recovery0.30s. CharacterBody move_and_slide stops
  retreat at walls; no extra invulnerability. Counter grants no basic-shot energy,
  normal Perfect Dodge reward retained.
- Hit/Q/Esc interrupts action; death/round end clears movement/projectiles.
  Charge/Z/Counter cannot overlap. Archer now bypasses Knight-specific COUNTER
  strike gate when returning IDLE; original Knight counter gate retained.
- Defense suite36/36 PASS in actual OpenGL, stderr empty:
  scratch/archer_defense_render.log. Covers front/rear guard, durability once,
  break/recovery, charge/Z cancellation, PD requirement, damage, retreat/walls,
  shield blocking, expiration, round/death cleanup and FPS. Distance tolerance
  0.01m accounts for floor collision motion. Reviewed bow pose and Counter TPS/FPS.
  Full43-suite regression43/43 PASS, all exits0, no script/parse errors;
  scratch/archer_defense_full_regression.log. Final editor syntax gate exits0.
  Headless tests retain known dummy-renderer teardown errors; OpenGL stderr empty.
- No model export, Knight balance, AI or match rule changes. No commit/push;
  preserve dirty existing work. Next after playtest: X three homing arrows.

## Previous checkpoint — 2026-10-03: Archer Z rapid volley

User accepted basic Archer and requested the next step. Implemented only Z;
X/C/V are future stages. User subsequently accepted Z.

- ArcherCombat equips skill_1 `archer_rapid_volley` in the shared AbilitySystem.
  Real Z input and PlayerController._try_cast_ability(skill_1) both start it.
  6 arrows ×7 damage;25 energy,5s cooldown; startup0.22, spacing0.14,
  recovery0.35, speed30m/s, range24m, shield damage5 per arrow.
- Cast selects visible target once, commits trajectory; mouse steering limited
  12° around initial yaw at25°/s. No reacquisition/homing during volley.
  Lower-body movement retained at35% normal speed; bow draw/release cycles,
  shared green trail mesh/material and existing release audio.
- LMB/Z cannot overlap active volley, charge or recovery. Hit/Q/RMB/Esc cancel
  future emissions; already launched arrows remain physical. No energy/cooldown
  refund; death/disabled controls/round end reset clears all arrows immediately.
  Basic hits grant15 energy as before; volley hits grant none. Shared incoming
  payload preserves directional block, real i-frame/Perfect Dodge handling.
- Arena Test HUD now shows Z cooldown/25 energy; Practice generic slot HUD reads
  the equipped ability. F1 infinite energy/F2 cooldown reset work; in-progress
  cast guard still rejects overlap. X/C/V visibly remain in development.
- Validation: run_archer_volley_test.gd32/32 PASS in headless and actual OpenGL,
  stderr empty (scratch/archer_volley_render*.log). Targeted regression11/11
  suites PASS: basic44, AbilitySystem28, combat49, practice27/navigation11/AI27,
  Knight Z27/X63/C52/V60, map17. Logs scratch/*_volley_regression.log.
  Reviewed scratch/archer_volley_tps.png and archer_volley_fps.png from Practice;
  preview stderr empty. Syntax gate exits0. Full42-suite runner includes Z, but
  full suite was not rerun during this stage; previous full results are historical.
- No Blender/model, Knight kit, map, AI or match rules changed this stage.
  Modified ArcherCombat, PlayerController archer guards/movement, CombatTestHUD,
  Practice HUD controls, tests/runner/docs. Basic-test assertion updated to
  expect Archer Z equipped while still rejecting Knight ultimate.
- Next: await Z feel/balance feedback, then X three homing arrows. No commit/push;
  repository contains pre-existing accepted work and remains dirty.


## Previous checkpoint — 2026-10-03: Forest archer, playable basic shot

User chose heroes 2/3 before multi-round match flow and approved implementing
Archer stage1 first. This stage is implemented; user playtest is pending.

- Select Knight / Cung thủ rừng in Arena Test (Esc reveals cursor). Selector
  reloads a clean room; carries selection through Practice, replay and return.
  Practice human is Archer when selected; AI remains Knight, with existing
  3-second countdown, timer, HP, difficulty and results. No multi-round change.
- Archer has an isolated `ArcherCombat` child and separate character GLB, bow,
  arrow and generated release audio. Reuses the clean18-bone rig and idle/run/dead
  clips; does not attach Knight C/V animations to the hunter rig. Original Knight
  GLB and scenes were not altered during this stage.
- Hold captured LMB to charge (cap1.2s); release one physical arrow. Temporary
  tuning:12→36 damage,18→32m/s,24m range,0.4s recovery. Aim assistance finds
  a living visible target within24m/front55° and follows while holding; walls,
  death/range/cone changes drop lock. Direction commits on release; no homing.
- Swept ray collision includes world layer1 and enemy mask, excludes shooter,
  starts at chest (cannot spawn beyond nearby walls). Front block/i-frame use
  receiver damage APIs. Only positive HP delta grants15 energy/actual hit VFX.
  Misses expire by range; projectile count bounded12. RMB/Esc/hit/dodge cancels
  hold; controls disabled/death/round end/scene exit clear charge/projectiles.
- Charging moves at55% speed. Q retains shared dodge; B retains FPS/TPS.
  Archer cannot use Knight melee/block/Z/X/C/V; HUD marks skill slots as in
  development. Stage1 does not implement volley, homing arrows, stealth or T-rex.
- Blender MCP: addon/scene inspection preceded work; new Forest_Archer_Work
  scene preserves existing work. Export uses selected objects + active scene
  (multi-scene Blender export otherwise leaks unrelated objects). Final assets:
  forest_archer26 nodes/569 tris/3 clips; bow1 node/68 tris; arrow3 nodes/21 tris.
  Reviewed Blender viewport and real Godot screenshots; export contains no map,
  duplicated Knight or weapon rig. Builder: `blender/build_forest_archer.py`.
- Verification: targeted44/44 PASS with actual OpenGL renderer and empty stderr;
  includes hold/release, damage timing, quick/full charge, wall, block, moving
  target miss, cancel, FPS, actual timed dodge, death/end cleanup, hero selection,
  practice/replay/return. Headless syntax check for final ArcherCombat exits0.
  Full regression:37 PASS/4 FAIL due to audio added while the run was active
  before its import completed. After import, all4 affected suites reran cleanly
  (shield lifecycle35/35, feedback44/44, shift lock40/40, dummy17/17). Final
  coverage41 suites PASS across full run +4 reruns; initial full exit1 retained.
  Rerun logs: scratch/run_*_archer_final.log. Do not claim initial full was green.
  Logs: scratch/archer_real_test.log, archer_real_error.log,
  archer_full_regression.log; suite `run_archer_basic_test.gd` added to runner.
- Initial added dodge assertion failed because fixture only assigned DODGE state
  without starting DodgeController i-frames. Fixture corrected to initiate a real
  timed dodge with zero movement to keep the receiver in projectile path;
  gameplay was unchanged for this failure. Headless dummy renderer emits its
  existing mesh teardown diagnostics; real renderer passes with empty stderr.
- Next authorized design: Z low-damage volley, then X3homing arrows, C dash/
  invisibility, V circular meat bait + giant T-rex. Implement each separately
  after stage1 user feedback. Third hero is not designed yet. Multi-round match
  follows character work per user's chosen order. Repository remains dirty with
  prior work; no commit/push. Older next-step/checklist entries are historical.


## Workflow update — 2026-10-03

User confirmed the game/AI upgrade is working, then requested a workflow for
improving game quality. Replaced the older generic development_workflow.md with
a project-specific Vietnamese workflow: playable match loop, combat feel,
visual consistency, complete Knight AI, second hero, and export-ready demo.
Includes scoped iteration, meaningful verification, playtest scenarios,
proposed performance/art targets, and a reusable delivery worksheet.
This request changes documentation only; new roadmap features remain proposed.
Next recommended implementation is win2-round match flow. No commit/push.



## Latest checkpoint — 2026-10-03, AI difficulty and combat decisions

- User accepted the base practice duel and F1–F4, authorized further development.
  Next bounded step: upgrade PracticeOpponent with selectable Easy/Normal/Hard,
  combo chaining, delayed dodge/block decisions, and autonomous C using the
  existing Knight lifecycle. No model, map, damage tuning, new hero or commit/push.
- Arena Test panel now has a difficulty OptionButton below the practice entry.
  Normal is default; selection is transferred when entering PracticeArena,
  retained on replay/return. Dark panel background keeps tool labels legible.
  Practice HUD shows selected difficulty next to timer and AI energy; warning
  uses a separate label so the HP rows cannot overflow when it appears.
- Difficulty changes AI decisions, not base damage/health: 200 HP each, basic25,
  C30/30 energy/5s cooldown. Easy: 3.6m/s, 1.7s attack cadence, 0.32s reaction,
  single strikes and occasional blocks. Normal: 4.4m/s, 1.25s cadence, 0.22s
  reaction, combos capped2, block/dodge, C decision gap12s. Hard: 5m/s, 1.05s
  cadence, 0.16s reaction, combos capped3, block/dodge, C gap8s. Finisher recovery
  remains 0.8s. AI leaves openings and never reads human mouse/buttons.
- Combo uses actual `_try_combat_attack` during the normal 0.35–0.70s window,
  requests after0.50s, only while target stays within2.2m. Facing is committed
  across a swing/combo so strafing can escape. No manual animation/phase forcing.
- Defense observes visible melee windup and distance only. Reaction delay and
  one-response-per-threat guard avoid instant/spammed defense. Dodge uses the
  normal cooldown/i-frames/Perfect Dodge pipeline; no free damage/energy bonuses.
- PlayerController external actors now derive dodge direction, dodge completion
  locomotion, and block release from external movement. Human WASD retains its
  existing path and cannot steer the AI dodge.
- Normal/Hard C requires real energy and cooldown readiness, target within2.7m,
  no shield break/stun/finisher. Adds a reusable orange radius3m warning ring
  and HUD notice for0.55s before entering existing C startup0.15s. AI stops
  approaching during warning; no early spending/damage. Shared AOE uses mask2,
  raw payload/directional block/shield/dodge already used by human C. Broken
  shield or round-end clears warning without spending; no per-decision nodes.
- New `run_practice_ai_upgrade_test.gd`: 27/27 PASS. Covers all actual combo
  caps, delayed defense, dodge/input isolation, zero-energy/real energy/cooldown,
  no early damage, C30 HP damage, Easy skill exclusion, shield-break/end cleanup.
  Combo fixture disables target knockback to keep it in range; production AI
  intentionally stops chaining when hit knockback takes target out of range.
  AI C check waits for actual warning+startup before checking HP, no phase forcing.
- Navigation suite11/11 now also verifies Hard selection passes through entry
  and replay; existing practice lifecycle suite27/27 remains passing.
- Compatibility/GTX1650 previews checked: `scratch/practice_difficulty.png`,
  `practice_hard_countdown.png`, `practice_ai_c_warning.png`, `practice_ai_c_impact.png`.
  Actual renderer preview error log is empty; headless parse/diff checks pass.
- Full 40-suite run: 39 PASS / 1 FAIL / 0 KNOWN, runner exit1. Failure was old
  shield durability TEST14 sampling IDLE immediately after block release while
  residual recoil was settling. Added a bounded actual-physics settle wait;
  assertion still requires IDLE and retains shield/block checks. Targeted rerun
  now15/15 PASS, exit0; no production combat changes or allowlist exclusions.
  Remaining39 suites passed the full run and were not repeated after this
  fixture-only correction. Aggregate final coverage: all40 suites pass across
  full run plus corrected rerun. Preserve both reports, do not claim initial
  full report was all-green: `tools/regression_output/practice_ai_full_regression.log`
  and `practice_ai_shield_stable.log`. Z27, X63, C52, V60, map17 still PASS.
- Final real-renderer checks: navigation11/11 and corrected shield suite15/15
  PASS with empty stderr logs (`scratch/ai_navigation_rendered*.log`,
  `ai_shield_rendered*.log`).
- User confirmed the upgraded game/AI is working on2026-10-03. Base practice,
  map and Z/X/C/V acceptance remains valid.


## Previous checkpoint — 2026-10-03, practice duel and Arena Test tools

- User authorized resolving the remaining legacy regression groups, adding an
  entry button for an empty arena with one AI opponent, Arena Test F1–F4 tools,
  and a countdown for AI matches. No commit/push. Prior accepted Z/X/C/V and
  character/map assets retained.
- New `scenes/EmptyArena.tscn` contains environment only; `PracticeArena.tscn`
  plus `PracticeArena.gd` instantiate exactly one human and one AI, both using
  PlayerController and the existing authored rig/combat pipeline. Opponent has
  red armor, targets collision layer 2; human targets layer 4. Both have 200 HP,
  begin with 0 energy (earn it through hits/perfect dodge), standard shield
  recovery. PracticeOpponent approaches at 4.4m/s, commits normal attack facing,
  attacks at fair intervals and sometimes blocks after a 0.18s reaction delay.
  AI is a basic sparring opponent; no autonomous skill/ultimate usage yet.
- PlayerController defaults unchanged; external_controlled skips human input,
  mouse capture and movement axes for the AI. controls_enabled locks both actors
  during intro/results. AI feedback cannot flash the human screen.
- Practice HUD: 3–2–1 intro, 90s match timer, both HP/shield, human energy and
  Z/X/C/V readiness. Timer compensates for slow motion. Defeat ends the match;
  timeout compares remaining HP (equal = draw). Results freeze combat, cancel
  active ability/VFX, restore time/cursor, offer replay and return to Arena Test.
  Esc unlocks cursor to use navigation buttons during a match.
- Arena Test now has top-right `ĐẤU TẬP · Bạn vs AI` button and live tool states:
  F1 infinite energy, F2 no cooldowns (action/recovery still run normally),
  F3 HP invulnerability (shield/knockback still function), F4 reload/reset entire
  test room including tool flags. Tools default OFF. F4 deferred until input
  completes; only CombatTestArena handles these keys. No flags transfer to duel.
- Fixed real BLOCK -> LMB attack rejection: `_try_combat_attack` now admits BLOCK
  through existing exclusive ATTACK transition. Mid-swing RMB remains rejected.
  Fixed basic attacks against PlayerController receivers: raw AttackPayload goes
  through receiver exactly once, HP delta determines hit feedback/stamina; dodge
  and invulnerability award no hit energy, defeated actors are ignored.
- GiantSwordUltimate tracks active presentation explicitly so an unused AI
  camera cannot restore an uninitialized mouse mode on scene teardown. Active
  casts cancel before navigation. Existing V behavior still passes 60/60.
- Legacy checks: phase2/RMB now wait actual physics frames; RMB case D begins
  after case C's attack completes. Shield TEST17 now asserts broken shield
  rejects attacks, then permits attacks after shield restoration. No gameplay
  relaxation for shield-break lockout. Phase3 unchanged and now passes with
  BLOCK -> attack fix. Removed all four resolved KNOWN allowlist groups.
- New automated suites: `run_practice_arena_test.gd` 27/27 and
  `run_practice_navigation_test.gd` 11/11 (actual key events and viewport clicks).
  Navigation also verified with real Compatibility renderer/GTX1650, including
  captured cursor on return during V; headless cannot report mouse capture.
  Preview images `scratch/training_tools.png`, `practice_countdown.png`,
  `practice_fight.png`, `practice_result.png`; renderer error log empty.
- Final full regression: 39/39 suites PASS, 0 KNOWN, 0 FAIL, runner exit 0.
  Report `tools/regression_output/practice_full_regression.log`. Z 27/27,
  X 63/63, C 52/52, V 60/60, map 17/17, E 28/28, F 49/49. Runner detects
  SCRIPT ERROR/parse errors too. Pre-existing headless dummy-renderer teardown
  messages remain; actual Compatibility previews have no errors.
- User manually tested and ACCEPTED base practice duel / Arena Test tools on
  2026-10-03, then authorized the next development step. Prior skills/map
  acceptance remains valid.


## Previous checkpoint — 2026-10-03, legacy ability tests reconciled

- User accepted revised V, then authorized updating legacy ability tests.
  Scope: test scripts 5.15E / 5.15F and documentation only; no gameplay, asset,
  input binding or regression-known allowlist changes; no commit/push.
- Rewrote 5.15E for accepted Knight Z/X/C/V instead of generic prototype
  Thrust/Shield Bash/Whirlwind/Judgment definitions and instant-hit assumptions.
  Uses isolated floor + Player/TrainingDummy, real InputMap events/physics frames,
  actual charge hit, X aerial aim/LMB/physical landing, C ACTIVE damage, V ground
  ray selection/descent/impact/recovery. Each scenario resets via respawn;
  casts finish naturally, no forced phase advance to satisfy damage assertions.
- Retains/improves checks: exact tuning, stamina cost/insufficient stamina,
  independent cooldowns/retrigger rejection, no early damage/no stamina reward,
  ability lockout, X does not inherit Shield Bash repair, V restores camera/cursor,
  finisher recovery and DEAD restrictions. Targeted 5.15E: 28/28 PASS.
- Preserved all original 44 combat integration checks in 5.15F, added five:
  reject V during Z without spending, wait for Z recovery/shield retraction,
  enter V aiming, LMB confirmation without combo, natural camera/input cleanup.
  Then continue FPS/TPS, death/respawn tests. Targeted 5.15F: 49/49 PASS.
- Fixed integration fixture: default headless viewport is tiny, so CombatTestHUD
  intercepts ground-selection clicks. Set viewport 1152x720 before loading scene;
  keep real MouseButton events through normal input routing. Disable unrelated
  arena attacker processing so extended waits do not alter HP/stamina randomly.
- Godot editor parse/import PASS and diff check PASS. Specialized Z/X/C/V tests
  still carry detailed block/dodge/cancel/FPS/map coverage; no exclusions added.
- Final full regression: 37 suites, 33 PASS / 4 KNOWN / 0 FAIL; runner exit 0.
  5.15E 28/28, 5.15F 49/49, Z 27/27, X 63/63, C 52/52, V 60/60, map 17/17.
  No script/parse errors; pre-existing headless renderer teardown messages remain.
  Report `tools/regression_output/knight_ability_reconciliation_final.log`.
- Other existing KNOWN suites (TPS targeting, old FSM/RMB, shield break) remain
  separate follow-up work. Do not describe KNOWN as passing or all-green.

## Previous checkpoint — 2026-10-02, V revision: targeted colossal sword

- User requested a much larger SOLID ordinary sword, camera zoom-out on V,
  LMB ground selection, blade falling through clouds onto selected point,
  heavy impact then disappearance. This supersedes the automatic caster-centered
  spectral V prototype below. No Git commit/push.
- Added GiantSwordUltimate node to isolate targeting/cinematic camera/HUD.
  V reserves 100 stamina and freezes AbilityAction STARTUP until fresh LMB.
  Camera zooms out over 0.45s; cursor is visible, ground ring follows ray hit.
  Valid surfaces: environment layer 1, upward normal >=0.7, within 24m and
  height +/-4m from cast origin. Invalid clicks keep aiming; held LMB from before
  V cannot confirm. ESC during aim refunds reservation; death resets stamina.
- LMB locks exact world impact origin and starts 1.40s descent. Existing 90
  damage / 4.5m AOE, active 0.20s; recovery extended to 2.0s for impact/dissolve.
  Shared radial damage/block/shield/occlusion/dodge/Perfect Dodge code retained.
  Click never leaks into normal LMB combo; movement/combat/perspective toggle
  remains locked during ultimate. Camera/cursor restore on finish/cancel/death.
- Separate cinematic camera does not modify original FPS/TPS camera settings.
  Temporarily reveals FPS head/neck during cinematic and restores original mask.
  Keeps framed target during descent/impact; shakes 0.65s, eases back near end.
- Rebuilt `assets/models/knight_ultimate_sword.glb` in separate Blender scene
  Ultimate_Colossal_Sword: 24.5m tall, 8 mesh nodes, VERIFIED 104 triangles,
  opaque steel/bronze/leather. Saved `blender/knight_ultimate_colossal_sword.blend`.
  Selected active-scene export only. Original character/map/animation assets unchanged.
- GiantSwordVFX reuses meshes per player: drop from 60m through cloud puffs at 34m;
  clouds split, ring, shockwave and 32 debris puffs at impact. Fully solid lit
  sword throughout descent/impact. Opaque shader discards fragments with glowing
  edges only late in recovery; no transparency during flight. All effects cleaned
  up on cancellation/death; no per-cast node creation.
- Added original synthesized WAVs `assets/audio/ultimate_fall.wav` and
  `ultimate_impact.wav`; actual AudioStreamPlayers play descent/impact (not only
  feedback signals). Audio stops with cancellation. Existing ultimate feedback
  signal remains once per impact.
- Targeted V suite expanded: 60/60 PASS, real InputMap/MouseButton events and
  physics frames; aim freeze, zoom/cursor, invalid clicks, held/fresh LMB, ESC,
  targeted remote AOE, block/dodge, death/cancel/restore, shake/debris/dissolve.
  Godot editor import/parse PASS; diff check PASS.
- Real Godot Compatibility render on GTX 1650 inspected at
  `scratch/colossal_aim.png`, `colossal_descent.png`, `colossal_impact.png`,
  `colossal_dissolve.png`; preview has no script/shader errors and restores captured
  cursor (mode 2) and gameplay camera. Headless mouse-mode restoration test compares
  saved mode because headless driver cannot enter captured mouse mode.
- Full regression: 37 suites, 31 PASS / 4 KNOWN / 2 old FAIL (5.15E 9/22,
  5.15F 42/44, identical failure assertions to baseline). V 60/60, C 52/52,
  X 63/63, Z 27/27, map 17/17; no new failed assertions. Full runner exit 1,
  not all green; pre-existing headless renderer teardown errors remain. Report
  `tools/regression_output/colossal_ultimate_regression_final.log`.
- User manually tested the revised V and reported it working (2026-10-02).
  Revised V milestone is USER ACCEPTED; earlier pending notes are historical.
  Next planned work: reconcile legacy ability tests with the current Knight design.

## Previous checkpoint — 2026-10-02, Knight V — Giant Sword Ultimate

- User manually accepted C and asked to continue; previous pending notes are
  historical. Completed V only; no Git commit/push.
- Preserved tuning: 100 stamina required/spent, cooldown 0, damage 90 / 4.5m,
  STARTUP 0.70s -> ACTIVE 0.20s -> RECOVERY 0.80s. V starts immediately; impact
  remains at cast origin, marked by a ring, even if incoming knockback moves caster.
- V damages once at ACTIVE through shared radial C pipeline: wall/range/height
  checks, per-target guard, existing block/shield and dodge/Perfect Dodge/Counter.
  No basic-attack stamina reward. C/V share stationary physics and input lock;
  cancellation/death cleans up with no refund or delayed impact.
- Reusable GiantSwordVFX uses a Blender sword (40 triangles), descends from 8m,
  lands exactly at ACTIVE and fades during recovery. No per-cast node spawning.
- Separate Blender scene Knight_V_Work saved to `blender/knight_v_giant_sword.blend`.
  Export selected objects AND active scene (`use_active_scene=True` excludes
  selected objects from other scenes): `assets/models/knight_v_giant_sword.glb`
  has 20 nodes/18 bones/one clip; `knight_ultimate_sword.glb` has 3 mesh nodes.
- `tools/extract_ultimate_animation.gd` verifies rest transforms/track paths,
  extracts `assets/animations/knight_v_giant_sword.tres` (1.7s, 36 tracks).
  Retain immutable rest tracks; omit scale to preserve FPS head mask. Runtime
  adds animation to existing rig. Base character and map assets unchanged for V.
- Fixed duplicate ultimate audio signal: play_audio_event already emits it.
  Radial presentation/audio is guarded once per cast, including retry dispatch.
- Targeted V 36/36 PASS with real InputMap/physics frames: timing/cost, radial
  edge/wall/height, single damage/audio, movement/input lock, cancellation/death/
  respawn, block, FPS, knockback origin, dodge/Perfect Dodge/Counter reward guard.
  Godot editor parse passed. Real Compatibility-renderer preview inspected at
  `scratch/ultimate_runtime_screenshot.png`; preview exited without script errors.
- Full regression: 37 suites, 31 PASS, 4 KNOWN, 2 FAIL. V 36/36, C 52/52,
  X 63/63, Z 27/27, map 17/17. FAIL suites remain 5.15E 9/22 and 5.15F 42/44;
  failures match baseline. Report `tools/regression_output/ultimate_regression_final.log`.
  Full runner exit 1; not all green. Existing headless renderer teardown
  "Parameter m is null" messages remain distinct from gameplay/script results.
- V manual acceptance pending: in CombatTestArena fill stamina to 100, stand
  within 4.5m of a dummy, press V. Expect ring and descending sword, one 90 HP
  hit after 0.70s, stamina 0, then recovery. Try FPS/TPS and inspect debugger;
  holding V must not repeat, LMB/RMB/Q should work afterwards.

## Previous checkpoint — 2026-10-02, Knight C — Whirling Blade

- User tested the map fix and reported it is working. Continued the planned
  Z -> X -> C -> V sequence with C only; no Git commit/push.
- C now owns STARTUP 0.15s -> ACTIVE 0.45s -> RECOVERY 0.30s through the existing
  AbilityAction. Preserved Knight tuning: damage 30, range 3m, stamina 30,
  cooldown 5s. Damage is dispatched once on entry to ACTIVE, not on cast.
- WASD is locked while C runs; existing incoming knockback and gravity remain.
  C can replace allowed attack follow-through/block without leaving stale states.
  Death/cancellation clean up animation and VFX; normal input resumes afterwards.
- Added `PlayerCombat.execute_radial_ability_impact`: bounded query, radial and
  height checks, wall occlusion, dead-target rejection and per-cast target guard.
  Uses existing target damage APIs/AttackPayload, block/shield rules, i-frame and
  Perfect Dodge pipeline, hit signals, damage number pool and feedback hooks.
  C does not grant the attacker's basic-attack stamina reward.
- Added one reusable WhirlingBladeVFX node per PlayerCombat (384-triangle ring,
  unshaded alpha fade over ACTIVE). No per-cast node spawning.
- Blender work was created in a separate `Knight_C_Work` scene. The original
  scene was preserved. Imported the cleaned character, authored a full-revolution
  root/sword pose clip and exported only rig + mesh (684 triangles) to
  `assets/models/knight_c_whirling_blade.glb`. Saved authoring source at
  `blender/knight_c_whirling_blade.blend`.
- Extracted `assets/animations/knight_c_whirling_blade.tres` with
  `tools/extract_whirling_animation.gd`, which checks all bone rest transforms
  and animation track paths against the existing character. Runtime loads only
  this animation resource, not another character or arena. The base character
  GLB and its nine existing animations were not changed for C.
- Godot import/validation passed after completing the new class scan.
  Targeted C test: 52/52 PASS, using actual physics frames and InputMap events;
  tests include front/rear/side AOE, wall/range rejection, single hit, animation
  spin, movement lock, cooldown/cost, cancellation, death/respawn, FPS, block,
  receiver i-frame/Perfect Dodge/Counter and repeat-dispatch reward prevention,
  transitions from block/attack, FPS head hiding and wrist-pose cleanup.
- A transition test reproduced an inherited basic-attack wrist pose (50/51).
  Fixed C import to retain immutable rest-pose tracks, and extraction excludes
  scale tracks so existing FPS head/neck hiding retains ownership. Final clip
  has 36 tracks. No changes to the original character rig/animations.
- Regression runner includes C (36 suites); report:
  `tools/regression_output/whirling_regression_final.log`. Initial report is
  retained separately; its isolated shield durability TEST 14 failure passed
  15/15 on recheck (`whirling_shield_recheck.log`).
- Final full regression: 36 suites, 30 PASS, 4 KNOWN, 2 FAIL. C 52/52,
  Z 27/27, X 63/63 and map 17/17. The remaining FAIL suites are the same
  pre-existing 5.15E (9/22, 13 failures) and 5.15F (42/44, 2 failures) documented
  at the Z/X checkpoint; no new failed assertions remain in the final run.
  Phase 2's intermittent TPS assertion is again KNOWN; shield durability is
  back to 15/15. Full suite exit remains 1, not an all-green result.
- Manual C acceptance remains pending: in CombatTestArena with stamina >=30,
  stand within 3m of a dummy, press C once. Expect a 0.15s windup, one 30 HP hit,
  circular spin/VFX and 0.30s recovery; holding C does not repeat. Verify WASD,
  RMB/Q/Z and LMB are gated during C, then usable afterwards; retry after 5s,
  repeat in FPS and inspect debugger. Existing headless renderer teardown errors
  below remain separate from script/gameplay test results.

## Latest checkpoint — 2026-10-02, duplicated map attached to player

- User symptom: arena appears duplicated and follows the character.
- Root cause: `assets/models/player_character.glb` included 42 `Arena_*`
  mesh nodes alongside the Gladiator rig, so `Player/Visuals/CharacterModel`
  instanced a second arena under the moving player.
- Removed those nodes and unused mesh definitions from the character GLB;
  remapped scene roots, node children, skin joints and animation target indices.
  The binary geometry/animation buffer, accessors and buffer views are unchanged.
  Character retains 20 nodes, one mesh, 18 bones and all nine animations.
- No edits to the Blender scene, arena GLB, map collision, camera or combat code.
- Backup: `scratch/player_character_before_map_fix.glb.tmp` (ignored by Git).
- Regression test `run_character_map_isolation_test.gd` reproduced four failures
  before the asset fix and now passes 17/17 (including a skin-binding check added
  after the initial 16/16 run). It verifies the imported character,
  all authored animations and the actual main scene while the player moves.
- Godot headless editor import/validation passed; diff check passed. Renderer
  teardown messages described below still appear in headless tests.
- Regression runner includes the map isolation test (35 suites); report:
  `tools/regression_output/map_fix_report.log`.
- Initial full run: 29 PASS, 3 KNOWN, 3 FAIL. Two FAIL suites are the previously
  verified 5.15E/5.15F prototype/lifecycle issues (same failed assertion IDs).
  The third was Z's unstable movement test: it called movement repeatedly outside
  physics frames with an attack dummy on the charge path (measured 0.49m vs >0.5m).
  Corrected only that test fixture to use a clear path and actual physics frames;
  targeted Z rechecks pass 27/27 with 3.00m travel. X remains 63/63 and map 17/17.
  Full regression was not rerun after the test-only correction; the original
  full-run report is retained. Z recheck: `map_fix_z_recheck.log`.
- Manual visual acceptance remains pending. Restart the running game after
  Godot reimports the model and verify WASD/mouse no longer move a second map.
- Future character exports must include only the character mesh and armature,
  excluding arena objects. The isolation test guards against another bad export.
- No commit/push.

## Latest checkpoint — 2026-10-02, Z/X review

This section supersedes the older 2026-10-01 snapshot below. The working tree
already contained dodge, Perfect Dodge, Counter, stamina, AbilityAction,
KnightAbilities, Shield Charge and Sky Dive work when this review began. Preserve
those uncommitted changes; do not assume the repository is clean.

- Blender MCP read-only check succeeded: Blender 5.2.2 LTS, addon 1.8,
  protocol 13; scene contains 46 objects and 13 materials. No Blender edits.
- X: startup -> physical takeoff -> aerial AIM -> fresh LMB confirmation ->
  camera-directed dive -> physical floor contact -> recovery. Holding LMB before
  AIM or pressing on its entry frame must not confirm. AIM has no automatic dive.
- Fixed missing X landing damage by calling the existing ability effect while
  AbilityAction is still ACTIVE, immediately before entering recovery. Uses
  configured AOE range 3.5 and damage 35; existing per-cast target tracking
  prevents repeat damage. No basic-attack stamina refund on landing.
- Fixed Z impact position snap: horizontal velocity stops at the position
  resolved by physics instead of assigning a position one metre from the target.
  Z tuning remains 25 damage, 20 stamina, 4s cooldown.
- Targeted verification: Z 27/27; X core 63/63. The new X assertions first failed
  against the missing damage implementation; the Z position assertion first
  failed with a target 1.8m ahead before the snap was removed.
- Godot headless editor validation succeeded. Headless runtime tests also emit
  `mesh_get_surface_count: Parameter "m" is null` during mesh teardown; the same
  messages were present before these patches. Do not describe runtime logs as
  error-free or treat automated results as manual acceptance.
- Regression runner now includes the Z and current X core suites. The older
  `run_task_knight_sky_dive_foundation_test.gd` is not the current runtime gate.
- Full regression: 34 suites, 28 PASS, 4 KNOWN, 2 FAIL. The runner remains
  nonzero; no failures were hidden or tests weakened. `run_task5_15e` has 13
  failures (9/22) and `run_task5_15f` has 2 (42/44). Both were rerun with only
  this review's X landing call and Z snap removal temporarily reverted, and
  produced the exact same failed assertion IDs. Final source was restored in
  `finally`. These are pre-existing prototype-loadout/lifecycle test issues,
  not new regressions from this patch. The four KNOWN suites are Phase 2,
  Phase 3, RMB lifecycle and shield break. Reports and baseline logs are in
  `tools/regression_output/`.
- Manual check still required: Z toward dummy, steer mouse, verify smooth stop,
  25 HP loss and shield retraction; then X, release any held LMB, aim downward,
  click once, verify 35 HP loss near landing and no repeated damage during
  recovery. Confirm fresh LMB/RMB/Q work afterwards and check the debugger.
- No commit or push. User acceptance remains pending.

## Project Overview
- **Name**: Game_3D
- **Engine**: Godot 4.3 (GDScript 2.0)
- **Genre**: 3‑D Arena Combat (Third‑Person)
- **Target Platform**: Windows PC (16 GB RAM, 4 GB VRAM)
- **Repository**: `D:/Game 3D/Game_3D` (already initialized, no pending commits)

## Current State (as of 2026‑10‑01)
- All core combat systems are **complete and passing**:
  - 3‑hit combo system (Task 5.14) – **PASS** (14/14 tests)
  - Combo input buffer (Task 5.14A) – **PASS** (14/14 tests)
  - Finisher‑recovery pause (Task 5.14C) – **PASS** (9/9 tests)
- Full regression suite (22 test scripts) runs with **0 failures**.
- No new gameplay features have been added beyond the combo system.

## Implemented Gameplay Systems
- Player movement
- FPS/TPS camera (centered TPS configuration)
- Combat FSM (states: IDLE, RUN, ATTACK, BLOCK, DEAD)
- Basic attack handling
- 3‑hit combo
- Combo input buffer
- Finisher recovery (0.8 s pause)
- Directional block
- Shield durability and break mechanics
- Hit reaction
- Knockback
- Camera recoil
- Slash Arc VFX
- Hit Impact VFX
- Block Impact VFX
- Shield Break VFX
- Damage Numbers UI
- Attack Telegraph
- CombatFeedback node (coordinates feedback pipeline)
- TrainingDummy and AttackTrainingDummy entities
- CombatTestArena scene (integration/testing arena)
- Combat HUD
- Low‑shield warning system
- Automated regression suite (run via `tools/run_regression.ps1`)

## Finisher Recovery Details (COMBO_FINISHER_RECOVERY)
During the 0.8 s recovery window:
- Attack input is **blocked**.
- Block input is **blocked**.
- Movement and state behavior remain consistent with the current implementation (character stays in a neutral state, unable to perform new attacks or blocks).

## Tooling
- The regression suite can be executed with the repository‑relative script:
  `tools/run_regression.ps1` – runs all automated tests and reports a summary.

## Handoff Checklist for the Next Agent
- Verify the repository is clean (`git status --short` shows no changes).
- Run the full regression suite via `tools/run_regression.ps1` to confirm the baseline passes.
- Review this `AI_HANDOFF.md` for a concise project snapshot.
- Continue from the **next checkpoint** after the combo system – e.g., implement distinct combo attack animations (Task 5.14B) or address other backlog items.
- Follow the workflow described in `docs/development_workflow.md` for any new feature work.

---
*Generated automatically by Antigravity on 2026‑10‑01.*
