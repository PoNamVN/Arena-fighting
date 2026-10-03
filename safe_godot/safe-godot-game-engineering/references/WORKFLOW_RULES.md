# Controlled AI Development Workflow

PLAN → SELECT ROLE → INSPECT → IMPLEMENT → FEATURE TEST → REGRESSION → MANUAL TEST → ACCEPT/REJECT → GIT CHECKPOINT → NEXT TASK

## Scope lock
Every task should define TASK, GOAL, LOCKED, DO NOT TOUCH, TEST, REGRESSION, REPORT.

## Git
No automatic commit, push, reset, or revert of unrelated user work. Before checkpoint: git status, git diff, git diff --check. One logical milestone = one commit.

## Definition of done
Implementation complete; targeted test passes; relevant regression passes; manual test passes; no unrelated changes; diff check passes; docs updated when needed; user accepts; checkpoint only after acceptance.

## Failure policy
If manual gameplay fails, do not accept based on automated tests. Identify actual runtime failure, fix only current task, rerun targeted and manual tests.

## Report style
Distinguish implemented, tested, manually verified, known issue, and not tested.
