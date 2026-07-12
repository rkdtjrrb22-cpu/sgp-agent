@echo off
REM S8.2 — SM-S918N STT 파이프라인 adb 검증 (연결된 기기 1대)
setlocal
cd /d "%~dp0.."

where adb >nul 2>&1
if errorlevel 1 (
  echo ERROR: adb not found in PATH
  exit /b 1
)

for /f "tokens=*" %%D in ('adb devices ^| findstr /r "device$"') do set DEVICE=%%D
if not defined DEVICE (
  echo ERROR: No adb device connected
  adb devices
  exit /b 1
)

echo === SGP-Agent STT device validation ===
echo Device: %DEVICE%

echo.
echo [1] Package installed?
adb shell pm path com.sgp.sgp_agent
if errorlevel 1 (
  echo WARN: App not installed — run flutter run first
)

echo.
echo [2] Microphone / Bluetooth permissions (user-granted)
adb shell dumpsys package com.sgp.sgp_agent | findstr /i "RECORD_AUDIO BLUETOOTH"

echo.
echo [3] Whisper model path (optional)
adb shell run-as com.sgp.sgp_agent ls -la files/whisper/ 2>nul
if errorlevel 1 echo (no whisper dir — SpeechRecognizer fallback only)

echo.
echo [4] Logcat filter — launch app and tap STT, then watch:
echo     adb logcat -s sgp_whisper_jni SgpNativePlugin AudioRecord

echo.
echo Manual: open app on device, connect radio BT SCO, tap STT capture.
echo See docs\s8_stt_radio_validation.md for full checklist.
exit /b 0
