Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$f1 = 'd:\Game 3D\Game_3D\scratch\archer_bow_godot_idle.png'
$f2 = 'd:\Game 3D\Game_3D\scratch\archer_bow_godot_run.png'
$f3 = 'd:\Game 3D\Game_3D\scratch\archer_bow_godot_shot.png'

$img1 = [System.Drawing.Image]::FromFile($f1)
$img2 = [System.Drawing.Image]::FromFile($f2)
$img3 = [System.Drawing.Image]::FromFile($f3)

$w = $img1.Width
$h = $img1.Height
$combo = New-Object System.Drawing.Bitmap ($w * 3), $h
$g = [System.Drawing.Graphics]::FromImage($combo)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(35, 39, 46))

$g.DrawImage($img1, 0, 0, $w, $h)
$g.DrawImage($img2, $w, 0, $w, $h)
$g.DrawImage($img3, ($w * 2), 0, $w, $h)

$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 240, 245))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 20, 24, 30))
$font = New-Object System.Drawing.Font('Arial', 24, [System.Drawing.FontStyle]::Bold)

$labels = @(
    @{ Text = '1. Godot Idle Pose'; X = 40; Y = 40 },
    @{ Text = '2. Godot Run Pose'; X = $w + 40; Y = 40 },
    @{ Text = '3. Godot Shot / Aiming Pose'; X = ($w * 2) + 40; Y = 40 }
)

foreach ($lbl in $labels) {
    $size = $g.MeasureString($lbl.Text, $font)
    $g.FillRectangle($bgBrush, $lbl.X - 5, $lbl.Y - 5, $size.Width + 10, $size.Height + 10)
    $g.DrawString($lbl.Text, $font, $brush, $lbl.X, $lbl.Y)
}

$outPath = 'd:\Game 3D\Game_3D\scratch\archer_bow_godot_showcase.png'
$combo.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Set actual image bitmap to clipboard!
$dataObj = New-Object System.Windows.Forms.DataObject
$dataObj.SetImage($combo)
$fileDrop = New-Object System.Collections.Specialized.StringCollection
$fileDrop.Add($outPath) | Out-Null
$dataObj.SetFileDropList($fileDrop)
[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true)

$g.Dispose()
$combo.Dispose()
$img1.Dispose()
$img2.Dispose()
$img3.Dispose()

Write-Output "SUCCESS: Created $outPath and copied bitmap to clipboard!"
