# Project Context

## Game Vision
- A **fast‑paced 3‑D arena combat** experience where players control a low‑poly Roman‑style fighter with a sword and shield.
- Emphasis on **responsive melee combat**, **combo depth**, and **tight feel**.
- Designed for **single‑player practice** and **local multiplayer** (future expansion).

## Core Pillars
1. **Gameplay Clarity** – Clear hit feedback, predictable damage windows, and visible combo counters.
2. **Performance‑First** – Low‑poly assets (< 3000 tris per character) and efficient Godot scripts to run on modest Windows PCs.
3. **Iterative Polish** – A regression test suite ensures new changes never break existing combat mechanics.

## Technical Scope (as of 2026‑10‑01)
- **Engine**: Godot 4.3, GDScript 2.0.
- **Art Pipeline**: Blender 5.2 assets exported via the **Blender MCP** integration.
- **Combat Architecture**: Composition of `Hitbox3D`, `Hurtbox3D`, `HealthComponent` with a central `StateMachine`.
- **Current Feature Set**:
  - 3‑hit combo system with input buffering and finisher‑recovery pause.
  - Shield block with directional cone protection.
  - Basic movement, **centered TPS camera** configuration.
  - Combat HUD, low‑shield warning, and training dummies.
- **Testing**: 22 automated GDScript test scripts covering combat phases, FSM, and block lifecycle.

## Multiplayer
- Multiplayer is **not implemented**. It is not part of the current gameplay architecture and remains a possible future direction only.

## Shield Recovery Mode
- Two modes are supported in the current implementation:
  - `TEST_ARENA` – used for the CombatTestArena testing scene.
  - `MATCH` – used during normal match gameplay.
- No `MatchManager` or related multiplayer systems exist.

## Low‑Shield Warning System
- Variables:
  - `low_shield_threshold` – the shield value at which the warning activates.
  - `low_shield_warning_changed` – flag indicating the warning state has changed and UI should update.
- The system currently only triggers a UI warning; no additional gameplay effects are implemented.

## UI Notes
- **Task 5.13** removed the crosshair. The current combat UI must **not** assume a crosshair exists.

---
*Generated automatically by Antigravity on 2026‑10‑01.*
