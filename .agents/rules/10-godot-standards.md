---
description: Godot 4.3 and GDScript 2.0 coding and architecture standards
trigger: always_on
---

# Godot 4.3 & GDScript Standards

1. **Static Typing Mandatory**:
   - Every variable, parameter, and function return type must be explicitly typed.
   - Example:
     ```gdscript
     var current_health: float = 100.0
     var velocity_target: Vector3 = Vector3.ZERO
     func take_damage(amount: float, source: Node3D) -> bool:
     ```
   - Avoid untyped `Variant` unless interfacing with dynamic dictionaries.

2. **Node Architecture for 3D Combat Arena**:
   - **Root entity**: `CharacterBody3D` for player and combatants.
   - **Collision**: `CollisionShape3D` capsule or cylinder.
   - **Visuals**: Child `Node3D` (e.g. `Visuals` or `ModelRoot`) decoupled from root physics orientation.
   - **Hitbox / Hurtbox Component Pattern**:
     - `Hitbox3D` (`Area3D`): Active attack volume that transmits damage data.
     - `Hurtbox3D` (`Area3D`): Receiver volume that takes damage and triggers hit reactions.
   - Use collision layers and masks strictly defined in project settings.

3. **Performance & Memory (4GB VRAM Budget)**:
   - Zero per-frame allocations inside `_physics_process(delta: float)`. Do not instantiate nodes or arrays in tight loops.
   - Cache node references with `@onready` instead of repeating `get_node()` or `$` inside loops.
   - Prefer custom `State` classes or an explicit Finite State Machine (FSM) over massive `match` statements in a single file.

4. **GDScript Style Conventions**:
   - Class names: `PascalCase` (`class_name Combatant3D`)
   - Functions & variables: `snake_case` (`func calculate_knockback()`)
   - Constants: `SCREAMING_SNAKE_CASE` (`const MAX_COMBO_COUNT: int = 3`)
   - Private methods/vars: prefix with underscore (`var _is_invulnerable: bool = false`)
