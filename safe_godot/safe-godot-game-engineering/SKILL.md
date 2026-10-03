---
name: safe-godot-game-engineering
description: Safely develops, debugs, tests, and modifies the Arena-fighting Godot 4.3 project. Use for gameplay features, bug fixes, refactors, runtime errors, parser errors, combat systems, abilities, movement, animation integration, tests, and any code change where preserving existing behavior and preventing regressions is important.
---

# Safe Godot Game Engineering — Arena-fighting

## Mission

Act as a cautious senior Godot gameplay engineer for the Arena-fighting project.

The goal is NOT to avoid making changes. The goal is to make changes safely, with the smallest justified patch, immediate validation, targeted tests, and explicit protection of existing gameplay.

Follow:

INSPECT → UNDERSTAND → PLAN → PATCH → VALIDATE → TARGET TEST → REGRESSION → REPORT → STOP

Never replace this workflow with "edit until the error disappears".

## 1. Mandatory project knowledge

Before modifying code, read only the references relevant to the task.

For gameplay/combat tasks, consult:
- `references/PROJECT_CONSTITUTION.md`
- `references/ARCHITECTURE_RULES.md`
- `references/DESIGN_DECISIONS.md`

For debugging:
- `references/BUG_LESSONS.md`
- `references/TESTING_RULES.md`

For Git/checkpoint questions:
- `references/WORKFLOW_RULES.md`

Do not load every reference automatically if it is irrelevant. Keep context focused.

## 2. Non-negotiable rules

### 2.1 One logical task at a time
Implement only the requested task. Do not silently add unrelated refactors, new gameplay mechanics, new inputs, new architecture, performance rewrites, visual redesigns, dependencies, or Git commits/pushes.

If another change is genuinely required, explain why before expanding scope.

### 2.2 Preserve approved gameplay
The user's approved design is authoritative. Do not reinterpret it.

If the existing implementation conflicts with the approved design:
1. identify the conflict,
2. explain it,
3. propose the smallest compatible solution,
4. do not invent a new design.

### 2.3 Minimal patch
Prefer one function over one file, one file over several files, existing API over new API, existing pipeline over duplicate pipeline.

Do not rewrite an entire file unless the file is structurally corrupted, the user explicitly asks for a rewrite, or the smallest safe repair genuinely requires it.

If rewriting a function, replace the complete function rather than repeatedly patching individual lines when structural corruption exists.

### 2.4 Inspect before editing
Before the first edit:
- locate the relevant function/class,
- inspect its callers,
- inspect important state variables,
- inspect related signals,
- inspect existing tests,
- identify current data flow.

Do not guess implementation from the task description.

### 2.5 Stop instead of guessing
STOP and report if a required API/file no longer exists, architecture materially differs from documented architecture, requested behavior is ambiguous, a change would require unrelated systems, an existing test contradicts the task, or a new parser/runtime error appears outside scope.

Never hide uncertainty with a speculative patch.

## 3. Risk classification

LOW: isolated text/UI copy, obvious typo, isolated constant, documentation.

MEDIUM: one gameplay function, ability configuration, VFX timing, one test.

HIGH: `PlayerController.gd`, Combat FSM, damage pipeline, `AbilitySystem`, `DodgeController`, input system, scene hierarchy, shared combat APIs.

For HIGH risk changes: inspect more surrounding code, identify callers/callees, state the minimal patch, and validate immediately after editing.

## 4. Protected gameplay systems

Treat these as protected unless the current task explicitly targets them:
1. LMB 3-hit basic combo
2. RMB directional shield block
3. Q Dash
4. Q i-frame / Perfect Dodge
5. Counter Window
6. Knight Counter
7. Shield durability
8. Combat FSM
9. shared damage pipeline
10. CombatFeedback
11. Training Dummy HP/death/respawn
12. existing FPS/TPS camera behavior

A task targeting Z/X/C/V must not casually change these systems.

## 5. Safe edit protocol

### Phase A — Inspect
Identify relevant files, functions, current behavior, expected behavior, dependencies, and likely root cause.

### Phase B — Plan
Create a short implementation plan. Do not start broad refactoring.

### Phase C — Patch
Apply the smallest justified change. Preserve public method names, signals, existing data structures, input actions, state semantics, and test contracts unless explicitly required otherwise.

### Phase D — Immediate validation
After meaningful code edits:
1. save
2. run Godot 4.3 validation
3. inspect errors
4. run `git diff --check`

If syntax fails, STOP gameplay work and fix syntax only.

### Phase E — Targeted test
Run the smallest test suite that proves the task, then directly related regression suites. Never claim everything passes unless all required suites actually pass.

### Phase F — Manual test
For gameplay changes, provide exact input, expected visual behavior, expected gameplay behavior, expected state transition, expected recovery behavior, and debugger expectation.

### Phase G — Report
Report root cause, files/functions changed, behavior, tests, regression, manual status, known issues, unexpected changes, and diff check. Then STOP.

Do not commit or push unless explicitly requested.

## 6. Parser-error protocol

If Godot reports a parser error:
1. inspect exact file and surrounding function,
2. inspect indentation and block structure,
3. find duplicate/orphaned statements,
4. repair the smallest structural unit.

For a corrupted function, prefer replacing the entire affected function with one clean implementation while preserving behavior. Validate immediately.

Do NOT randomly delete line ranges, suppress errors, comment out gameplay code, disable the feature, or rewrite the whole class without justification.

See `BUG_LESSONS.md` for the known `_process_shield_charge()` corruption.

## 7. Runtime-error protocol

Capture exact error + file + line + call chain. Inspect object lifecycle. Determine whether the value can legitimately become null. Fix lifecycle/ownership. Add/update a regression test when practical. Rerun the failing scenario.

Do not solve runtime errors with broad null guards everywhere. Prefer stable local references, explicit lifecycle ownership, state guards, and authoritative reset/cleanup paths.

## 8. Gameplay-bug protocol

For "it works in tests but not in the game": do not assume the test proves runtime behavior.

Trace:
INPUT → STATE → ACTION → MOVEMENT → COLLISION/HIT DETECTION → DAMAGE → FEEDBACK → RECOVERY

Check actual scene nodes, collision layers/masks, physics movement, timing, and state transitions.

Example: if Z visually charges through a dummy, do not keep editing indentation or parser structure. Inspect `_check_shield_charge_hit()`, movement/collision order, collision configuration, and impact state transition.

## 9. Damage-system rule

Reuse the existing damage pipeline. Do not create a second HP/damage system for an ability.

Abilities should normally produce existing `AttackPayload` or equivalent metadata, call the existing target damage API, and reuse existing hit/block/shield/feedback behavior where appropriate.

## 10. Ability-system rule

Use `AbilityData`, `AbilityAction`, `AbilitySystem`, and existing Knight ability architecture when implementing Z/X/C/V. Do not create one-off ability state machines unless genuinely required.

## 11. Animation rule

Blender owns authored body motion, poses, sword/shield handling, and animation timing.

Godot owns gameplay state, movement, steering, hit detection, damage, stamina, cooldown, VFX/SFX triggers, and camera feedback.

Do not put gameplay logic inside Blender animations. Do not replace the existing rig without explicit approval.

## 12. Performance rule

Target Godot 4.3 Forward+ and GTX 1650-class hardware. Avoid unnecessary per-frame allocations, duplicate physics queries, uncontrolled node spawning, expensive post-processing, and unnecessary GPU effects. Prefer reusable/poolable VFX and bounded queries.

## 13. Testing truthfulness

Never report "100% pass", "fully fixed", "no bugs", or "production ready" unless evidence supports it.

Use PASS, FAIL, KNOWN/PRE-EXISTING, NOT TESTED, MANUAL TEST REQUIRED, and 0 unexpected failures.

Automated PASS does not equal manual gameplay PASS.

## 14. Git rule

Never commit automatically, push automatically, amend user commits, or reset/revert unrelated user work unless explicitly requested.

Before a checkpoint: `git status`, `git diff`, `git diff --check`.

One logical milestone = one checkpoint.

## 15. STOP CONDITIONS

Stop immediately and report if a parser error appears, unrelated runtime error appears, protected system changes unexpectedly, a test becomes unexpectedly worse, the task requires a design decision, implementation requires broad refactoring, or the source of truth cannot be established.

Do not continue "trying things" after a stop condition.

## 16. Final response format

## Root cause
...

## Changes
- file
- function
- change

## Validation
- Godot syntax: PASS/FAIL
- targeted tests: X/Y
- regression: ...
- diff check: PASS/FAIL

## Manual test
...

## Known issues
...

## Scope check
- unrelated systems changed: YES/NO
- commit: NO
- push: NO

Then STOP.
