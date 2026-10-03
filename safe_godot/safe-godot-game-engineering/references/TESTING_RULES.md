# Testing Rules

## Testing hierarchy
1. Syntax/project validation
2. Targeted automated test
3. Related regression
4. Manual runtime test
5. User acceptance
6. Git checkpoint

## Godot validation
Known Godot 4.3 executable: `D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe`
Project: `D:\Game 3D\Game_3D`

Basic validation:
```text
"D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe" --path "D:\Game 3D\Game_3D" --headless --editor --quit
```

Do not claim validation unless actually run.

## Targeted tests
Use the current repository's task tests. Historical examples include:
- run_task5_15b_dodge_test.gd
- run_task5_15c_a_iframe_test.gd
- run_task5_15c_counter_test.gd
- run_task5_15c_hp_bar_test.gd
- combo tests
- shield tests
- regression runner

Filenames may evolve; inspect the current repository rather than assuming they still exist.

## Regression truth
Historical known/pre-existing failures exist in older suites. Never call the entire regression 100% passed if known failures remain. Use "0 unexpected failures", "no new regressions", "X/Y targeted tests passed", and "known pre-existing failure" where appropriate.

## Manual test
For gameplay features define exact input, starting position, target state, expected movement, expected hit result, expected animation/state, expected cooldown/recovery, and expected debugger result.

## Runtime truth
If automated tests pass but manual gameplay fails, manual failure wins for acceptance. Investigate the actual runtime path. Do not dismiss it as visual.

## Test isolation
Targeted tests should prove the requested feature without accidentally depending on unrelated systems.

## Regression additions
When a bug is discovered, add a focused regression test when practical. Never weaken a test merely to restore green status.
