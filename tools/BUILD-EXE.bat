@echo off
REM ============================================================================
REM  RailSim — railsim.exe ÝYGNAMAK / BUILD railsim.exe
REM
REM  Windows kompýuterinde bu faýla iki gezek basyň. Galanyny ozi edyar.
REM  On a Windows PC, double-click this file. It does the rest.
REM
REM  Gerek: internet (bir gezek) we ~10 GB boş ýer.
REM  Needs: internet (once) and about 10 GB of free space.
REM
REM  Ýygnalandan soň internet gerek däl. Netije islendik Windows-da işleýär.
REM  After the build, no internet is needed and the result runs on any Windows.
REM ============================================================================
setlocal
cd /d "%~dp0\.."

echo.
echo  RailSim - Windows .exe
echo  ======================
echo.

where flutter >nul 2>&1
if errorlevel 1 goto NOFLUTTER
goto HAVEFLUTTER

:NOFLUTTER
echo  Flutter tapylmady. Gurnalyar... / Flutter not found. Installing...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$dst='C:\flutter';" ^
  "if (-not (Test-Path $dst)) {" ^
  "  $zip=\"$env:TEMP\flutter.zip\";" ^
  "  Write-Host '  downloading Flutter SDK (about 1 GB)...';" ^
  "  Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.38.9-stable.zip' -OutFile $zip;" ^
  "  Write-Host '  unpacking...';" ^
  "  Expand-Archive -Path $zip -DestinationPath 'C:\' -Force;" ^
  "  Remove-Item $zip }" ^
  "$env:PATH=\"$dst\bin;$env:PATH\";" ^
  "[Environment]::SetEnvironmentVariable('PATH', \"$dst\bin;\" + [Environment]::GetEnvironmentVariable('PATH','User'), 'User')"
if errorlevel 1 goto FAILED
set "PATH=C:\flutter\bin;%PATH%"

:HAVEFLUTTER
echo.
echo  Visual Studio barlanyar... / Checking for the C++ compiler...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$vsw=\"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe\";" ^
  "$ok = (Test-Path $vsw) -and (& $vsw -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath);" ^
  "if ($ok) { exit 0 } else { exit 1 }"
if not errorlevel 1 goto BUILD

echo  C++ gurallary ýok. Gurnalyar (~5 GB, biraz wagt alar)...
echo  C++ build tools missing. Installing (about 5 GB, this takes a while)...
echo.
where winget >nul 2>&1
if errorlevel 1 goto NOWINGET
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --accept-source-agreements --accept-package-agreements ^
  --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
if errorlevel 1 goto FAILED
goto BUILD

:NOWINGET
echo.
echo  winget yok. Visual Studio 2022 Build Tools-y elde gurnan:
echo  winget is unavailable. Install Visual Studio 2022 Build Tools by hand:
echo    https://visualstudio.microsoft.com/downloads/
echo    -^> "Desktop development with C++"
echo.
goto END

:BUILD
echo.
echo  Yygnalyar... / Building...
echo.
call flutter config --enable-windows-desktop
call flutter pub get
if errorlevel 1 goto FAILED
call powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build_windows.ps1"
if errorlevel 1 goto FAILED

echo.
echo  ============================================================
echo   TAYYAR / DONE
echo.
echo   Bukja  / Folder : build\windows\x64\runner\Release\
echo   Bir fayl / One file : dist\RailSim-windows-x64.exe
echo   Ugratmak ucin / To send : dist\RailSim-windows-x64.zip
echo  ============================================================
echo.
goto END

:FAILED
echo.
echo  YALNYSLYK / FAILED. Yokardaky habary okan.
echo  Read the message above.
echo.

:END
pause
