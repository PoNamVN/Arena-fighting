$src = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\51b335fb-583d-47ce-b413-033edcfca278\scratch\ponytail_repo\skills"
$dest = "C:\Users\HP VICTUS\.gemini\config\skills"

if (-not (Test-Path $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
}

$skillDirs = Get-ChildItem -Path $src -Directory
foreach ($dir in $skillDirs) {
    $target = Join-Path $dest $dir.Name
    if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
    }
    Copy-Item -Path (Join-Path $dir.FullName "*") -Destination $target -Recurse -Force
    Write-Host "Installed skill: $($dir.Name) -> $target"
}

# Also install rules/ponytail.md in global config
$rulesDest = "C:\Users\HP VICTUS\.gemini\config\rules"
if (-not (Test-Path $rulesDest)) {
    New-Item -ItemType Directory -Path $rulesDest -Force | Out-Null
}
$agentsMd = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\51b335fb-583d-47ce-b413-033edcfca278\scratch\ponytail_repo\AGENTS.md"
if (Test-Path $agentsMd) {
    Copy-Item -Path $agentsMd -Destination (Join-Path $rulesDest "ponytail.md") -Force
    Write-Host "Installed global rule: ponytail.md -> $rulesDest"
}

Write-Host "Ponytail installation finished successfully!"
