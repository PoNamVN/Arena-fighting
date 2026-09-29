# Game Design Document (Overview)

## 1. Project Identity & Core Pillars
- **Project Name**: Game_3D
- **Genre**: 3D Arena Combat (Third-Person Perspective)
- **Engine**: Godot 4.3 (GDScript 2.0)
- **3D Modeling & Art**: Blender 5.2 (via Blender MCP)
- **Visual Style**: Low-poly, lightweight aesthetic (optimized for <= 4GB GPU VRAM)
- **Target Platform**: Windows PC (16GB RAM, 4GB VRAM)

---

## 2. Confirmed Core Specifications
- **Perspective**: Third-person follow camera (SpringArm3D + Camera3D).
- **Core Loop**: Arena-based real-time combat between player and opponents.
- **Asset Constraint**: Ultra-lightweight low-poly models (< 3,000 triangles for characters, < 500 triangles for arena props), flat shading or color palette textures.

---

## 3. Specifications To Be Determined (TBD)
> [!NOTE]
> The following gameplay details are deliberately not assumed or invented. They will be confirmed with the user in subsequent planning phases:

- **Combat Mechanics [TBD]**:
  - Attack types: [TBD - Light/Heavy combos, projectile abilities, or special skills?]
  - Defensive options: [TBD - Dodge roll, block, parry, or jump evade?]
  - Health & Resource system: [TBD - Health bar only, or stamina / mana / poise bar?]
- **Arena Design [TBD]**:
  - Theme/Setting: [TBD - Sci-fi, medieval colosseum, cyber-void, or fantasy ruins?]
  - Arena size & boundaries: [TBD - Circular walled arena, floating platform, or hazards?]
- **Opponent AI [TBD]**:
  - Enemy behavior model: [TBD - Training dummy first, then melee brawler or ranged attacker?]
- **Input System [TBD]**:
  - Primary controls: [TBD - Keyboard & Mouse default, Gamepad support?]
- **Audio & VFX [TBD]**:
  - Sound effects & music: [TBD - Free CC0 audio libraries or procedurally generated?]
