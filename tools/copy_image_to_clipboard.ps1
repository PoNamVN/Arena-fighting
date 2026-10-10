param(
    [string]$ImagePath = 'd:\Game 3D\Game_3D\scratch\archer_godot_real_ingame.png'
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (Test-Path $ImagePath) {
    # Load into memory stream so file handle isn't locked
    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $img = [System.Drawing.Image]::FromStream($ms)
    
    # Put actual bitmap into clipboard
    [System.Windows.Forms.Clipboard]::SetImage($img)
    
    Write-Output "Successfully copied real image bitmap to clipboard: $ImagePath"
} else {
    Write-Error "File not found: $ImagePath"
}
