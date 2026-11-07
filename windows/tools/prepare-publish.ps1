param(
    [Parameter(Mandatory = $true)][string]$PublishDir
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path $PublishDir).Path

$pri = Join-Path $root "Zalla.pri"
if (-not (Test-Path -LiteralPath $pri)) {
    throw "Zalla.pri was not published. Unpackaged WinUI cannot load its styles without it."
}

Copy-Item -LiteralPath $pri -Destination (Join-Path $root "resources.pri") -Force

$required = @(
    "Zalla.exe",
    "Zalla.dll",
    "Zalla.pri",
    "resources.pri",
    "Microsoft.WindowsAppRuntime.dll",
    "Microsoft.ui.xaml.dll",
    "Microsoft.UI.Xaml.Controls.dll",
    "Microsoft.UI.Xaml.Controls.pri",
    "MRM.dll",
    "Microsoft.WinUI.dll",
    "WebView2Loader.dll"
)

foreach ($name in $required) {
    $path = Join-Path $root $name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Published app is missing $name"
    }
}

$nested = Get-ChildItem -LiteralPath $root -Recurse -File -Filter *.zip
if ($nested) {
    throw "The publish folder contains a zip. The downloadable artifact must be the app files themselves."
}

Write-Host "Publish folder is ready: $root"
