$ErrorActionPreference = 'Continue'
$godot = 'D:\Game\godot_editor\Godot_v4.3-stable_win64_console.exe'
$project = 'D:\Game 3D\Game_3D'
$outputRoot = Join-Path $PSScriptRoot 'regression_output'
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$suites = @('run_phase1_runtime_test.gd','run_phase2_runtime_test.gd','run_phase3_runtime_test.gd','run_phase4_fsm_runtime_test.gd','run_rmb_lifecycle_test.gd','run_task5_1_slash_arc_test.gd','run_task5_2_hit_impact_test.gd','run_task5_3_block_impact_test.gd','run_task5_4_shield_durability_test.gd','run_task5_5_shield_break_test.gd','run_task5_6_combat_test_arena_test.gd','run_task5_7_hit_reaction_test.gd','run_task5_8_combat_feedback_test.gd','run_task5_9_attack_telegraph_test.gd','run_task5_10_shield_lifecycle_test.gd','run_task5_11_combat_feedback_test.gd','run_task5_12_shift_lock_test.gd','run_training_dummy_test.gd','run_visual_slash_cue_test.gd','run_task5_14_attack_combo_test.gd','run_task5_14a_combo_buffer_test.gd','run_task5_14c_combo_finisher_recovery_test.gd','run_task5_14d_manual_combo_test.gd','run_task5_15a_foundation_test.gd','run_task5_15b_dodge_test.gd','run_task5_15c_perfect_dodge_test.gd','run_task5_15c_a_iframe_test.gd','run_task5_15c_counter_test.gd','run_task5_15c_hp_bar_test.gd','run_task5_15d_stamina_test.gd','run_task5_15e_ability_system_test.gd','run_task5_15f_combat_integration_test.gd','run_task_knight_shield_charge_test.gd','run_task_knight_sky_dive_core_test.gd','run_character_map_isolation_test.gd','run_task_knight_whirling_blade_test.gd','run_task_knight_giant_sword_test.gd','run_practice_arena_test.gd','run_practice_navigation_test.gd','run_practice_ai_upgrade_test.gd','run_archer_basic_test.gd','run_archer_volley_test.gd','run_archer_defense_test.gd','run_archer_xc_test.gd','run_archer_spiral_test.gd','run_archer_ultimate_test.gd','run_wizard_foundation_test.gd','run_wizard_zx_test.gd','run_wizard_cv_test.gd','run_wizard_presentation_test.gd','run_combat_spectacle_test.gd','run_vfx_framework_test.gd')
$known = @{}

function Get-Records([string[]]$lines) {
 $records=@(); $current=''
 foreach($line in $lines) {
  if($line -match '(?i)(TEST\s+\d+|STEP\s+\d+)'){$current=$matches[1].ToUpper()}
  if($line -match '(?i)(>>>\s*FAILED|TEST\s+\d+\s+FAILED|STEP\s+\d+.*FAILED|\[FAIL\])') {
   $key=''; if($line -match '(?i)(TEST\s+\d+|STEP\s+\d+)'){$key=$matches[1].ToUpper()}else{$key=$current}
   $records += [PSCustomObject]@{Key=$key;Line=$line.Trim()}
  }
 }
 return $records
}
$rows=@()
foreach($suite in $suites) {
 $lines=@(& $godot --path $project --headless -s $suite 2>&1 | ForEach-Object {"$_"}); $exit=$LASTEXITCODE
 $lines | Set-Content -Encoding UTF8 (Join-Path $outputRoot ($suite -replace '\.gd$','.log'))
 $records=@(Get-Records $lines); $fails=$records.Count; $old=@(); $new=@()
 foreach($r in $records){if($known.ContainsKey($suite) -and $known[$suite] -contains $r.Key){$old+=$r.Line}else{$new+=$r.Line}}
 $pass=@($lines|Where-Object{$_ -match '(?i)^\s*(\[PASS\]|>>>.*\bPASSED\b)'}).Count
 $sumPass=$null;$sumTotal=$null
 foreach($line in $lines){if($line -match '(?i)(RESULTS|SUMMARY):\s*(\d+)\s*/\s*(\d+).*?(PASSED|TESTS PASSED)'){$sumPass=[int]$matches[2];$sumTotal=[int]$matches[3]}}
 if($suite -eq 'run_phase1_runtime_test.gd' -and ($lines -match 'ALL PHASE 1 RUNTIME TESTS COMPLETED SUCCESSFULLY')){$sumPass=4;$sumTotal=4;$pass=4}
 if($null -eq $sumTotal){$ids=@($lines|ForEach-Object{if($_ -match '(?i)(TEST\s+\d+|STEP\s+\d+)'){$matches[1].ToUpper()}}|Sort-Object -Unique);if($ids.Count -gt 0){$pass=$ids.Count-$fails}}
 $mismatch=($null -ne $sumTotal -and ($pass -ne $sumPass -or $fails -ne ($sumTotal-$sumPass)))
 $executionError=($exit -ne 0 -and $fails -eq 0) -or (@($lines | Where-Object {$_ -match "SCRIPT ERROR:|Parse Error:"}).Count -gt 0);$status=if($new.Count -gt 0 -or $mismatch -or $executionError){'FAIL'}elseif($old.Count -gt 0){'KNOWN'}else{'PASS'}
 $rows += [PSCustomObject]@{Suite=$suite;Status=$status;Pass=$pass;Fail=$fails;Exit=$exit;Summary=if($null -ne $sumTotal){"$sumPass/$sumTotal"}else{'NONE'};Mismatch=$mismatch;Known=($old -join ' | ');New=($new -join ' | ')}
}
Write-Host "`nREGRESSION REPORT ($($suites.Count) SUITES)";$rows|Format-Table Suite,Status,Pass,Fail,Exit,Summary,Mismatch,Known,New -AutoSize
if(@($rows|Where-Object{$_.Status -eq 'FAIL'}).Count -gt 0){exit 1}else{exit 0}