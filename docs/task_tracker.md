# Task Tracker & Roadmap

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


Workflow cho các đợt tiếp theo: [Nâng chất lượng game](development_workflow.md).

## Current development checkpoint (2026-10-03)

- Map attached to/duplicated under Player: asset fixed, isolation 17/17,
  user manually tested and reported working.
- Knight C — Whirling Blade: IMPLEMENTED / USER ACCEPTED (2026-10-02). Existing
  30 damage / 3m / 30 stamina / 5s tuning; authored spin clip and reusable VFX;
  phase-controlled AOE through shared damage APIs; targeted suite 52/52.
- Knight V — targeted colossal sword: IMPLEMENTED / USER ACCEPTED (2026-10-02).
  24.5m opaque sword, zoom-out camera and fresh LMB ground selection (24m),
  clouds/descent/slam/shake/debris/dissolve. 100 stamina / 90 damage / 4.5m;
  fall 1.40s, active 0.20s, recovery 2.0s. V targeted 60/60; latest regression recorded below.
- Legacy ability tests: 5.15E 28/28, 5.15F 49/49. Resolved remaining TPS/RMB/
  shield KNOWN groups; normal BLOCK -> attack fixed. Broken shield lockout retained.
- Practice duel: IMPLEMENTED / USER ACCEPTED (2026-10-03).
  Entry button, environment-only arena + one mobile AI, 3–2–1 intro,
  90s timer, 200 HP, win/loss/draw, replay/return. New suites 27/27 + 11/11.
- Arena Test tools: IMPLEMENTED / USER ACCEPTED.
  F1 infinite energy; F2 no cooldown; F3 HP invulnerability; F4 full room reset.
  Default OFF, restricted to Arena Test. Prior accepted skill/map behavior retained.
- AI difficulty upgrade: IMPLEMENTED / USER ACCEPTED (2026-10-03).
  Easy/Normal/Hard selector, combos1/2/3, delayed block/dodge, C with orange
  warning and real energy/cooldown. New AI suite27/27, navigation11/11.
  Final coverage40 suites PASS across full run39PASS and fixture-corrected
  shield rerun15/15; see AI_HANDOFF for original failure and logs.
  User confirmed the upgraded game is working. User subsequently chose heroes
  2/3 before best-of-three; current priority is the forest archer.
  Older roadmap entries below are historical; consult AI_HANDOFF.

## Forest archer — X triple helix / V T-rex bait (2026-10-03)

- IMPLEMENTED / AWAITING USER PLAYTEST. User accepted previous X/C and explicitly
  requested spiral X then Ultimate. X now launches3 simultaneous physical helices,
  120 degrees apart,0.95m radius,2.4 rotations/s; opens then converges. Curved
  collision/trails;20m/s, same30 energy/8s cooldown/42 max damage.
- V100 full energy: zoom/select ground24m with fresh LMB, ESC cancels before spend.
  Physical meat arc, outline2.2m,0.8s tag window; caster excluded, walls respected.
  Giant T-rex chases marked enemy and bites3x30, else only eats bait. Block,
  i-frame/Perfect Dodge and escaping mouth work. Wide showcase camera/roar/dust,
  walking/jaw/crouch, leave/fade; round/death cleanup and match win verified.
- Original isolated2084-triangle T-rex and128-triangle bait; GLB13/2 nodes clean,
  editable Blender source retained. Knight/map assets unchanged.
- Full46/46 suites PASS (Ultimate32 then); final expanded Ultimate37/37 headless
  and OpenGL PASS, empty stderr; spiral11/11 both renderers, X/C40/40 retained.
  Final syntax gate exits0, diff --check clean. User validation of feel pending.
- Next: X/V playtest then Archer/Knight matchup balance.

## Forest archer — X/C (2026-10-03)

- IMPLEMENTED / AWAITING USER PLAYTEST. Guard/Counter USER ACCEPTED.
- X three seeking arrows:14 damage each,30 energy,8s cooldown; startup0.28s,
  spacing0.16s,recovery0.35s;23m/s,24m range,110 degrees/s steering.
  Needs visible front target; locks identity once, no reacquisition. Walls/shields
  still block,8 shield damage per arrow; no energy from skill hits.
- C dash5m/0.25s in WASD direction (idle forward), collision with walls;25 energy,
  10s cooldown,recovery0.20s. Stealth2.5s, leaf burst, readable alpha silhouette.
  AI loses tracking; attacks/actual damage reveal. No invulnerability.
  Death/round end fully restores materials/action state. X/C HUD supports F1/F2.
- New X/C40/40 PASS headless and OpenGL, stderr empty. Related15/15 regression
  suites PASS. Reviewed FPS/TPS captures; fixed alpha support for GL Compatibility.
  Runner now44 suites; full44 not rerun this stage (previous full43 passed).
- Next: playtest X/C, then V bait/T-rex.

## Forest archer — Bow guard and retreat Counter (2026-10-03)

- IMPLEMENTED / AWAITING USER PLAYTEST: RMB horizontal bow guard, front65%
  mitigation, shared100 durability, rear full damage, depletion stun0.65s.
  HUD shows bow durability/break; guard cancels charge/Z without refund.
- Perfect Dodge -> fresh LMB within0.6s: enlarged physical arrow toward attacker,
  50 damage/20 shield damage,38m/s,24m range; gold trail, no homing.
  Backward hop3.2m/0.32s stops at walls; recovery0.30s, ends dodge invulnerability,
  consumes Counter window and grants no basic-shot energy.
- Defense suite36/36 PASS in actual renderer, empty stderr; full43-suite
  regression43/43 PASS, exits0; final syntax gate exits0, git diff --check clean.
  Guard, break, damage, wall/shield, FPS and cleanup covered.
- Next: user playtest of defensive kit, then X three homing arrows.

## Forest archer — Stage 2: Z rapid volley (2026-10-03)

- IMPLEMENTED / USER ACCEPTED: press Z for6 sequential physical arrows,
  damage7 each (42 maximum),25 energy,5s cooldown. Startup0.22s, interval0.14s,
  recovery0.35s; range24m/speed30m/s; movement35% while firing.
- Aim assist chooses visible target only at cast start. Direction commits, with
  at most12° steering at25°/s; emitted arrows never home. Repeated Z/LMB cannot
  overlap volley; Q/RMB/Esc/hit cancel remaining emissions without refund.
- Each arrow uses actual wall collision, block/i-frame damage APIs. Shield
  damage5 per arrow (30 maximum); skill hits do not generate basic-shot energy.
  Round end/death clear emissions and arrows; F1/F2 work in Arena Test.
- Reuses existing bow/arrow/audio, adds shared green trail resources and cycling
  bowstring draw pose. HUD shows Z cooldown/cost; X/C/V remain unavailable.
- Z suite32/32 PASS headless and real renderer (empty stderr). Basic shot44/44
  remains PASS. Eleven targeted regression suites all PASS: AbilitySystem,
  combat integration, practice/navigation/AI, Knight Z/X/C/V and map isolation.
  Full42-suite runner now includes Z; full runner was not repeated this stage.
- Z accepted; defensive kit added next, then X after playtest.

## Forest archer — Stage 1 (2026-10-03)

- IMPLEMENTED / USER ACCEPTED: selector in Arena Test; separate hunter
  model/wood bow/arrow; human Archer versus Knight AI with existing countdown.
- Hold LMB up to1.2s, release one arrow; aim assist24m/front55°/visible living
  target; fixed flight direction after release. Quick12→full36 damage,
  speed18→32m/s, range24m, recovery0.4s; temporary tuning for playtest.
- Swept collision against world and enemy, receiver-owned block/i-frame logic;
  successful damage grants15 energy; RMB/Esc/hit/dodge cancel charge;
  death/round end clears projectiles. No Knight block/melee/skills for Archer.
- Prototype asset budget: character569 tris, bow68, arrow21; original rig18 bones
  reused with isolated meshes/materials and idle/run/dead clips.
- Z/X/C/V are visibly unavailable; not implemented in this stage. Next: Z volley,
  then X homing trio, C dash/invisibility, V meat bait/T-rex as requested.
- Archer44/44 PASS with real renderer/empty stderr; syntax exit0. Regression
  coverage41 suites PASS across full37PASS/4 audio-import failures +4 clean reruns.
  Original failure report retained; details in newest AI_HANDOFF checkpoint.

## Milestone 0: Environment & Workflow Setup
- [x] **Audit environment**: Antigravity, Godot 4.3, Blender 5.2 MCP status verified.
- [x] **Initialize Git repo**: Initialized in `D:\Game 3D\Game_3D` with `.gitignore`.
- [x] **Install Antigravity Rules**: `00-core-discipline`, `10-godot-standards`, `20-blender-lowpoly`, `30-qa-verification`.
- [x] **Install Antigravity Skills**: `godot4-game-dev`, `blender-mcp-pipeline`, `systematic-debugging`, `verification-discipline`.
- [x] **Initialize Documentation**: `gdd_overview.md`, `architecture.md`, `task_tracker.md`.

---

## Milestone 1: Core Player Controller & Third-Person Camera [COMPLETED]
- [x] **Task 1.1**: Define standard input actions in `project.godot` (`move_forward`, `move_backward`, `move_left`, `move_right`, `jump`, `sprint`) with fallback key bindings.
- [x] **Task 1.2**: Create `Player.tscn` with `CharacterBody3D`, `CapsuleShape3D`, Capsule placeholder mesh, and facing indicator.
- [x] **Task 1.3**: Implement Third-Person SpringArm3D Camera with vertical clamp (`-75°` to `+60°`), mouse capture, Esc release, and click recapturing.
- [x] **Task 1.4**: Implement ground movement relative to camera yaw, gravity, jump, sprint, and smooth character rotation in `PlayerController.gd`.
- [x] **Task 1.5**: Create `ArenaTest.tscn` with floor, obstacles, lighting, environment, and set as `run/main_scene`.
- [x] **Verification Gate**: Headless parse check & 10-frame automated physics simulation test passed with return code 0.

---

## Milestone 2: Arena & Combat Foundation [COMPLETED]
- [x] **Task 2.1**: Implement reusable `HealthComponent.gd` (clamping, negative damage prevention, signals, safe death).
- [x] **Task 2.2**: Implement `PlayerCombat.gd` (basic melee attack, 25 damage, 2.2m range, 0.4s cooldown, wall occlusion raycast, visual slash cue).
- [x] **Task 2.3**: Create `TrainingDummy.tscn` & `TrainingDummy.gd` (stationary target on Layer 3, hit flash effect, billboard health bar with SubViewport ProgressBar).
- [x] **Task 2.4**: Upgrade `ArenaTest.tscn` (perimeter walls, central combat ground, lighting, player and dummy instances).
- [x] **Task 2.5**: Configure `attack` action in `project.godot` (Left Mouse Button) with fallback support in code.
- [x] **Verification Gate**: Headless parse check & 5-stage automated test suite passed with return code 0.

---

## Milestone 3: Low-Poly Arena & Blender MCP Pipeline [COMPLETED]
- [x] **Task 3.1**: Model low-poly arena environment in Blender via MCP (octagonal colosseum, stone floor, 8 walls, 8 corner pillars, 920 tris).
- [x] **Task 3.2**: Export arena as `.glb` to `res://assets/models/arena.glb` (glTF 2.0 binary, +Y Up, materials preserved).
- [x] **Task 3.3**: Create `Arena.tscn` in Godot with static collisions (Layer 1 floor & 8 perimeter wall boxes), directional light, environment, and entity spawns.
- [x] **Verification Gate**: Viewport screenshot in Blender + headless scene check in Godot passed + manual ratio test confirmed.

---

## Milestone 4: Low-Poly Character, Combat Animations & Camera Overhaul [IN PROGRESS]
- [x] **Task 4.1**: Model low-poly Roman gladiator in Blender (420 vertices, flat-shaded, sword in right hand, shield on left forearm).
- [x] **Task 4.2**: Humanoid Armature rigging & accurate bone weights assignment (18 bones, zero unintended vertex deformation).
- [x] **Task 4.3**: Integrate `player_character.glb` with `Player.tscn` and `PlayerController.gd`.
- [x] **Phase 1: FPS Camera Overhaul & 360° Zero-Drift Verification**:
  - Centered CameraPivot at `(0, 1.62, 0)` collinear with spine.
  - Eliminated 22 cm eccentric orbit drift across 360° yaw (measured horizontal drift: `0.0000 m`).
  - FPS near clipping (`near = 0.08`), head/neck scaled down to `0.0001` in FPS and restored in TPS.
  - Synchronized melee attack aim with camera pitch and yaw in FPS.
- [x] **Phase 2: Attack Animation & Damage Timing Synchronization**:
  - Redesigned 3-phase melee attack in Blender (Wind-Up -> Slash Apex -> Recovery, 18 frames / 0.75s).
  - Standardized XYZ bone rotation mode and keyframed articulated wrist `hand.R` and shoulder/core mechanics.
  - Synchronized damage at swing apex ($t = 0.35\text{s}$) with single-hit guarantee (`_damage_applied_this_swing`).
  - Verified no premature damage during wind-up, out-of-range miss, and directional check against TrainingDummy.
  - Verified visual slash cue and dummy hit reactions in both FPS and TPS modes.
- [x] **Phase 3: Shield Block Animation & Directional Defense Logic**:
  - Keyframed dedicated shield defense animations in Blender: `block_start` (0.208s), `block_hold` (0.417s loopable), `block_release` (0.208s), and unified `block`.
  - Exported and imported into `player_character.glb` with clean XYZ bone rotation and baked tracks.
  - Implemented RMB input state machine: Press -> `block_start`, Hold -> `block_hold` (looping without restart every frame), Release -> `block_release` -> `idle`.
  - Enforced mutual exclusion preventing simultaneous Attack and Block states.
  - Implemented 120° directional defense cone vector calculation in `PlayerCombat.gd`.
  - Configured `block_damage_reduction = 0.85` (85% damage mitigation on frontal block).
  - Executed automated 10-test validation suite (`run_phase3_runtime_test.gd`) with 10/10 tests passing on GPU runtime.
- [x] **Phase 4: Combat FSM Matrix (IDLE, RUN, ATTACK, BLOCK, DEAD)** [COMPLETED]:
  - Modeled and keyframed non-looping `dead` action in Blender (monotonic collapse to ground, physically grounded, limbs resting at $Z \ge 0.0$m).
  - Implemented centralized `enum CombatState { IDLE, RUN, ATTACK, BLOCK, DEAD }` with transitions, guards, and mutually exclusive property getters in `PlayerController.gd`.
  - Integrated `HealthComponent` into `Player.tscn` with terminal death prioritization when $\text{HP} \le 0$.
  - Enforced death lock: zero horizontal velocity, input lockout (movement, attack, block disabled), cancellation of active attacks/blocks, terminal dead state without idle reset.
  - Implemented 18 automated tests in `run_phase4_fsm_runtime_test.gd` with 18/18 passing on GPU runtime.
  - Verified zero regressions on Phase 1, Phase 2, and Phase 3 suites.
- [x] **Bug Fix: RMB Block Stuck / Character Freezes**:
  - Eliminated duplicate RMB handling across `InputEventMouseButton` and `block` action.
  - Established single source of truth via InputMap `block` and `attack`.
  - Verified and secured `_block_transition` lifecycle: `start` -> `holding` -> `releasing` -> `""`.
  - Created runtime test `run_rmb_lifecycle_test.gd` verifying RMB press/hold/release, 45% speed, locomotion recovery, and re-entry (11/11 tests PASS).
  - Executed full Phase 1-4 regression suite with 0 regressions.
- [ ] **Phase 5: Gameplay Polish & Visual Verification Gate** [IN PROGRESS]:
  - [x] **Task 5.1: Stylized Sword Slash Arc Ribbon VFX**:
    - Created procedural `SlashArcVFX.gd` generating a dynamic $120^\circ$ crescent ribbon mesh (radius $1.05\,\text{m}$, width $0.14\,\text{m}$, 48 tris).
    - Unshaded, two-sided, vertex-colored alpha material with bright white cutting edge and golden trail.
    - Synchronized with exact `forward_dir` and player origin derived during attack apex impact ($t=0.35\,\text{s}$).
    - Rapid expansion scale tween ($0.06\,\text{s}$), dynamic cut sweep rotation, smooth transparency fade ($0.15\,\text{s}$ total).
    - Stale tween cleanup and persistent node instance to prevent leak/accumulation.
    - Verified with 10-test suite `run_task5_1_slash_arc_test.gd` (10/10 PASS) and 0 regressions across Phase 1–4 suites.
  - [x] **Task 5.2: Stylized Hit Impact Spark VFX**:
    - Identified exact damage confirmation point in `PlayerCombat.gd` (`_perform_attack()` right after damage dispatch and `hit_landed.emit()`).
    - Created reusable procedural `HitImpactVFX.gd` and scene `HitImpactVFX.tscn`:
      - 4-pointed diamond star core flash (8 tris, white core to golden tip) with rapid pop (0.05s) and fade (0.08s).
      - 7 radial low-poly diamond spark shards (14 tris, total 22 tris) with radial burst (0.12s) and alpha fade (0.10s).
      - Unshaded, two-sided, vertex-colored alpha blending matching the warm-golden low-poly aesthetic.
      - Lightweight and zero-texture (procedural `ImmediateMesh`), zero child node accumulation.
    - Instantiated under `PlayerCombat` and safely triggered at exact target contact boundary (`target_pos - hit_dir * min(0.35, dist * 0.5)`).
    - Zero VFX triggered on miss or out-of-range swings.
    - Validated in both FPS and TPS camera modes.
    - Tested with 10-test suite `run_task5_2_hit_impact_test.gd` (10/10 PASS).
    - Zero regressions across Phase 1, Phase 2, Phase 3, Phase 4, RMB lifecycle, and Task 5.1 test suites.
  - [x] **Task 5.3: Stylized Block Impact Shield Deflection VFX**:
    - Identified exact confirmed-block path in `PlayerCombat.gd` (`_perform_attack()` where `is_blocked == true` and damage is mitigated by 85%).
    - Created reusable procedural `BlockImpactVFX.gd` and scene `BlockImpactVFX.tscn`:
      - 6-pointed hexagonal barrier star flash (12 tris, crisp white-cyan core to electric cyan rim) with rapid pop (0.04s) and fade (0.07s).
      - 6 low-poly deflection spark shards (12 tris, total 24 tris) that burst backward toward incoming attacker along `-incoming_direction` (0.11s) and fade (0.08s). Total duration: 0.14s.
      - Visually distinct from warm-gold `HitImpactVFX` by utilizing cyan/steel-blue energetic barrier aesthetic matching `TrainingDummy.block_flash_color`.
      - Single instance reuse with zero node accumulation (clean tween reuse and finish hide).
    - Hooked strictly into confirmed directional block:
      - Frontal block: Block Impact VFX appears at shield/contact point, 85% reduced damage applied, no Hit Impact VFX.
      - Rear attack: Full damage, no Block Impact VFX, Hit Impact VFX triggered on back.
      - Flank attack (outside 120° cone): Full damage, no Block Impact VFX, Hit Impact VFX triggered.
      - Unblocked attack: Full damage, no Block Impact VFX, normal Hit Impact VFX triggered.
    - Supported both Player-as-attacker against blocking targets and Player-as-defender in `PlayerController.take_damage()`.
    - Tested with 10-test suite `run_task5_3_block_impact_test.gd` (10/10 PASS).
    - Zero regressions across Task 5.1, Task 5.2, RMB lifecycle, and Phases 1–4 suites.
  - [x] **Task 5.4: Shield Durability Resource & Combat Integration**:
    - Implemented separate Shield Durability resource (`shield_max_durability = 100.0`, `shield_durability = 100.0`).
    - Added `normal_attack_shield_damage = 15.0` to `PlayerCombat.gd`, extensible for future attack tiers.
    - Added reusable shield durability API with `apply_shield_damage(amount: float)` (clamping at 0.0 without going negative) and `reset_shield_durability()` in both `PlayerController.gd` and `TrainingDummy.gd`.
    - Emits signal `shield_durability_changed(current: float, maximum: float)`.
    - Integrated with confirmed directional block:
      - Blocked attack: defender HP takes exactly 3.75 damage (85% reduction), shield durability loses exactly 15.0. Shield damage is completely independent of HP damage calculation.
      - Repeated blocks cleanly step: 100 -> 85 -> 70 -> 55 -> 40 -> 25 -> 10 -> 0.
      - Durability clamps strictly at 0.0. Shield Break is NOT implemented yet (reserved for Task 5.5); blocking is not disabled at 0 durability and no stun/stagger is added.
      - Unblocked / Rear / Flank attacks: full HP damage (25.0), shield durability does NOT decrease.
      - Existing visual FX (Block Impact VFX on block, Hit Impact VFX on unblocked) remain 100% functional.
    - Verified in both FPS and TPS camera modes.
    - Tested with 15-test suite `run_task5_4_shield_durability_test.gd` (15/15 PASS).
    - Zero regressions across Task 5.1, Task 5.2, Task 5.3, RMB lifecycle, and Phases 1–4 suites.
  - [x] **Combat Testing Tool Upgrade: Resettable Training Dummy & Attack Training Dummy**:
    - **Part 1 (Resettable Training Dummy)**:
      - Added `@export var auto_reset_on_death: bool = true` and `@export var reset_delay: float = 1.0` to `TrainingDummy.gd`.
      - On death, schedules non-duplicating reset timer that restores full HP, clears dead state, updates health bar, resets shield durability, and restores material color without altering position.
      - Added public API `reset_dummy()` for instant test resets.
      - Added `reset_health()` to `HealthComponent.gd`.
    - **Part 2 (Attack Training Dummy)**:
      - Created `scripts/AttackTrainingDummy.gd` and `scenes/AttackTrainingDummy.tscn`.
      - Stands completely still (strictly static position, zero chase/movement drift).
      - Has zero health bar, zero health components, zero UI.
      - Periodically executes basic melee attack cycle: 1.0s spawn delay -> Wait (2.0s) -> Wind-up (0.35s) -> Impact (25.0 damage in 2.2m frontal cone) -> Recovery (0.75s).
      - Debug key controls: F6 (force attack now), F7 (toggle auto attack).
      - Created dedicated test arena: `scenes/CombatTestArena.tscn` (Player + Side Training Dummy + Frontal Attack Dummy).
      - Tested with 17-test suite `run_training_dummy_test.gd` (17/17 PASS).
      - Zero regressions across Task 5.1, Task 5.2, Task 5.3, Task 5.4, RMB lifecycle, and Phases 1–4 suites.
  - [x] **Task 5.5: Shield Break, Stagger Stun & Recovery System**:
    - Dedicated Shield State machine in `PlayerController.gd`: `enum ShieldState { READY, BROKEN }`.
    - Integrated Shield Break trigger when shield durability transitions $> 0 \to 0$ upon a confirmed block:
      - Final incoming attack reducing durability to 0 resolves normally as a successful block (3.75 HP damage, Block Impact VFX triggers).
      - Immediately enters `SHIELD_BROKEN` state.
      - Emits `shield_broken()`.
      - Forces player out of `CombatState.BLOCK` to `CombatState.IDLE`.
      - Applies stagger stun (`shield_break_stun_duration: float = 1.0`): halts horizontal movement and locks jump/block.
      - During broken and recovery state: RMB/block requests strictly rejected, shield durability stays 0.0, incoming attacks deal full damage (25.0) with zero Block Impact VFX.
      - After `shield_recovery_delay: float = 2.0`, shield automatically restores to `shield_max_durability` (100.0), broken state clears, and `shield_restored()` is emitted.
      - Player can block normally again after recovery.
    - Created procedural `ShieldBreakVFX.gd` and scene `ShieldBreakVFX.tscn`:
      - 8-pointed star burst flash (16 tris, pure white core).
      - Expanding fractured shockwave ring (32 tris, electric blue/violet).
      - 12 3D crystalline shield shards (24 tris) violently erupting outward and spinning with radial dispersion.
      - Total duration ~0.32s; unshaded, vertex-colored alpha blending; single instance reuse with zero node accumulation.
    - Updated `TrainingDummy.gd` with matching broken state, break detection, and recovery.
    - Created acceptance test suite `run_task5_5_shield_break_test.gd` covering all 18 acceptance tests (18/18 PASS).
    - Updated `run_task5_4_shield_durability_test.gd` Test 14 to reflect the new Task 5.5 contract (15/15 PASS).
    - Zero regressions across Task 5.4 (15/15), Task 5.3 (10/10), Task 5.2 (10/10), Task 5.1 (10/10), RMB lifecycle (15/15), Phase 4 FSM (18/18), Phase 3 (10/10), Phase 2, Phase 1, and Training Dummy tests.
  - [x] **Task 5.6A: Combat Test Arena UX, Shield Feedback & Player Respawn**:
    - **Part A (One-Hit Death Diagnosis)**:
      - Traced damage pipeline: `AttackTrainingDummy` -> `impact_time (0.35s)` -> `_apply_damage()` -> `PlayerController.take_damage()` -> `HealthComponent.take_damage()`.
      - Measured Player max HP: `100.0`.
      - Measured Dummy damage: `25.0` per swing.
      - Confirmed single application per swing (no duplicate damage calls).
      - Identified root cause of perceived "one-hit death": Absence of in-game Player HP/Shield HUD, lack of unblocked hit feedback VFX on player, and absence of clear Shield Break banner led to silent accumulation of damage until sudden death.
    - **Part B (Combat Test Arena Respawn System)**:
      - Added test-arena-only respawn system in `CombatTestArena.gd` (`scenes/CombatTestArena.tscn`).
      - On player death, preserves death animation, waits ~1.5 seconds, then cleanly revives the exact same player instance via `PlayerController.respawn()`.
      - Restores HP to 100, shield to 100, clears stun/block/attack, resets velocity, resets FSM to IDLE, and moves player back to original spawn transform. Zero node duplication.
    - **Part C & D (Combat Test Arena HUD & Shield Break Banner)**:
      - Created lightweight `CombatTestHUD.gd` and `scenes/CombatTestHUD.tscn`.
      - Displays Player HP bar (green), Shield Durability bar (cyan), and Shield status label (`READY` in cyan, `BROKEN` in red with live recovery countdown `Recovering... X.Xs`).
      - Centered high-contrast `SHIELD BROKEN` alert banner pulsing on the exact transition from $>0 \to 0$ durability, auto-fading after ~1.2s without repeat spam.
      - Connected `PlayerController.take_damage()` to `PlayerCombat.trigger_hit_impact()` so incoming damage produces visual hit sparks on player.
    - **Part E (Attack Training Dummy Verification)**:
      - Verified stationary position, ~2.0s auto-attack interval, F6 manual trigger, F7 auto toggle, and single-hit impact timing.
    - **Part F & Regression**:
      - Created 24-test acceptance test suite `run_task5_6_combat_test_arena_test.gd` (24/24 PASS).
      - Ran full 12-suite regression: Task 5.6A (24/24), Task 5.5 (18/18), Task 5.4 (15/15), Task 5.3 (10/10), Task 5.2 (10/10), Task 5.1 (10/10), RMB lifecycle (15/15), Phase 4 FSM (18/18), Phase 3 (10/10), Phase 2 (5/5), Phase 1 (4/4), Training Dummy (17/17) - ALL PASSED.
      - Confirmed zero Git commits or pushes executed.
  - [x] **Task 5.7: Hit Reaction, Knockback & Combat Feel**:
    - **Normal Hit Reaction**:
      - Lightweight procedural recoil on both TrainingDummy (`_apply_dummy_reaction`) and PlayerController (`apply_hit_reaction`).
      - Visual flinch with tilt (~12° unblocked, ~4° blocked) and spring-back tween lasting ~0.15s (`hit_reaction_duration`).
      - In first-person mode, adds subtle pitch kick (`_cam_recoil_pitch`).
      - Target automatically returns to baseline locomotion/combat state without interrupting the attacker or desynchronizing FSM.
    - **Small Directional Knockback**:
      - Horizontal XZ directional displacement (`hit_knockback_distance = 0.40m`, duration `0.10s`).
      - Strictly zero vertical launch (`delta.y == 0.0`).
      - Halted immediately upon expiration to eliminate friction overshoot; does not accumulate into infinite velocity when spammed.
      - Disables FSM transition to RUN while knockback impulse is active.
      - Zeroed on character death and respawn.
    - **Block Defensive Recoil**:
      - Added small defensive recoil (`block_recoil_distance = 0.08m`, duration `0.08s`) on successful frontal block.
      - Preserves full player control over RMB block hold lifecycle, 85% damage reduction, and 15 shield durability damage.
    - **Shield Break Stagger & Feedback**:
      - Stronger stagger recoil impulse (0.45m over 0.12s) and 2.0x camera pitch feedback.
      - Retains exact 1.0s stun, 2.0s recovery delay, RMB rejection while broken, and ShieldBreakVFX.
    - **Hit-Stop Safety**:
      - As permitted by Section 6, hit-stop is safely bypassed (`hit_stop_duration = 0.0`) to strictly avoid global pause locks (breaking timers/shield recovery/VFX) or animation scaling desynchronization (breaking the strict 0.35s impact timing constraint).
    - **Miss & Death Priorities**:
      - Misses and out-of-range attacks trigger zero hit reactions and zero knockback.
      - Death takes terminal priority over hit reactions; disables knockback and cancels active impulses.
    - **Acceptance & Regression Testing**:
      - Created dedicated 22-test acceptance suite `run_task5_7_hit_reaction_test.gd` (22/22 PASS).
      - Full 13-suite regression: 168 / 168 tests passed (0 failures).
      - Strictly zero Git commits or pushes executed.
  - [x] **Task 5.8: Combat Feedback & Target Feedback**:
    - **Floating Damage Numbers**:
      - Created `DamageNumberVFX.gd` and `scenes/DamageNumberVFX.tscn` using `Label3D` with `billboard = BILLBOARD_FIXED_Y` and `no_depth_test = true` for high visibility across FPS and TPS.
      - Displays actual damage dealt at confirmed contact position: unblocked hit displays gold `25`, blocked hit displays light cyan `3.75`.
      - Displays shield damage feedback as a distinct subtitle label `Shield -15` without changing or contaminating the HP damage calculation.
      - Floats upward smoothly (~0.5m) and fades out over ~0.65s lifetime before recycling.
    - **Instance Pooling & Memory Stability**:
      - Created `DamageNumberPool.gd` and `scenes/DamageNumberPool.tscn` with 8 pre-allocated pooled instances under `PlayerCombat`.
      - Recycles inactive instances and round-robin reuses oldest when saturated, strictly preventing permanent node accumulation or memory leaks.
    - **Low-Shield Feedback**:
      - Implemented `is_low_shield` detection and `low_shield_warning_changed` signal in `PlayerController.gd` at `<= 25%` threshold (`<= 25.0` durability).
      - Added static warning label `LowShieldWarning` in `scenes/CombatTestHUD.tscn` without spawning duplicate nodes.
      - Low-shield warning auto-clears on shield break (superseded by authoritative `SHIELD BROKEN` state) and upon shield restoration/respawn.
    - **Combat Invariants Preserved**:
      - Normal damage = 25.0, Block reduction = 85% (damage = 3.75), Shield damage = 15.0, Shield max = 100.0, Attack impact = 0.35s, Block cone = 120°, Dummy range = 2.2m.
    - **Acceptance & Regression Testing**:
      - Created dedicated 24-test acceptance suite `run_task5_8_combat_feedback_test.gd` (24/24 PASS).
      - Full regression across all 14 previous suites: 168 / 168 PASS.
      - Grand total: 192 / 192 PASS.
  - [x] **Task 5.9: Attack Telegraph & Impact Readability**:
    - **Attack Telegraph Component**:
      - Created `scripts/AttackTelegraphVFX.gd` and `scenes/AttackTelegraphVFX.tscn` using a procedural low-poly sector fan mesh (60° arc, 2.2m radius) with an unshaded alpha-blended material, inner gradient fill, outer rim outline, and central directional arrow.
      - Opacity ramps smoothly from 0.35 to 1.0 during wind-up (0.0s to 0.35s) and cleanly terminates at impact.
      - Authoritative tracking: continuously follows `source_node` in `_process()`, strictly preventing telegraph from lagging behind a moving character.
    - **Authoritative Attack Direction**:
      - Reuses the combat system's authoritative attack direction (`dummy_fwd` for `AttackTrainingDummy`, camera forward projected onto XZ for player).
      - Fully consistent in FPS and TPS modes without secondary or duplicate directional calculations.
    - **Integration with AttackTrainingDummy**:
      - Telegraph starts at the exact start of `_execute_attack_sequence()`.
      - Automatically extinguished at `_apply_attack_impact()` (0.35s) and `_finish_attack_sequence()`.
      - Extinguished immediately if attack is cancelled via `cancel_attack()`, misses, or target is out of range.
      - AttackTrainingDummy remains strictly stationary.
    - **Integration with Player**:
      - Wired into `PlayerCombat.gd` (`trigger_attack_telegraph`) and triggered in `PlayerController.gd` during the wind-up phase of `CombatState.ATTACK`.
      - Automatically cancelled if player dies, resets, or completes attack.
    - **Node Stability & Zero Accumulation**:
      - Bounded architecture: exactly one reusable telegraph instance per attacker (child of `AttackTrainingDummy` and `PlayerCombat`).
      - Repeated attacks do not create new nodes or leak memory.
    - **Combat Invariants Preserved**:
      - Normal damage = 25.0, Block reduction = 85% (damage = 3.75), Shield damage = 15.0, Shield max = 100.0, Attack impact = 0.35s, Block cone = 120°, Dummy range = 2.2m.
      - Zero early damage before 0.35s; zero duplicate damage; all existing VFX (Slash Arc, Hit Impact, Block Impact, Damage Numbers) intact.
    - **Acceptance & Regression Testing**:
      - Created dedicated 24-test acceptance suite `run_task5_9_attack_telegraph_test.gd` (24/24 PASS).
      - Full regression across all 15 previous test suites: 192 / 192 PASS.
      - Grand total: 216 / 216 PASS (233 / 233 individual assertions passed across all 16 suites).
  - [x] **Task 5.10: Shield Lifecycle (Test Arena vs Real Match)**:
    - **Shield Recovery Mode Policy / Context**:
      - Defined explicit `ShieldRecoveryMode` enum (`TEST_ARENA`, `MATCH`) and exported `shield_recovery_mode` on `PlayerController.gd`.
      - `CombatTestArena.gd` explicitly configures `player.shield_recovery_mode = PlayerController.ShieldRecoveryMode.TEST_ARENA` in `_ready()`.
      - Future match configurations can cleanly set `ShieldRecoveryMode.MATCH` without hard-coding scene names or guessing context.
    - **Context-Dependent Recovery Behavior**:
      - **TEST_ARENA**: Retains existing prototype recovery where shield break causes 1.0s stun, followed by 2.0s recovery delay, restoring durability to 100 and state to `READY`.
      - **MATCH**: Automatic recovery is strictly disabled. When shield durability reaches 0, shield transitions to `BROKEN` and permanently remains `BROKEN` for the rest of the life/round. RMB blocks are rejected, attacks deal full 25 damage without block impact VFX, and no timer restores durability until an explicit new-life/new-round reset.
    - **Explicit Reset & Respawn Contract**:
      - Created authoritative `reset_shield_for_new_round()` API on `PlayerController.gd`.
      - Resets durability to 100, state to `READY`, clears stun and recovery timers, zeroes knockback impulses, updates/clears low-shield warnings, and emits `shield_restored`.
      - `reset_shield_durability()` routes directly to `reset_shield_for_new_round()` for seamless backwards compatibility.
      - `PlayerController.respawn()` leverages `reset_shield_for_new_round()` as the single source of truth for new-life reset without creating duplicate Player nodes.
    - **Combat Invariants Preserved**:
      - Normal damage = 25.0, Block reduction = 85% (damage = 3.75), Shield damage = 15.0, Shield max = 100.0, Attack impact = 0.35s, Block cone = 120°, Dummy range = 2.2m.
      - Knockback (0.40m), block recoil (0.08m), shield break stun (1.0s), and all VFX intact.
    - **Acceptance & Regression Testing**:
      - Created dedicated 35-test acceptance suite `run_task5_10_shield_lifecycle_test.gd` (35/35 PASS).
      - Full regression across all 16 previous test suites: 216 / 216 PASS.
      - Grand total: 251 / 251 PASS (268 individual assertions passed across all 17 suites).
      - Strictly zero Git commits or pushes executed.
  - [x] **Task 5.11: Combat Feedback Polish (Hit/Miss, Block, Shield Break Presentation)**:
    - **Hit Camera Feedback (Zero Drift)**:
      - Additive, temporary pitch recoil on camera pivot (`_cam_recoil_pitch`).
      - Normal Hit: subtle downward kick (-0.025 rad / ~1.4°), smooth tween return in 0.12s.
      - Blocked Hit: smaller reaction (-0.012 rad / ~0.7°), smooth return in 0.08s.
      - Shield Break: readable impact kick (-0.055 rad / ~3.1°), smooth return in 0.22s.
      - Zero drift: resets to exactly 0.0 rad, strictly zero cumulative angular drift across repeated hits, blocks, and shield breaks.
    - **Crosshair / Target Detection Feedback**:
      - Added procedural screen-space centered crosshair (`scripts/Crosshair.gd`, `scenes/CombatFeedback.tscn`).
      - Centered in both FPS and TPS (`is_centered()` returns true, anchored at center).
      - Visual-only: does not modify aiming, attack direction, rotation, or auto-lock.
      - Reuses combat detection logic (`PlayerCombat.get_valid_target_in_range()`) without duplicate geometry calculations.
      - Dynamically highlights (red diamond pips + reticle pulse) when a valid target is in range and facing arc; returns to normal subtle state when no target is present.
    - **Target Hit Flash & Feedback**:
      - Triggers brief visual highlight on target (`is_flashing_hit`) ONLY after confirmed damage.
      - Misses and out-of-range attacks produce zero target flash.
      - Blocked attacks do NOT trigger normal hit flash (shield absorbs blow; BlockImpactVFX remains authoritative).
      - Shield break triggers authoritative ShieldBreakVFX without material corruption.
      - Zero permanent material changes, zero node leaks, zero duplicate instances.
    - **Block & Shield Break Feedback**:
      - Blocked attacks retain 3.75 HP damage, 15 shield damage, 120° block cone, and Block Impact VFX with subtle camera recoil.
      - Shield Break retains 1.0s stun, stronger stagger, and ShieldBreakVFX, enhanced with subtle camera kick and temporary screen emphasis.
    - **Miss Feedback**:
      - Misses produce zero damage numbers, zero hit impact VFX, zero target knockback, and zero target hit reaction.
    - **Lightweight Audio Hooks**:
      - Implemented placeholder architecture: `audio_attack_started`, `audio_attack_hit`, `audio_attack_blocked`, `audio_shield_break`, and `audio_death`.
      - Integrated silent `AudioStreamPlayer` nodes in `scenes/CombatFeedback.tscn` without downloading external files or creating low-quality placeholder noise.
    - **FPS & TPS Compatibility**:
      - Every feedback element verified in both First-Person and Third-Person modes.
    - **Combat Invariants Preserved**:
      - Normal damage = 25.0, Block reduction = 85% (damage = 3.75), Shield damage = 15.0, Shield max = 100.0, Attack impact = 0.35s, Block cone = 120°, Knockback = 0.40m, Block recoil = 0.08m, Dummy range = 2.2m.
    - **Acceptance & Regression Testing**:
      - Created dedicated 46-test acceptance suite `run_task5_11_combat_feedback_test.gd` (46/46 PASS).
      - Full regression across all 18 test suites: 297 / 297 PASS.
      - `git diff --check` strictly CLEAN.
      - Strictly zero Git commits or pushes executed.
  - [x] **Task 5.12: Centered TPS Combat Camera & Shift Sprint (Revision)**:
    - **Centered Always-On TPS Combat Camera**:
      - TPS camera is always in combat orientation: player stays visually centered on screen without over-the-shoulder offset (`h_offset = 0.0`, `v_offset = 0.0`).
      - Core camera pivot strictly preserved at `(0, 1.62, 0)` collinear with spine, maintaining Phase 1 zero-drift architecture.
      - Mouse look controls horizontal camera yaw and vertical pitch (`-75°` to `+60°`).
      - Player horizontal yaw follows camera yaw (`visuals.rotation.y = _camera_yaw`).
      - Camera pitch affects camera pivot only; player stays strictly upright (`visuals.rotation.x = 0.0`, `rotation.x = 0.0`, `rotation.z = 0.0`).
    - **Camera-Relative Movement & Strafing**:
      - WASD movement is camera-relative: W forward, S backward, A/D strafe.
      - Player continuously faces forward along camera yaw while moving or standing.
    - **Shift Sprint**:
      - Shift key operates as Sprint only (no Combat Lock toggle).
      - Reuses existing sprint system: holding Shift increases movement speed to `sprint_speed` (10.5); releasing restores `walk_speed` (6.0).
    - **Combat Actions & VFX Compatibility**:
      - Melee attacks, directional blocks, and VFX (Slash Arc, Hit Impact, Block Impact) align with camera forward.
      - Attacks deal normal 25 damage; blocks retain 120° cone, 85% mitigation, and shield durability rules.
    - **FPS Isolation & Lifecycle Safety**:
      - FPS camera remains completely unchanged (`camera.position = (0, 0, 0)`, `near = 0.08`, `h_offset = 0.0`).
      - Perspective toggling (`KEY_V`) transitions cleanly between FPS and centered TPS without camera drift.
      - Death and respawn maintain centered camera.
    - **Acceptance & Regression Testing**:
      - Created dedicated acceptance suite `run_task5_12_shift_lock_test.gd` (40/40 PASS).
      - Full regression across all 19 test suites: 352 / 352 PASS.
      - `git diff --check` strictly CLEAN.
      - Strictly zero Git commits or pushes executed.
  - [x] **Task 5.13: Remove Crosshair**:
    - **Crosshair Complete Removal**:
      - Deleted `scripts/Crosshair.gd`.
      - Removed `Crosshair` Control node and script reference from `scenes/CombatFeedback.tscn`.
      - Removed crosshair property, update calls, and `is_crosshair_centered()` from `scripts/CombatFeedback.gd`.
      - Removed crosshair-only assertions and tests from `run_task5_11_combat_feedback_test.gd` and `run_task5_12_shift_lock_test.gd`.
      - Preserved all other feedback systems completely unchanged: camera recoil, hit flash, block feedback, shield-break feedback, damage numbers, attack telegraph, screen emphasis, audio signals, combat FSM, centered TPS camera, Shift sprint, and FPS/TPS behaviors.
    - **Acceptance & Regression Testing**:
      - Updated Task 5.11 acceptance test suite (`run_task5_11_combat_feedback_test.gd`): 44 / 44 PASS.
      - Updated Task 5.12 acceptance test suite (`run_task5_12_shift_lock_test.gd`): 40 / 40 PASS.
      - Full regression across all test suites: 352 / 352 PASS.
      - `git diff --check` strictly CLEAN.
      - Strictly zero Git commits or pushes executed.
  - [x] **Task 5.14: 3-Hit Attack Combo System** [COMPLETED / ACCEPTED]:
    - **Combo Chaining Sequence**:
      - Implemented 3-hit attack combo (`_combo_step`: 0 -> 1 -> 2 -> 3) in `PlayerController.gd`.
      - Each swing deals 25.0 damage (total 75.0 damage for complete 3-hit combo against training dummy).
      - Reuses 18-frame melee attack animation with apex damage at $t = 0.35$s.
      - Integrated with combat FSM: preserves `CombatState.ATTACK` across chain transitions without dropping to locomotion prematurely.
    - **Combo Window & Transition Timing**:
      - Defined combo window `COMBO_WINDOW_START = 0.35` and `COMBO_WINDOW_END = 0.70`.
      - `is_in_combo_window()` evaluates active swing position.
      - If no follow-up attack is triggered within `combo_recovery_timeout = 0.25s` after swing finishes, combo resets cleanly to step 0.
    - **Defensive & Combat Invariants**:
      - RMB block cancels combo on press; mid-swing blocking remains rejected during active strike.
      - Directional block cone (120°), 85% mitigation (3.75 HP damage), shield durability (-15 per hit) work seamlessly across all combo steps.
      - VFX (Telegraph fan, Slash Arc ribbon, Hit Impact sparks, Block Impact deflection, Damage Numbers) trigger reliably on each respective strike.
      - Death, respawn, and shield break immediately reset active combo state.
      - Both FPS and centered TPS modes support 3-hit combo identically.
    - **Acceptance Testing**:
      - Verified with `run_task5_14_attack_combo_test.gd`: 14 / 14 PASS.
  - [x] **Task 5.14A: Combo Input Buffer** [COMPLETED / ACCEPTED]:
    - **Early Input Buffering**:
      - Implemented `_combo_buffer` and `_combo_queued` state tracking in `PlayerController.gd`.
      - Mouse clicks occurring during attack wind-up ($t < 0.35$s) or recovery are safely queued into the input buffer.
      - Queued inputs execute automatically at the completion of current attack animation (`_on_animation_finished`).
    - **Input Spam Clamping**:
      - Clicking rapidly/spamming LMB cannot exceed `MAX_COMBO_STEP = 3` attacks.
      - Excess clicks beyond 3 are discarded safely without hanging or infinite loops.
    - **Buffer Cleanup Safety**:
      - Buffer is cleared immediately upon character death, hit reaction recoil, shield break, or block engagement.
    - **Acceptance Testing**:
      - Verified with `run_task5_14a_combo_buffer_test.gd`: 14 / 14 PASS.
  - [x] **Task 5.14C: Combo Finisher Recovery Pause** [COMPLETED / ACCEPTED]:
    - **Finisher Recovery Lockdown**:
      - Defined `COMBO_FINISHER_RECOVERY = 0.8` seconds in `PlayerController.gd`.
      - Upon completing the 3rd attack (Finisher), `_combo_finisher_recovery_timer` is set to 0.8s.
      - During this 0.8s window, both LMB attack and RMB block requests are strictly rejected (`can_attack()` and `_start_block()` return false).
    - **Anti-Bypass Hardening**:
      - Finisher recovery pause timer cannot be bypassed or cleared by hit reaction or shield break (`reset_combo(false)` preserves finisher recovery timer).
      - Death and respawn cleanly reset finisher pause.
      - Once the 0.8s timer expires, normal locomotion and combat inputs (LMB attack, RMB block) resume seamlessly.
      - 1-hit and 2-hit attacks do not trigger finisher recovery (normal 0.25s combo reset timeout applies).
    - **Acceptance Testing**:
      - Verified with `run_task5_14c_combo_finisher_recovery_test.gd`: 9 / 9 PASS.
