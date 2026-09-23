$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$iconRoot = $PSScriptRoot
$projectRoot = [IO.Path]::GetFullPath((Join-Path $iconRoot '../../..'))
$catalog = Join-Path $projectRoot 'Zalla/Assets.xcassets'
$appSet = Join-Path $catalog 'AppIcon.appiconset'
$markSet = Join-Path $catalog 'ZallaMark.imageset'
foreach ($folder in @($appSet, $markSet, "$iconRoot/exports", "$iconRoot/iphone")) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}
function Write-JsonFile($path, $value) {
    [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 12) + "`n", [Text.UTF8Encoding]::new($false))
}
# Mechanical PNG sizing/encoding only; artwork was created with ImageGen.
function Export-Png($source, $destination, [int]$size, [bool]$alpha = $false) {
    $inputImage = [Drawing.Bitmap]::FromFile($source)
    $format = if ($alpha) { [Drawing.Imaging.PixelFormat]::Format32bppArgb } else { [Drawing.Imaging.PixelFormat]::Format24bppRgb }
    $outputImage = [Drawing.Bitmap]::new($size, $size, $format)
    $graphics = [Drawing.Graphics]::FromImage($outputImage)
    $attributes = [Drawing.Imaging.ImageAttributes]::new()
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $attributes.SetWrapMode([Drawing.Drawing2D.WrapMode]::TileFlipXY)
        $rect = [Drawing.Rectangle]::new(0, 0, $size, $size)
        $graphics.DrawImage($inputImage, $rect, 0, 0, $inputImage.Width, $inputImage.Height, [Drawing.GraphicsUnit]::Pixel, $attributes)
        $outputImage.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $attributes.Dispose(); $graphics.Dispose(); $outputImage.Dispose(); $inputImage.Dispose()
    }
}
$entries = @()
foreach ($appearance in @('default', 'dark', 'tinted')) {
    $filename = "zalla-$appearance-1024.png"
    Export-Png "$iconRoot/source/$appearance.png" "$appSet/$filename" 1024
    Copy-Item "$appSet/$filename" "$iconRoot/exports/$filename" -Force
    $entry = @{ filename = $filename; idiom = 'universal'; platform = 'ios'; size = '1024x1024' }
    if ($appearance -ne 'default') { $entry.appearances = @(@{ appearance = 'luminosity'; value = $appearance }) }
    $entries += $entry
}
Write-JsonFile "$catalog/Contents.json" @{ info = @{ author = 'xcode'; version = 1 } }
Write-JsonFile "$appSet/Contents.json" @{ images = $entries; info = @{ author = 'xcode'; version = 1 } }
Copy-Item "$appSet/zalla-default-1024.png" "$iconRoot/exports/zalla-app-store-1024.png" -Force
$sizes = @(
    @{ name = 'notification-20pt-2x'; pixels = 40 },
    @{ name = 'notification-20pt-3x'; pixels = 60 },
    @{ name = 'settings-29pt-2x'; pixels = 58 },
    @{ name = 'settings-29pt-3x'; pixels = 87 },
    @{ name = 'spotlight-40pt-2x'; pixels = 80 },
    @{ name = 'spotlight-40pt-3x'; pixels = 120 },
    @{ name = 'homescreen-60pt-2x'; pixels = 120 },
    @{ name = 'homescreen-60pt-3x'; pixels = 180 }
)
foreach ($item in $sizes) {
    Export-Png "$iconRoot/source/default.png" "$iconRoot/iphone/zalla-$($item.name).png" $item.pixels
}
Export-Png "$iconRoot/source/mark.png" "$iconRoot/exports/zalla-mark-transparent-1024.png" 1024 $true
$markEntries = @()
foreach ($scale in 1..3) {
    $filename = "zalla-mark-$($scale)x.png"
    Export-Png "$iconRoot/source/mark.png" "$markSet/$filename" (128 * $scale) $true
    $markEntries += @{ filename = $filename; idiom = 'universal'; scale = "$($scale)x" }
}
Write-JsonFile "$markSet/Contents.json" @{ images = $markEntries; info = @{ author = 'xcode'; version = 1 } }
Write-Output 'Exported 1024px icon appearances, App Store master, eight iPhone exports and transparent in-app images.'
