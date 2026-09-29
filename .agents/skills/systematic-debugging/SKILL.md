---
name: systematic-debugging
description: A 4-phase rigorous debugging procedure (ECC inspired) to isolate, diagnose, and fix issues without introducing side-effects.
---

# Systematic Debugging Procedure

When any bug, syntax error, or runtime crash occurs, follow these 4 mandatory phases:

## Phase 1: Reproduce & Capture
1. Do not start editing code immediately.
2. Run the headless check or inspection script to capture the exact error message, stack trace, and line number:
   ```powershell
   & "D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --path "D:\Game 3D\Game_3D" --headless --check-only
   ```
3. Document the precise failure symptoms.

## Phase 2: Root Cause Isolation
1. Trace the stack trace to the exact triggering statement.
2. Read the surrounding lines using `view_file`.
3. Distinguish between symptom and root cause (e.g. `null instance` usually means an uninitialized `@onready` path or wrong node hierarchy, not an issue with the call itself).

## Phase 3: Minimal, Atomic Fix
1. Formulate a hypothesis and apply the smallest possible change to address the root cause.
2. Do not rewrite large chunks of code or refactor unrelated logic.
3. Keep the diff clean and focused.

## Phase 4: Verification & Regression Check
1. Re-run the verification command.
2. Ensure the specific error is resolved and no new warnings/errors were introduced.
3. If the fix fails, rollback using Git before attempting a different approach.
