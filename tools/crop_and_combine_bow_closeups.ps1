Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$files = @(
    @{ Name = "archer_bow_idle_left"; Title = "1. Idle (Left View) - Bow vs Hand_L"; Path = "d:\Game 3D\Game_3D\scratch\archer_bow_idle_left_closeup.png" },
    @{ Name = "archer_bow_run_f4"; Title = "2. Run Frame 4 (Stride Peak 1)"; Path = "d:\Game 3D\Game_3D\scratch\archer_bow_run_f4_closeup.png" },
    @{ Name = "archer_bow_run_f10"; Title = "3. Run Frame 10 (Stride Peak 2)"; Path = "d:\Game 3D\Game_3D\scratch\archer_bow_run_f10_closeup.png" }
)

$cropW = 600
$cropH = 600
$cropX = 276  # (1152 - 600) / 2 = 276 -> perfectly centered around hand & bow
$cropY = 24   # (648 - 600) / 2 = 24 -> perfectly centered vertically

$previewDir = "d:\Game 3D\preview_images"
if (-not (Test-Path $previewDir)) {
    New-Item -ItemType Directory -Path $previewDir -Force | Out-Null
}

$croppedBitmaps = @()

foreach ($item in $files) {
    $srcImg = [System.Drawing.Image]::FromFile($item.Path)
    $bmp = New-Object System.Drawing.Bitmap $cropW, $cropH
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    
    $srcRect = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropW, $cropH
    $dstRect = New-Object System.Drawing.Rectangle 0, 0, $cropW, $cropH
    $g.DrawImage($srcImg, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    
    $g.Dispose()
    $srcImg.Dispose()
    
    # Save individual cropped image
    $outCropScratch = "d:\Game 3D\Game_3D\scratch\" + $item.Name + "_cropped.png"
    $outCropPreview = $previewDir + "\" + $item.Name + "_cropped.png"
    $bmp.Save($outCropScratch, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Save($outCropPreview, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $croppedBitmaps += @{ Bmp = $bmp; Title = $item.Title }
}

# Create 3-in-1 composite
$headerH = 60
$comboW = $cropW * 3
$comboH = $cropH + $headerH

$combo = New-Object System.Drawing.Bitmap $comboW, $comboH
$gCombo = [System.Drawing.Graphics]::FromImage($combo)
$gCombo.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gCombo.Clear([System.Drawing.Color]::FromArgb(30, 34, 42))

$font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 240, 245))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(20, 24, 30))

for ($i = 0; $i -lt 3; $i++) {
    $xOffset = $i * $cropW
    # Draw header background
    $gCombo.FillRectangle($bgBrush, $xOffset, 0, $cropW, $headerH)
    
    # Draw title string centered in header
    $strSize = $gCombo.MeasureString($croppedBitmaps[$i].Title, $font)
    $strX = $xOffset + [math]::Max(10, ($cropW - $strSize.Width) / 2)
    $strY = ($headerH - $strSize.Height) / 2
    $gCombo.DrawString($croppedBitmaps[$i].Title, $font, $brush, $strX, $strY)
    
    # Draw cropped image
    $gCombo.DrawImage($croppedBitmaps[$i].Bmp, $xOffset, $headerH, $cropW, $cropH)
}

$comboScratch = "d:\Game 3D\Game_3D\scratch\archer_bow_comparison_cropped.png"
$comboPreview = "$previewDir\archer_bow_comparison_cropped.png"
$comboArtifact = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\ae1a941b-37f7-425a-9019-d431a81cb3ee\archer_bow_comparison_cropped.png"

$combo.Save($comboScratch, [System.Drawing.Imaging.ImageFormat]::Png)
$combo.Save($comboPreview, [System.Drawing.Imaging.ImageFormat]::Png)
$combo.Save($comboArtifact, [System.Drawing.Imaging.ImageFormat]::Png)

# Set clipboard to real image bitmap
$dataObj = New-Object System.Windows.Forms.DataObject
$dataObj.SetImage($combo)
$fileDrop = New-Object System.Collections.Specialized.StringCollection
$fileDrop.Add($comboPreview) | Out-Null
$dataObj.SetFileDropList($fileDrop)
[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true)

$gCombo.Dispose()
$combo.Dispose()
foreach ($cb in $croppedBitmaps) {
    $cb.Bmp.Dispose()
}

Write-Host "Successfully generated and saved cropped images and 3-in-1 composite to $comboPreview"
Write-Host "Bitmap copied to clipboard!"
