# Arena-fighting Project Constitution

## Project
Name: Arena-fighting
Purpose: 3D stylized hero-based arena fighting game.
Engine: Godot 4.3 Forward+
Tools: Blender 5.2, Blender MCP, Antigravity, Git/GitHub.
Hardware target: GTX 1650-class PC.

## Core design
Hero-based combat. Hero identity comes from basic combat style, abilities, animation, VFX, movement, and ultimate.

**Do NOT introduce a generic Heavy Attack system.**

## Knight controls
| Input | Function |
|---|---|
| LMB | 3-hit basic sword combo |
| RMB | shield block |
| Q | Dash / Perfect Dodge / Counter |
| Z | Giant Shield Charge |
| X | Sky Dive / Aerial Impale |
| C | Whirling Blade |
| V | Ultimate |
| B | FPS/TPS toggle |
| WASD | movement |

## Locked combat rules

### LMB
- 3-hit combo.
- No rapid-click buffer.
- Each next attack requires a new LMB press during the valid combo window.
- Holding LMB must not advance the combo.
- Expired combo resets.
- Finisher recovery blocks attack/block/dodge.

### RMB
- directional shield block.
- approximately 120-degree front cone.
- normal incoming damage: 25.
- block reduction: 85%.
- blocked HP damage: 3.75.
- shield damage is separate.
- broken shield means later attacks deal full normal damage until reset/new life/round according to current mode.

### Q
Dash: distance 4.5m, duration 0.25s, speed 18m/s, cooldown 1.0s, stamina cost 0.

Perfect Dodge: partial-dash i-frame; only dodgeable attacks can be perfectly dodged; successful Perfect Dodge opens Counter Window.

Counter: Counter Window 0.6s; LMB during it triggers Knight Counter; target range 8m; real lunge, not teleport; current counter damage 50; no Heavy Attack.

### Z
Giant Shield Charge:
- enlarged shield
- real forward charge
- steer using camera/mouse with turn-rate limit
- front protection during active charge
- side/back not protected
- existing damage pipeline
- one hit per target/cast
- enemy should stop/stagger on impact according to approved implementation
- shield retracts
- LMB combo usable after recovery
- no Heavy Attack

Current config: startup 0.20s, active 0.60s, recovery 0.40s, damage 25, stamina 20, cooldown 4s.

### X
Aerial positioning/aim phase, high jump, camera/mouse positioning, click confirms long-distance impale, no hard target lock.

### C
Circular sword spin, radial attack, no per-frame damage spam, one hit per target/cast by default.

### V
Giant sword descends from sky into medium AOE, requires 100 stamina, no normal cooldown, consumes/resets stamina.

## Stamina
- successful hits generate stamina
- no passive stamina regeneration in v1
- skills consume stamina
- Ultimate requires 100%
- Dash currently costs 0 stamina

## Camera
B toggles FPS/TPS. FPS head/neck camera. TPS spring arm ~3.5m. TPS centered. 360 yaw. Camera pitch does not rotate player. Player yaw follows camera. WASD camera-relative. No target lock. No second Camera3D. Do not re-add crosshair automatically.

## Hard prohibition
Do not introduce Heavy Attack. If an ability resembles one visually, it remains a named ability with its own input/data. If a design change seems desirable, report it instead of implementing silently.
