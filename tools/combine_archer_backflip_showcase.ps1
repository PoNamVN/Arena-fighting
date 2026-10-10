Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$files = @(
    @{ Name = "1_crouch_spring"; Title = "Phase 1: Pre-jump Coil (t=0.06s) - Deep Spring Compression"; Path = "d:\Game 3D\preview_images\archer_backflip_1_crouch_spring.png" },
    @{ Name = "2_launch_tuck"; Title = "Phase 2: High Aerial Launch (t=0.18s) - Rising Rotation ~90 deg"; Path = "d:\Game 3D\preview_images\archer_backflip_2_launch_tuck.png" },
    @{ Name = "3_inverted_somersault"; Title = "Phase 3: Majestic Somersault Apex (t=0.30s) - Upside Down 180 deg (Height 1.75m)"; Path = "d:\Game 3D\preview_images\archer_backflip_3_inverted_somersault.png" },
    @{ Name = "4_descending_open"; Title = "Phase 4: Descending & Unfolding (t=0.42s) - Target Acquisition"; Path = "d:\Game 3D\preview_images\archer_backflip_4_descending_open.png" },
    @{ Name = "5_landing_crouch"; Title = "Phase 5: Athletic Touchdown (t=0.54s) - Deep 3-Point Hunter Crouch & Bow Guard"; Path = "d:\Game 3D\preview_images\archer_backflip_5_landing_crouch.png" },
    @{ Name = "6_hunter_recovery"; Title = "Phase 6: Hunter Poise Recovery (t=0.64s) - Ready-to-Draw Stance"; Path = "d:\Game 3D\preview_images\archer_backflip_6_hunter_recovery.png" }
)

$previewDir = "d:\Game 3D\preview_images"

# 3 columns x 2 rows grid composite
$w = 1280
$h = 720
$comboW = $w * 3
$comboH = $h * 2
$combo = New-Object System.Drawing.Bitmap $comboW, $comboH
$g = [System.Drawing.Graphics]::FromImage($combo)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(15, 20, 26))

$font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 248, 255))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 10, 15, 22))

for ($i = 0; $i -lt 6; $i++) {
    $col = $i % 3
    $row = [math]::Floor($i / 3)
    $x = $col * $w
    $y = $row * $h
    
    if (Test-Path $files[$i].Path) {
        $srcImg = [System.Drawing.Image]::FromFile($files[$i].Path)
        $g.DrawImage($srcImg, $x, $y, $w, $h)
        $srcImg.Dispose()
    }
    
    $title = $files[$i].Title
    $strSize = $g.MeasureString($title, $font)
    $g.FillRectangle($bgBrush, $x + 20, $y + 20, $strSize.Width + 20, $strSize.Height + 10)
    $g.DrawString($title, $font, $brush, $x + 30, $y + 25)
}

$outPath = "$previewDir\archer_backflip_showcase.png"
$artifactDir = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\51b335fb-583d-47ce-b413-033edcfca278"
if (!(Test-Path $artifactDir)) { New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null }
$artifactPath = "$artifactDir\archer_backflip_showcase.png"

$combo.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$combo.Save($artifactPath, [System.Drawing.Imaging.ImageFormat]::Png)

$dataObj = New-Object System.Windows.Forms.DataObject
$dataObj.SetImage($combo)
$fileDrop = New-Object System.Collections.Specialized.StringCollection
$fileDrop.Add($outPath) | Out-Null
$dataObj.SetFileDropList($fileDrop)
[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true)

$g.Dispose()
$combo.Dispose()

Write-Host "Created $outPath and copied to clipboard successfully!"
