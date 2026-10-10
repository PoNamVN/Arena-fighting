Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Load source images
$fFront = 'd:\Game 3D\Game_3D\scratch\elf_archer_front.png'
$fBack  = 'd:\Game 3D\Game_3D\scratch\elf_archer_back_capped.png'
$f34    = 'd:\Game 3D\Game_3D\scratch\elf_archer_34.png'
$fSide  = 'd:\Game 3D\Game_3D\scratch\elf_archer_side.png'
$fGodot = 'd:\Game 3D\Game_3D\scratch\archer_godot_real_ingame.png'

$imgFront = [System.Drawing.Image]::FromFile($fFront)
$imgBack  = [System.Drawing.Image]::FromFile($fBack)
$img34    = [System.Drawing.Image]::FromFile($f34)
$imgSide  = [System.Drawing.Image]::FromFile($fSide)
$imgGodot = [System.Drawing.Image]::FromFile($fGodot)

# 1. Generate 3-in-1 (Front, Side, 3/4)
$w = $imgFront.Width
$h = $imgFront.Height
$combo3 = New-Object System.Drawing.Bitmap ($w * 3), $h
$g3 = [System.Drawing.Graphics]::FromImage($combo3)
$g3.Clear([System.Drawing.Color]::FromArgb(40, 44, 52))
$g3.DrawImage($imgFront, 0, 0, $w, $h)
$g3.DrawImage($imgSide, $w, 0, $w, $h)
$g3.DrawImage($img34, ($w * 2), 0, $w, $h)
$outPath3 = 'd:\Game 3D\Game_3D\scratch\elf_archer_showcase_3in1.png'
$combo3.Save($outPath3, [System.Drawing.Imaging.ImageFormat]::Png)
$g3.Dispose()
$combo3.Dispose()

# 2. Generate 4-in-1 Master Showcase Grid (Front, Back, 3/4, Godot in-game)
$gw = 800
$gh = 800
$combo4 = New-Object System.Drawing.Bitmap ($gw * 2), ($gh * 2)
$g4 = [System.Drawing.Graphics]::FromImage($combo4)
$g4.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g4.Clear([System.Drawing.Color]::FromArgb(35, 39, 46))

$g4.DrawImage($imgFront, 0, 0, $gw, $gh)
$g4.DrawImage($imgBack, $gw, 0, $gw, $gh)
$g4.DrawImage($img34, 0, $gh, $gw, $gh)
$g4.DrawImage($imgGodot, $gw, $gh, $gw, $gh)

$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 240, 245))
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 20, 24, 30))
$font = New-Object System.Drawing.Font('Arial', 18, [System.Drawing.FontStyle]::Bold)

$labels = @(
    @{ Text = "1. Truoc (Front)"; X = 30; Y = 30 },
    @{ Text = "2. Sau da bit mu (Back Capped)"; X = $gw + 30; Y = 30 },
    @{ Text = "3. Goc 3/4 Perspective"; X = 30; Y = $gh + 30 },
    @{ Text = "4. Render that Godot 4.3 Vulkan"; X = $gw + 30; Y = $gh + 30 }
)

foreach ($lbl in $labels) {
    $size = $g4.MeasureString($lbl.Text, $font)
    $g4.FillRectangle($bgBrush, $lbl.X - 5, $lbl.Y - 5, $size.Width + 10, $size.Height + 10)
    $g4.DrawString($lbl.Text, $font, $brush, $lbl.X, $lbl.Y)
}

$outPath4 = 'd:\Game 3D\Game_3D\scratch\elf_archer_master_showcase.png'
$combo4.Save($outPath4, [System.Drawing.Imaging.ImageFormat]::Png)

# 3. SET REAL IMAGE BITMAP TO CLIPBOARD!
# Both SetImage (raw bitmap) AND SetFileDropList (file drop) so any application can accept it!
$dataObj = New-Object System.Windows.Forms.DataObject
$dataObj.SetImage($combo4)
$fileDrop = New-Object System.Collections.Specialized.StringCollection
$fileDrop.Add($outPath4) | Out-Null
$dataObj.SetFileDropList($fileDrop)
[System.Windows.Forms.Clipboard]::SetDataObject($dataObj, $true)

$g4.Dispose()
$combo4.Dispose()
$imgFront.Dispose()
$imgBack.Dispose()
$img34.Dispose()
$imgSide.Dispose()
$imgGodot.Dispose()

Write-Output "SUCCESS: Saved showcase and copied real bitmap image to clipboard!"
