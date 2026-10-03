# Bug Lessons — Arena-fighting

## BUG-001 — Corrupted `_process_shield_charge()` match structure
Symptom: parser error such as `Expected end of statement after expression, found ":" instead.`
Cause: duplicated/orphaned `AbilityAction.Phase.*:` branches inserted outside the intended `match action.current_phase:`.
Lesson: when a function's block structure is corrupted, do not repeatedly delete random line ranges. Replace the entire affected function with one clean implementation, preserving behavior, then run Godot validation immediately.

## BUG-002 — `active_ability_action` became nil during Z processing
Symptom: `Invalid access to property or key 'current_phase' on a base object of type 'Nil'`.
Cause: `action.update(delta)` could trigger lifecycle completion and clear `active_ability_action` before later code dereferenced it.
Lesson: use a stable local action reference and validate it after update:
```gdscript
var action = active_ability_action
if not action or not action.is_active():
    return

action.update(delta)

if not is_instance_valid(action):
    return
if active_ability_action != action:
    return
if not action.is_active():
    return
```

## BUG-003 — Dash initially did not move
Symptoms: Q rotated but did not produce visible movement.
Causes encountered: animation/state transition overwrote DODGE, locomotion animation interfered, block release interference, floor snapping/residual velocity issues, runtime stamina default zero.
Lesson: when input works but displacement does not, trace state → velocity → move_and_slide → animation/state override. Do not only inspect input mapping.

## BUG-004 — Dash feel was too short
Initial 2.2m/~7.33m/s felt weaker than sprint. Approved tuning: 4.5m, 0.25s, 18m/s, 1s cooldown, 0 stamina.
Lesson: gameplay feel requires manual runtime validation.

## BUG-005 — Perfect Dodge raw numeric payload crash
Symptom: `Invalid operands 'String' and 'float' in operator 'in'`.
Cause: `can_perfect_dodge_attack()` assumed payload/dictionary while `take_damage()` sometimes passed raw numeric damage.
Lesson: shared APIs must normalize or safely type-check inputs.

## BUG-006 — Z safe-reference fix
Use local `action` reference in `_process_shield_charge()` and verify it remains valid/current after `action.update(delta)`.

## BUG-007 — Automated Z impact test did not prove runtime collision feel
Automated tests could report success while runtime movement still passed through a dummy.
Lesson: for movement/collision abilities, test actual runtime movement, collision layers/masks, movement order, hit timing, and impact state transition. Mocked/group detection is not proof of physical collision correctness.

## BUG-008 — Too many overlapping Z hit-detection mechanisms
Z has used combinations of physics shape query, enemy group query, and slide collision. Redundant paths can make debugging difficult and cause inconsistent impact behavior. Do not add another detection mechanism before understanding the current pipeline.

## BUG-009 — Parser fix is not gameplay acceptance
Parser PASS proves code can parse/load. It does not prove F5, Z collision, animation, damage, or feel. Continue to runtime testing.
