# Task Tracker & Roadmap

## Milestone 0: Environment & Workflow Setup
- [x] **Audit environment**: Antigravity, Godot 4.3, Blender 5.2 MCP status verified.
- [x] **Initialize Git repo**: Initialized in `D:\Game 3D\Game_3D` with `.gitignore`.
- [x] **Install Antigravity Rules**: `00-core-discipline`, `10-godot-standards`, `20-blender-lowpoly`, `30-qa-verification`.
- [x] **Install Antigravity Skills**: `godot4-game-dev`, `blender-mcp-pipeline`, `systematic-debugging`, `verification-discipline`.
- [x] **Initialize Documentation**: `gdd_overview.md`, `architecture.md`, `task_tracker.md`.

---

## Milestone 1: Core Player Controller & Third-Person Camera [PENDING]
- [ ] **Task 1.1**: Define standard input actions (`move_left`, `move_right`, `move_forward`, `move_back`, `jump`, `attack`, `dodge`).
- [ ] **Task 1.2**: Create `Player.tscn` with `CharacterBody3D`, collision capsule, and placeholder mesh.
- [ ] **Task 1.3**: Implement Third-Person SpringArm3D Camera with mouse look & smoothing.
- [ ] **Task 1.4**: Implement basic ground movement & jump physics in `PlayerController.gd`.
- [ ] **Verification Gate**: Headless syntax verification & editor test.

---

## Milestone 2: Combat System Architecture [PENDING]
- [ ] **Task 2.1**: Implement `Hitbox3D` and `Hurtbox3D` components with custom collision layers.
- [ ] **Task 2.2**: Implement `HealthComponent` and `HitData` resource/dictionary structure.
- [ ] **Task 2.3**: Build Finite State Machine (`StateMachine.gd`, `State.gd`).
- [ ] **Task 2.4**: Connect basic attack combo logic and hurt response.
- [ ] **Verification Gate**: Headless syntax check and isolated component tests.

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
