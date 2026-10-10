Add-Type -AssemblyName System.Drawing
$w = 1280; $h = 720
$bmp = New-Object System.Drawing.Bitmap ($w * 2), ($h * 2)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

$files = @(
    @{ Path = 'd:\Game 3D\preview_images\test_aim_side_fixed.png'; X = 0; Y = 0; Title = '1. Aiming / Attack (Side View) - Left Hand Forwards Holding Bow, Right Hand Draws to Cheek' },
    @{ Path = 'd:\Game 3D\preview_images\test_aim_behind_fixed.png'; X = $w; Y = 0; Title = '2. Aiming / Attack (Behind View) - Straight Forward Aim Alignment' },
    @{ Path = 'd:\Game 3D\preview_images\test_block_side_fixed.png'; X = 0; Y = $h; Title = '3. Blocking with Bow (Side View) - Both Arms Extended Forward Bracing Bow' },
    @{ Path = 'd:\Game 3D\preview_images\test_block_behind_fixed.png'; X = $w; Y = $h; Title = '4. Blocking with Bow (Behind View) - Clean Front-Facing Block Silhouette' }
)

$font = New-Object System.Drawing.Font('Arial', 18, [System.Drawing.FontStyle]::Bold)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, 20, 20, 20))

foreach ($item in $files) {
    if (Test-Path $item.Path) {
        $img = [System.Drawing.Image]::FromFile($item.Path)
        $g.DrawImage($img, $item.X, $item.Y, $w, $h)
        $img.Dispose()
        $rect = New-Object System.Drawing.RectangleF ($item.X + 15), ($item.Y + 15), ($w - 30), 45
        $g.FillRectangle($bgBrush, $rect)
        $g.DrawString($item.Title, $font, $brush, ($item.X + 25), ($item.Y + 24))
    }
}
$g.Dispose()
$outPath = 'd:\Game 3D\preview_images\archer_combat_arm_showcase.png'
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Copy-Item $outPath 'C:\Users\HP VICTUS\.gemini\antigravity-ide\brain\51b335fb-583d-47ce-b413-033edcfca278\archer_combat_arm_showcase.png' -Force
Write-Host 'Created archer_combat_arm_showcase.png successfully!'
