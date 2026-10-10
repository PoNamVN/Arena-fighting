Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$poses = @(
    @{ Key = "state_idle"; Name = "1. Idle (Left View)"; Out = "archer_pose_1_idle_cropped.png"; CropX = 326; CropY = 24 },
    @{ Key = "state_run_f4"; Name = "2. Run F4 (Stride Peak 1)"; Out = "archer_pose_2_run_f4_cropped.png"; CropX = 326; CropY = 24 },
    @{ Key = "state_run_f10"; Name = "3. Run F10 (Stride Peak 2)"; Out = "archer_pose_3_run_f10_cropped.png"; CropX = 326; CropY = 24 },
    @{ Key = "state_aim_start"; Name = "4. Aim Start (Reparent)"; Out = "archer_pose_4_aim_start_cropped.png"; CropX = 326; CropY = 24 },
    @{ Key = "state_aim_hold"; Name = "5. Aim Hold (Full Draw)"; Out = "archer_pose_5_aim_hold_cropped.png"; CropX = 326; CropY = 24 },
    @{ Key = "state_aim_end"; Name = "6. Aim End (Return Hand)"; Out = "archer_pose_6_aim_end_cropped.png"; CropX = 326; CropY = 24 },
    @{ Key = "state_dead"; Name = "7. Dead (Bow on Ground)"; Out = "archer_pose_7_dead_cropped.png"; CropX = 326; CropY = 24 }
)

$cropW = 500
$cropH = 600
$previewDir = "d:\Game 3D\preview_images"
if (-not (Test-Path $previewDir)) {
    New-Item -ItemType Directory -Path $previewDir -Force | Out-Null
}

$croppedList = @()

foreach ($p in $poses) {
    $srcPath = "d:\Game 3D\Game_3D\scratch\" + $p.Key + ".png"
    $srcImg = [System.Drawing.Image]::FromFile($srcPath)
    
    $bmp = New-Object System.Drawing.Bitmap $cropW, $cropH
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    
    $srcRect = New-Object System.Drawing.Rectangle $p.CropX, $p.CropY, $cropW, $cropH
    $dstRect = New-Object System.Drawing.Rectangle 0, 0, $cropW, $cropH
    $g.DrawImage($srcImg, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    
    $g.Dispose()
    $srcImg.Dispose()
    
    $outPath = "$previewDir\" + $p.Out
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $croppedList += @{ Bmp = $bmp; Title = $p.Name; File = $outPath }
}

# Create 7-panel composite (or 2-row layout: 4 on top, 3 on bottom, or 1 wide row)
# Let's do 1 row of 7 panels: 7 * 500 = 3500 px wide, 660 px tall
$headerH = 50
$comboW = $cropW * 7
$comboH = $cropH + $headerH

$combo = New-Object System.Drawing.Bitmap $comboW, $comboH
$gCombo = [System.Drawing.Graphics]::FromImage($combo)
$gCombo.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gCombo.Clear([System.Drawing.Color]::FromArgb(26, 30, 38))

$font = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 245, 250))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(18, 22, 28))

for ($i = 0; $i -lt 7; $i++) {
    $xOffset = $i * $cropW
    $gCombo.FillRectangle($bgBrush, $xOffset, 0, $cropW, $headerH)
    
    $strSize = $gCombo.MeasureString($croppedList[$i].Title, $font)
    $strX = $xOffset + [math]::Max(5, ($cropW - $strSize.Width) / 2)
    $strY = ($headerH - $strSize.Height) / 2
    $gCombo.DrawString($croppedList[$i].Title, $font, $brush, $strX, $strY)
    
    $gCombo.DrawImage($croppedList[$i].Bmp, $xOffset, $headerH, $cropW, $cropH)
}

$showcasePath = "$previewDir\archer_option_b_7poses_showcase.png"
$artifactPath = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\ae1a941b-37f7-425a-9019-d431a81cb3ee\archer_option_b_7poses_showcase.png"
$combo.Save($showcasePath, [System.Drawing.Imaging.ImageFormat]::Png)
$combo.Save($artifactPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Clipboard
$dataObj = New-Object System.Windows.Forms.DataObject
$dataObj.SetImage($combo)
$fileDrop = New-Object System.Collections.Specialized.StringCollection
$fileDrop.Add($showcasePath) | Out-Null
$dataObj.SetFileDropList($fileDrop)
[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true)

$gCombo.Dispose()
$combo.Dispose()
foreach ($item in $croppedList) {
    $item.Bmp.Dispose()
}

Write-Host "Saved 7 cropped poses and master showcase: $showcasePath"
Write-Host "Bitmap copied to clipboard!"
