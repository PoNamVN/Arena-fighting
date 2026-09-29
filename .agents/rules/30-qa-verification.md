---
description: QA verification and headless testing enforcement before task completion
trigger: always_on
---

# QA Verification & Testing Policy

1. **Automated Headless Checks**:
   - Before reporting a Godot feature or script complete, run the Godot console executable to check for syntax or scene corruption:
     ```powershell
     & "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --path "D:\Game 3D\Game_3D" --headless --check-only
     ```
   - Must exit with code 0 and zero error logs.

2. **No False Completion Claims**:
   - Explicitly report the result of the headless run or manual inspection.
   - If interactive runtime testing (e.g. playing the scene with input) cannot be run automatically in the current session, clearly state: "Syntax/scene verified via headless check; interactive player control requires manual test in editor."

3. **Atomic Commit & Rollback Readiness**:
   - Maintain working code at each commit step.
   - If a change introduces errors that cannot be solved quickly, rollback cleanly using Git rather than stacking more broken edits.
