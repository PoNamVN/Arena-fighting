# Development Workflow

## General Process
1. **Planning** – Define a clear task, update `docs/progress_checkpoint.md` with the checkpoint description.
2. **Implementation** – Work in a feature branch, make atomic commits, run local tests.
3. **Testing** – Execute the relevant automated test script (e.g., `run_task5_14_attack_combo_test.gd`).
4. **Verification** – Before Git checkpoint:
   - Run feature tests.
   - Run full regression via `tools/run_regression.ps1`.
   - Verify regression summary.
   - Run `git diff --check`.
   - Perform manual gameplay test.
   - Obtain user acceptance.
   - Commit only after acceptance.
   - Never push unless explicitly requested.
5. **Checkpoint** – When all tests pass, create a Git checkpoint commit (do **not** push without user approval).
6. **Handoff** – Update `docs/AI_HANDOFF.md` and related documentation before handing over to the next agent.

## Tooling
- **Godot Editor** – Use the head‑less console for automated tests:
  ```powershell
  "D:\\Game\\godot_editor\\Godot_v4.3-stable_win64_console.exe" --path "D:\\Game 3D\\Game_3D" -s <test_script>.gd
  ```
- **PowerShell Scripts** – `tools/run_regression.ps1` runs all test suites.
- **Blender MCP** – Asset export pipeline; assets land in `assets/models/`.

## Branching & Commits
- Feature branches are named `feat/<description>`.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `refactor:`).
- After a checkpoint, **do not** push; the user will decide when to push.

## Code Review & Quality
- Keep the **architecture** (`docs/architecture.md`) up‑to‑date.
- Run `git diff --check` before any commit to catch whitespace issues.
- Maintain high test coverage – add a new test file for any new gameplay mechanic.

---
*Generated automatically by Antigravity on 2026‑10‑01.*
