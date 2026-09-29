---
name: godot4-game-dev
description: Specialized workflows, patterns, and best practices for developing 3D arena combat games in Godot 4.3 using GDScript 2.0.
---

# Godot 4.3 Game Development Skill

## Overview
This skill guides the implementation of 3D game systems in Godot 4.3, specifically focusing on a 3rd-person arena combat game.

## Key Architectures

### 1. 3D Combat Entity Pattern
Each combatant (Player, Enemy) follows a modular node layout:
- `CharacterBody3D` (Root, physics collision)
  - `CollisionShape3D` (Capsule for body physics)
  - `Visuals` (`Node3D`, holds exported `.glb` mesh, rotates smoothly towards velocity)
  - `CameraPivot` (`Node3D` on player, handles yaw/pitch spring arm)
    - `SpringArm3D`
      - `Camera3D`
  - `StateMachine` (`Node`, manages states: Idle, Move, Attack, Hurt, Dead)
  - `Hurtbox3D` (`Area3D`, layer: Hurtbox, mask: 0)
    - `CollisionShape3D`
  - `Hitbox3D` (`Area3D`, layer: 0, mask: Hurtbox)
    - `CollisionShape3D` (Disabled by default, enabled only during attack active frames)

### 2. Finite State Machine (FSM) Template
```gdscript
class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State
var states: Dictionary = {}

func init(actor: CharacterBody3D) -> void:
    for child in get_children():
        if child is State:
            states[child.name.to_lower()] = child
            child.actor = actor
            child.transition_requested.connect(_on_transition_requested)
    if initial_state:
        change_state(initial_state.name.to_lower())

func change_state(new_state_name: String) -> void:
    var target: State = states.get(new_state_name.to_lower())
    if not target or target == current_state:
        return
    if current_state:
        current_state.exit()
    current_state = target
    current_state.enter()
```

### 3. Combat & Hit Registration Protocol
- The `Hitbox3D` holds attack data: `damage: float`, `knockback: Vector3`, `hit_stun: float`.
- When `Hitbox3D` overlaps `Hurtbox3D`, the `Hurtbox3D` emits `damaged(hit_data: Dictionary)`.
- The combatant receives the signal, reduces health, applies knockback, and transitions to `HurtState`.
