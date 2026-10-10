Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$files = @(
    @{ Name = "wide_idle_left"; Title = "1. Idle (Left View - Full Bow)"; Path = "d:\Game 3D\Game_3D\scratch\wide_idle_left.png" },
    @{ Name = "wide_run_f4"; Title = "2. Run Frame 4 (Stride Peak 1)"; Path = "d:\Game 3D\Game_3D\scratch\wide_run_f4.png" },
    @{ Name = "wide_run_f10"; Title = "3. Run Frame 10 (Stride Peak 2)"; Path = "d:\Game 3D\Game_3D\scratch\wide_run_f10.png" },
    @{ Name = "wide_aim_start"; Title = "4. Aim Start (Reparent & Nocked Arrow)"; Path = "d:\Game 3D\Game_3D\scratch\wide_aim_start.png" }
)

$previewDir = "d:\Game 3D\preview_images"
foreach ($f in $files) {
    Copy-Item $f.Path "$previewDir\$($f.Name).png" -Force
}

# 2x2 grid composite
$w = 1280
$h = 720
$comboW = $w * 2
$comboH = $h * 2
$combo = New-Object System.Drawing.Bitmap $comboW, $comboH
$g = [System.Drawing.Graphics]::FromImage($combo)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(20, 24, 30))

$font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 245, 250))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 15, 18, 24))

for ($i = 0; $i -lt 4; $i++) {
    $col = $i % 2
    $row = [math]::Floor($i / 2)
    $x = $col * $w
    $y = $row * $h
    
    $srcImg = [System.Drawing.Image]::FromFile($files[$i].Path)
    $g.DrawImage($srcImg, $x, $y, $w, $h)
    $srcImg.Dispose()
    
    $title = $files[$i].Title
    $strSize = $g.MeasureString($title, $font)
    $g.FillRectangle($bgBrush, $x + 20, $y + 20, $strSize.Width + 20, $strSize.Height + 10)
    $g.DrawString($title, $font, $brush, $x + 30, $y + 25)
}

$outPath = "$previewDir\archer_wide_4poses_showcase.png"
$artifactPath = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\ae1a941b-37f7-425a-9019-d431a81cb3ee\archer_wide_4poses_showcase.png"
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

Write-Host "Created $outPath and copied to clipboard!"
