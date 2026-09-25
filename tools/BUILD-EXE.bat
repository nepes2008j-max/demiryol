@echo off
REM ===========================================================================
REM  RailSim - railsim.exe YYGNAMAK / BUILD railsim.exe
REM
REM  Windows kompyuterinde bu fayla iki gezek basyn.
REM  On a Windows PC, double-click this file.
REM
REM  Gerek: internet (bir gezek), ~10 GB bos yer.
REM  Needs: internet (once) and about 10 GB of free space.
REM
REM  Yygnalandan son netije islendik Windows-da isleyar - hic zat gurnamak
REM  gerek dal. Once built, the result runs on any Windows with nothing
REM  installed.
REM ===========================================================================
setlocal

echo.
echo   RailSim - Windows .exe
echo   ======================
echo.

REM All the real work is in setup_and_build.ps1. Keeping it there rather than
REM inline means no caret continuations and no escaped quotes for cmd to mangle.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_and_build.ps1"

if errorlevel 1 goto FAILED

echo.
echo   ============================================================
echo    TAYYAR / DONE
echo.
echo    Bukja       / Folder  : build\windows\x64\runner\Release\
echo    Bir fayl    / One file: dist\RailSim-windows-x64.exe
echo    Ugratmak uc / To send : dist\RailSim-windows-x64.zip
echo.
echo    MOHUM: railsim.exe yeke ozi islemeyar - bukjany doly gocurin.
echo    IMPORTANT: railsim.exe alone will not run. Copy the WHOLE folder.
echo   ============================================================
echo.
goto END

:FAILED
echo.
echo   YALNYSLYK / FAILED - yokardaky habary okan / read the message above.
echo.

:END
pause
