@echo off
REM SGP-Agent — 릴리즈 APK (Tree Shaking + Obfuscation)
setlocal
cd /d "%~dp0.."

echo === SGP-Agent release build (obfuscate) ===
call tools\flutter-direct.cmd pub get
if errorlevel 1 exit /b 1

if not exist "build\debug-info" mkdir "build\debug-info"

call tools\flutter-direct.cmd build apk --release --obfuscate --split-debug-info=build/debug-info
if errorlevel 1 exit /b 1

echo.
echo OK — release APK built with obfuscation.
echo Debug symbols: build\debug-info
echo APK: build\app\outputs\flutter-apk\app-release.apk
exit /b 0
