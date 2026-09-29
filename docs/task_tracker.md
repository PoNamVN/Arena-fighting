# Task Tracker & Roadmap

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

## Milestone 3: Low-Poly Arena & Blender MCP Pipeline [PENDING]
- [ ] **Task 3.1**: Model low-poly arena environment in Blender via MCP.
- [ ] **Task 3.2**: Export arena as `.glb` to `res://assets/models/arena.glb`.
- [ ] **Task 3.3**: Create `Arena.tscn` in Godot with static collisions and directional light.
- [ ] **Verification Gate**: Viewport screenshot in Blender + headless scene check in Godot.

---

## Milestone 4: Opponent Dummy & Combat Loop [PENDING]
- [ ] **Task 4.1**: Create `EnemyDummy.tscn` with `Hurtbox3D` and `HealthComponent`.
- [ ] **Task 4.2**: Verify hit detection, knockback, and health reduction when attacked.
- [ ] **Task 4.3**: Add basic Floating Damage Text or Health UI bar.
- [ ] **Verification Gate**: Headless check + manual combat playtest.
