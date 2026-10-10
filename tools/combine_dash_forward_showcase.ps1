Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$previewDir = "d:\Game 3D\preview_images"
$imgSidePath = "$previewDir\test_dash_fwd_side.png"
$imgBehindPath = "$previewDir\test_dash_fwd_behind.png"

$w = 1280
$h = 720
$comboW = $w * 2
$comboH = $h
$combo = New-Object System.Drawing.Bitmap $comboW, $comboH
$g = [System.Drawing.Graphics]::FromImage($combo)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::FromArgb(20, 24, 30))

$font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 245, 250))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 15, 18, 24))

# Left: Side View (Clear Forward Lean Profile)
if (Test-Path $imgSidePath) {
    $srcImg = [System.Drawing.Image]::FromFile($imgSidePath)
    $g.DrawImage($srcImg, 0, 0, $w, $h)
    $srcImg.Dispose()
    
    $title = "Goc Nhin Ngang (Side Profile): Cui Nguoi Rap Ve Truoc Rung & Luot Gio"
    $strSize = $g.MeasureString($title, $font)
    $g.FillRectangle($bgBrush, 20, 20, $strSize.Width + 20, $strSize.Height + 10)
    $g.DrawString($title, $font, $brush, 30, 25)
}

# Right: Behind View (Third Person In-Game)
if (Test-Path $imgBehindPath) {
    $srcImg = [System.Drawing.Image]::FromFile($imgBehindPath)
    $g.DrawImage($srcImg, $w, 0, $w, $h)
    $srcImg.Dispose()
    
    $title = "Goc Nhin Sau (3rd Person View): Ha Thap Trong Tam & Luot Thang"
    $strSize = $g.MeasureString($title, $font)
    $g.FillRectangle($bgBrush, $w + 20, 20, $strSize.Width + 20, $strSize.Height + 10)
    $g.DrawString($title, $font, $brush, $w + 30, 25)
}

$outPath = "$previewDir\archer_dash_forward_showcase.png"
$artifactPath = "C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\ae1a941b-37f7-425a-9019-d431a81cb3ee\archer_dash_forward_showcase.png"
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
