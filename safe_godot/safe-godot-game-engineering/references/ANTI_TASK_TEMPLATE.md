# Antigravity Task Template

TASK:
[one logical task]

GOAL:
[exact result]

CURRENT BEHAVIOR:
[what currently happens]

EXPECTED BEHAVIOR:
[what should happen]

LOCKED:
- preserve LMB
- preserve RMB
- preserve Q
- preserve existing damage pipeline
- preserve existing camera behavior
- no Heavy Attack
- no unrelated refactor

FILES ALLOWED TO CHANGE:
[list]

DO NOT TOUCH:
[list]

IMPLEMENTATION:
1. Inspect first.
2. Identify root cause.
3. State minimal patch.
4. Implement.
5. Validate immediately.
6. Run targeted test.
7. Run relevant regression.
8. Report.
9. Stop.

STOP CONDITIONS:
- parser error
- unrelated runtime error
- unexpected protected-system change
- architecture conflict
- ambiguous requirement
- need for broad refactor

TEST:
[list]

MANUAL TEST:
[list]

VALIDATION:
- Godot 4.3 validation
- targeted tests
- relevant regression
- git diff --check

REPORT:
- root cause
- files changed
- functions changed
- tests
- regression
- manual test
- known issues
- scope check

GIT:
DO NOT commit.
DO NOT push.
Wait for user acceptance.
