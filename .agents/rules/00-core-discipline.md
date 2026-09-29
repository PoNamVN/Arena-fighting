---
description: Core discipline, strict modification boundaries, and verification standards inspired by ECC
trigger: always_on
---

# Core Engineering Discipline (ECC Inspired)

1. **Strict Scope Control**:
   - Only modify files directly related to the current task or requested change.
   - Never refactor, rename, or "clean up" unrelated files without explicit user approval.
   - Do not make multi-file speculative changes. Make atomic, single-responsibility edits.

2. **No Hallucination & Fact-Based Decisions**:
   - Never invent gameplay rules, storyline, mechanics, or art styles. If unspecified, mark as `[TBD]` in documentation and ask the user.
   - Verify file existence, paths, and engine features before making assumptions.

3. **Verification Before Completion**:
   - **Never claim a task is completed, tested, or working without actual execution evidence.**
   - Run verification checks (e.g. Godot headless syntax check, script parsing, or Blender screenshot) before declaring success.
   - If a test cannot be executed, explicitly state what was done and what remains untested.

4. **Resource & Performance Constraints**:
   - Hardware target: Windows, 16GB RAM, max 4GB GPU VRAM.
   - Maintain lightweight architectures: low draw calls, low polygon count, zero memory leaks, avoid unnecessary heavy background processes.

5. **Stop and Ask Policy**:
   - If an error occurs, or if requirements conflict, stop immediately. Present the issue clearly with options rather than blindly trying alternatives.
