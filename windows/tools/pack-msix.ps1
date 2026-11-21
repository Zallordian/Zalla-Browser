param(
    [Parameter(Mandatory = $true)][string]$PublishDir,
    [Parameter(Mandatory = $true)][string]$Output
)

$ErrorActionPreference = "Stop"

$publish = (Resolve-Path $PublishDir).Path
$outDir = Split-Path -Parent $Output
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
$out = [System.IO.Path]::GetFullPath($Output)

$layout = Join-Path ([System.IO.Path]::GetTempPath()) ("zalla-msix-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $layout | Out-Null

try {
    Copy-Item -Path (Join-Path $publish "*") -Destination $layout -Recurse -Force
    Get-ChildItem $layout -Recurse -File |
        Where-Object { $_.Extension -eq ".pdb" -or $_.Extension -eq ".xml" } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  IgnorableNamespaces="uap rescap">
  <Identity Name="Zalla.Browser" Publisher="CN=Zalla" Version="0.1.0.0" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>Zalla</DisplayName>
    <PublisherDisplayName>Zalla</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Resources>
    <Resource Language="en-US" />
  </Resources>
  <Applications>
    <Application Id="App" Executable="Zalla.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements
        DisplayName="Zalla"
        Description="Zalla for Windows"
        BackgroundColor="transparent"
        Square150x150Logo="Assets\Square150x150Logo.png"
        Square44x44Logo="Assets\Square44x44Logo.png">
        <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png" />
      </uap:VisualElements>
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
    <Capability Name="internetClient" />
  </Capabilities>
</Package>
'@

    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText((Join-Path $layout "AppxManifest.xml"), $manifest.Trim() + "`n", $utf8)

    $kits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits\10\bin"
    $make = Get-ChildItem -Path $kits -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\x64\\makeappx\.exe$' } |
        Sort-Object FullName -Descending |
        Select-Object -First 1
    if (-not $make) {
        throw "makeappx.exe was not found under $kits"
    }

    & $make.FullName pack /d $layout /p $out /o
    if ($LASTEXITCODE -ne 0) {
        throw "makeappx failed with exit code $LASTEXITCODE"
    }
    if (-not (Test-Path $out)) {
        throw "MSIX was not written."
    }
}
finally {
    if (Test-Path $layout) {
        Remove-Item -Recurse -Force $layout
    }
}
