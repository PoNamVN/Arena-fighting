---
name: verification-discipline
description: Verification gates and task completion checklist to enforce honest, verified task delivery.
---

# Verification Discipline & Sign-Off Checklist

Before presenting any task as "complete", the agent must run through this checklist:

## 1. Scope Boundary Check
- [ ] Did I modify ONLY files listed in the agreed plan?
- [ ] Are all untouched files completely unmodified?
- [ ] Is there any leftover debug code or temporary `print()` statements?

## 2. Headless Compilation & Syntax Verification
- [ ] For Godot code, was headless verification executed?
  ```powershell
  & "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --path "D:\Game 3D\Game_3D" --headless --check-only
  ```
- [ ] Did it exit with return code 0?
- [ ] Are there zero parse errors or script warnings?

## 3. Asset Integrity Verification
- [ ] If a 3D model was exported, does the `.glb` file exist on disk?
- [ ] Was the scale, origin, and material verified?
- [ ] Is the polygon budget within limits (< 3000 tris)?

## 4. Honest Status Reporting
- Clearly state what was tested and what was not:
  - **Verified**: Headless syntax check, static types, node structure.
  - **Requires User Validation**: Game feel, camera smooth follow, input response.
