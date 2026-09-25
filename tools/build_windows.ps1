# Builds RailSim for Windows and packs it into ONE portable .exe.
#
# Run this on a Windows PC. The machine that RUNS the result needs nothing
# installed — no Flutter, no Visual Studio, no VC++ redistributable — because
# the Microsoft runtime DLLs are copied in beside the program.
#
#   powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1
#
# The build machine needs Flutter on PATH and Visual Studio 2022 with the
# "Desktop development with C++" workload (Community edition is free).
# `flutter doctor -v` must show Visual Studio as installed.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

Write-Host '== building ==' -ForegroundColor Cyan
flutter config --enable-windows-desktop | Out-Null
flutter pub get
flutter build windows --release

$release = 'build\windows\x64\runner\Release'
if (-not (Test-Path "$release\railsim.exe")) {
    throw "build produced no exe at $release"
}

# The Microsoft C runtime, copied in beside the program.
#
# A Flutter Windows app links the CRT dynamically, so without these it dies on
# startup on any PC that has never had Visual Studio or the VC++ redistributable
# installed — which is most of them. Copying them next to the exe is exactly
# what the redistributable licence allows, and it is the whole difference
# between "runs on the build machine" and "runs anywhere".
#
# The WHOLE folder, not a hand-picked three: VS2022 splits the runtime across
# msvcp140.dll, msvcp140_1.dll, msvcp140_2.dll, msvcp140_atomic_wait.dll,
# vcruntime140.dll, vcruntime140_1.dll and concrt140.dll, and which of them a
# given build touches depends on the plugins compiled in. Copying all of them
# costs about a megabyte and removes the guesswork.
Write-Host '== bundling the C runtime ==' -ForegroundColor Cyan
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsRoot = & $vswhere -latest -property installationPath
$crt = Get-ChildItem "$vsRoot\VC\Redist\MSVC\*\x64\Microsoft.VC*.CRT" -Directory |
       Sort-Object FullName -Descending | Select-Object -First 1
if (-not $crt) { throw "no VC redistributable found under $vsRoot" }
Copy-Item "$($crt.FullName)\*.dll" $release -Force
Write-Host "  from $($crt.FullName)"
Get-ChildItem $release -Filter '*140*.dll' | ForEach-Object { Write-Host "  + $($_.Name)" }

# A note for whoever receives the folder, because "just send railsim.exe" is
# the first thing everybody tries and it does not work: the program is an
# executable, its DLLs and a data\ tree, and it needs all three.
@"
RailSim — harby demir ýol ýükleme simulýatory

IŞLETMEK / TO RUN
  Bu bukjany doly göçüriň we railsim.exe faýlyny açyň.
  Copy this WHOLE folder, then run railsim.exe.

MÖHÜM / IMPORTANT
  railsim.exe faýlyny ýeke özi göçürmäň — işlemez.
  Do NOT copy railsim.exe on its own. It will not start without the
  .dll files and the data\ folder that sit beside it here.

  Hiç zat gurnamak gerek däl — Visual Studio hem, Flutter hem gerek däl.
  Nothing needs to be installed. No Visual Studio, no Flutter, no runtime.
"@ | Set-Content -Path (Join-Path $release 'READ ME - OKAŇ.txt') -Encoding UTF8

# The whole folder as one zip, which is what actually gets sent to somebody.
Write-Host '== zipping the folder ==' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path dist | Out-Null
$zipOut = 'dist\RailSim-windows-x64.zip'
if (Test-Path $zipOut) { Remove-Item $zipOut }
Compress-Archive -Path "$release\*" -DestinationPath $zipOut
Write-Host "  $zipOut ($([math]::Round((Get-Item $zipOut).Length/1MB)) MB)"

# One real .exe, built with IExpress — which has shipped inside Windows since
# XP, so the packing step needs nothing installed either. A .ps1 would have been
# fewer lines and is the wrong answer: Windows opens .ps1 in Notepad on a
# double-click, and the people who run this are not going to open a terminal.
Write-Host '== packing to a single exe ==' -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path dist | Out-Null

$stage = Join-Path $env:TEMP 'railsim-sfx'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

# IExpress flattens everything into one directory at run time, so the data/
# tree has to be carried as a zip and unpacked by the launcher.
Compress-Archive -Path "$release\*" -DestinationPath (Join-Path $stage 'app.zip')

@'
@echo off
set "DIR=%TEMP%\railsim-run"
rmdir /s /q "%DIR%" 2>nul
mkdir "%DIR%"
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Expand-Archive -LiteralPath '%~dp0app.zip' -DestinationPath '%DIR%' -Force"
start "" /wait "%DIR%\railsim.exe"
rmdir /s /q "%DIR%" 2>nul
'@ | Set-Content -Path (Join-Path $stage 'run.cmd') -Encoding ASCII

$sed = Join-Path $stage 'railsim.sed'
@"
[Version]
Class=IEXPRESS
SEDVersion=3
[Options]
PackagePurpose=InstallApp
ShowInstallProgramWindow=0
HideExtractAnimation=1
UseLongFileName=1
InsideCompressed=0
CAB_FixedSize=0
CAB_ResvCodeSigning=0
RebootMode=N
InstallPrompt=
DisplayLicense=
FinishMessage=
TargetName=$((Resolve-Path dist).Path)\RailSim-windows-x64.exe
FriendlyName=RailSim
AppLaunched=cmd /c run.cmd
PostInstallCmd=<None>
AdminQuietInstCmd=
UserQuietInstCmd=
SourceFiles=SourceFiles
[SourceFiles]
SourceFiles0=$stage
[SourceFiles0]
%FILE0%=
%FILE1%=
[Strings]
FILE0="app.zip"
FILE1="run.cmd"
"@ | Set-Content -Path $sed -Encoding ASCII

& "$env:SystemRoot\System32\iexpress.exe" /N /Q $sed
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ''
Write-Host "Portable folder : $release"  -ForegroundColor Green
Write-Host "Zip to send     : dist\RailSim-windows-x64.zip" -ForegroundColor Green
Write-Host "Single file     : dist\RailSim-windows-x64.exe" -ForegroundColor Green
Write-Host ''
Write-Host 'Ship either. Neither needs anything installed on the machine that'
Write-Host 'runs it — the Microsoft runtime DLLs are inside.'
