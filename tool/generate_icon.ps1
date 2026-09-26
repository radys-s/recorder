param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourceDir = Join-Path $ProjectRoot 'assets/icon/source'
$fullPath = Join-Path $sourceDir 'aftermind-icon.png'
$markPath = Join-Path $sourceDir 'aftermind-mark.png'
if (!(Test-Path -LiteralPath $fullPath) -or !(Test-Path -LiteralPath $markPath)) {
    throw "Expected generated source images in $sourceDir"
}

function New-Bitmap([int]$size) {
    $bmp = [System.Drawing.Bitmap]::new($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    return ,@($bmp, $g)
}

function Save-Resized($source, [int]$size, [string]$path, [bool]$opaque = $false) {
    $pair = New-Bitmap $size
    $bmp = $pair[0]
    $g = $pair[1]
    try {
        if ($opaque) {
            $g.Clear([System.Drawing.Color]::FromArgb(14, 15, 17))
        } else {
            $g.Clear([System.Drawing.Color]::Transparent)
        }
        $g.DrawImage($source, 0, 0, $size, $size)
        $parent = Split-Path -Parent $path
        if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}

$full = [System.Drawing.Bitmap]::new($fullPath)
$mark = [System.Drawing.Bitmap]::new($markPath)
try {
    $left = $mark.Width; $top = $mark.Height; $right = -1; $bottom = -1
    for ($y = 0; $y -lt $mark.Height; $y++) {
        for ($x = 0; $x -lt $mark.Width; $x++) {
            if ($mark.GetPixel($x, $y).A -gt 8) {
                if ($x -lt $left) { $left = $x }
                if ($x -gt $right) { $right = $x }
                if ($y -lt $top) { $top = $y }
                if ($y -gt $bottom) { $bottom = $y }
            }
        }
    }
    if ($right -lt $left -or $bottom -lt $top) { throw 'The mark source has no visible pixels.' }
    $crop = [System.Drawing.Rectangle]::new($left, $top, $right - $left + 1, $bottom - $top + 1)

    $assets = Join-Path $ProjectRoot 'assets/icon'
    Save-Resized $full 1024 (Join-Path $assets 'icon.png')
    Save-Resized $full 1024 (Join-Path $assets 'launch_tile.png')

    $pair = New-Bitmap 1024
    $fg = $pair[0]; $g = $pair[1]
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $target = [System.Drawing.Rectangle]::new(92, 92, 840, 840)
        $g.DrawImage($mark, $target, $crop, [System.Drawing.GraphicsUnit]::Pixel)
        $fg.Save((Join-Path $assets 'icon_foreground.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose() }

    $bgPair = New-Bitmap 1024
    $bg = $bgPair[0]; $bgGraphics = $bgPair[1]
    try {
        $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.Rectangle]::new(0, 0, 1024, 1024),
            [System.Drawing.Color]::FromArgb(40, 41, 46),
            [System.Drawing.Color]::FromArgb(14, 15, 17),
            [System.Drawing.Drawing2D.LinearGradientMode]::Vertical)
        try { $bgGraphics.FillRectangle($brush, 0, 0, 1024, 1024) } finally { $brush.Dispose() }
        $bg.Save((Join-Path $assets 'icon_background.png'), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { }

    $android = Join-Path $ProjectRoot 'android/app/src/main/res'
    foreach ($entry in @{ mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192 }.GetEnumerator()) {
        Save-Resized $full $entry.Value (Join-Path $android "mipmap-$($entry.Key)/ic_launcher.png")
    }
    foreach ($entry in @{ mdpi=108; hdpi=162; xhdpi=216; xxhdpi=324; xxxhdpi=432 }.GetEnumerator()) {
        $density = $entry.Key; $size = $entry.Value
        Save-Resized $bg $size (Join-Path $android "drawable-$density/ic_launcher_background.png")
        Save-Resized $fg $size (Join-Path $android "drawable-$density/ic_launcher_foreground.png")
    }
    foreach ($entry in @{ mdpi=96; hdpi=144; xhdpi=192; xxhdpi=288; xxxhdpi=384 }.GetEnumerator()) {
        Save-Resized $full $entry.Value (Join-Path $android "drawable-$($entry.Key)/launch_image.png")
    }

    $launch = Join-Path $ProjectRoot 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    Save-Resized $full 120 (Join-Path $launch 'LaunchImage.png')
    Save-Resized $full 240 (Join-Path $launch 'LaunchImage@2x.png')
    Save-Resized $full 360 (Join-Path $launch 'LaunchImage@3x.png')

    $appIcon = Join-Path $ProjectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    $manifest = Get-Content -Raw (Join-Path $appIcon 'Contents.json') | ConvertFrom-Json
    foreach ($image in $manifest.images) {
        if (!$image.filename) { continue }
        $points = [double](($image.size -split 'x')[0])
        $scale = [int]($image.scale -replace 'x', '')
        $px = [int][Math]::Round($points * $scale)
        Save-Resized $full $px (Join-Path $appIcon $image.filename)
    }
    Write-Output "Generated Aftermind icon set from $($full.Width)x$($full.Height) source; transparent-mark bounds $crop."
} finally {
    $fg.Dispose()
    $bg.Dispose()
    $bgGraphics.Dispose()
    $full.Dispose()
    $mark.Dispose()
}
