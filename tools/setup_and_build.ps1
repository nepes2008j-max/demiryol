# Installs what a Windows build needs, then builds railsim.exe.
#
# Called by BUILD-EXE.bat. Kept as its own .ps1 on purpose: the previous
# version inlined all of this into the .bat with caret continuations and
# escaped quotes, which cmd mangles in ways that are painful to predict and
# impossible to test from the Linux machine this was written on. A plain script
# file has none of that.
#
# Needs internet once. After the build, nothing needs internet and nothing
# needs installing on the machines that run the result.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$FlutterVersion = '3.38.9'      # the version this project is developed against
$FlutterRoot    = 'C:\flutter'

function Say($text) { Write-Host "  $text" -ForegroundColor Cyan }

# ---------------------------------------------------------------- Flutter ---
if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Say 'Flutter: already installed'
} elseif (Test-Path "$FlutterRoot\bin\flutter.bat") {
    Say 'Flutter: found at C:\flutter'
    $env:PATH = "$FlutterRoot\bin;$env:PATH"
} else {
    Say "Flutter: downloading $FlutterVersion (about 1 GB, this takes a while)"
    $zip = Join-Path $env:TEMP 'flutter.zip'
    $url = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FlutterVersion-stable.zip"
    # Invoke-WebRequest's progress bar makes a 1 GB download roughly three
    # times slower in Windows PowerShell. Off.
    $oldPref = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $zip
    $ProgressPreference = $oldPref

    Say 'Flutter: unpacking'
    Expand-Archive -Path $zip -DestinationPath 'C:\' -Force
    Remove-Item $zip

    $env:PATH = "$FlutterRoot\bin;$env:PATH"
    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*$FlutterRoot\bin*") {
        [Environment]::SetEnvironmentVariable('PATH', "$FlutterRoot\bin;$userPath", 'User')
    }
}

# ------------------------------------------------------ C++ build tools ---
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$haveCpp = $false
if (Test-Path $vswhere) {
    $found = & $vswhere -latest -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath
    $haveCpp = [bool]$found
}

if ($haveCpp) {
    Say 'C++ build tools: already installed'
} else {
    Say 'C++ build tools: installing (about 5 GB, this takes a while)'
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw @'
winget is not available on this PC, so the C++ tools cannot be installed
automatically. Install them by hand:

  https://visualstudio.microsoft.com/downloads/
  -> Tools for Visual Studio -> Build Tools for Visual Studio 2022
  -> tick "Desktop development with C++"

Then run this script again.
'@
    }
    winget install --id Microsoft.VisualStudio.2022.BuildTools -e `
        --accept-source-agreements --accept-package-agreements `
        --override '--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
    if ($LASTEXITCODE -ne 0) { throw "winget failed with exit code $LASTEXITCODE" }
}

# ------------------------------------------------------------------ build ---
Say 'Building'
flutter config --enable-windows-desktop | Out-Null
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

& (Join-Path $PSScriptRoot 'build_windows.ps1')
if ($LASTEXITCODE -ne 0) { throw 'the Windows build failed' }
