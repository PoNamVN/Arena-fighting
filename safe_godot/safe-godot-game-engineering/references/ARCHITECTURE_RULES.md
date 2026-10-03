# Arena-fighting Architecture Rules

## Responsibility map

### PlayerController.gd
Owns/integrates player movement, camera-relative movement, combat state integration, attack/block/dodge/ability state transitions, and runtime ability execution integration. High-risk file. Make minimal patches.

### PlayerCombat / combat layer
Owns/reuses attack impact, damage interaction, hit/block interaction, and combat feedback hooks. Do not duplicate damage logic inside abilities.

### DodgeController.gd
Owns Dash, dodge timing, i-frame state, Perfect Dodge detection, Counter Window, and counter-window consumption.

### StaminaComponent.gd
Owns stamina value, max stamina, spending, gain, reset. Do not duplicate stamina variables in abilities.

### AbilityData.gd
Ability configuration/data. Keep tuning data-driven.

### AbilityAction.gd
Ability lifecycle: STARTUP, ACTIVE, RECOVERY, FINISHED. Tracks phase timer and hit targets where needed. Protect lifecycle transitions.

### AbilitySystem.gd
Shared ability orchestration. Use for Z/X/C/V.

### KnightAbilities.gd
Knight-specific definitions/configuration. Hero-specific tuning belongs here rather than being hardcoded everywhere.

### CombatFeedback.gd
Shared hit reaction, knockback, camera recoil, VFX, damage numbers, telegraph, shield break feedback, audio hooks/placeholders. Do not create duplicate feedback systems.

### TrainingDummy.gd
Owns HP, alive/dead, targetable state, death, respawn, visible world-space HP bar. Do not create another dummy HP system.

### CombatTestArena
Test-only environment. Do not treat test-only dummy behavior as production MatchManager logic.

## State model
Current intended states include IDLE, RUN, ATTACK, BLOCK, DODGE, DEAD, COUNTER. DEAD is terminal until respawn/reset. Abilities should not become generic permanent FSM states without explicit design approval.

## Attack pipeline
Normal attack: wind-up → impact → follow-through/recovery. Damage is applied at the intended impact point. Duplicate-hit guards are required.

## Z architecture
Use AbilityData, AbilityAction, AbilitySystem/KnightAbilities, existing damage pipeline, and CombatFeedback. Z may integrate with PlayerController for movement/state. Do not create second HP, damage, ability lifecycle, or combat FSM systems.

## Runtime visual hierarchy
Player → Visuals → CharacterModel → Skeleton3D → hand.R/SwordMesh and hand.L/ShieldMesh. A runtime GiantShieldVisual has existed for Z. Do not delete/replace existing assets without validating dependencies.

## Blender/Godot boundary
Blender: authored animation, pose, sword/shield handling. Godot: state, timing, movement, hit detection, damage, stamina, cooldown, VFX, camera.

## High-risk changes
PlayerController, combat FSM, damage pipeline, DodgeController, AbilitySystem, InputMap, and scene hierarchy require inspection and immediate targeted validation.
