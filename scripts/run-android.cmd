@echo off
REM Android Studio Run 대신 사용 — flutter.bat / cmd 보안창 우회
cd /d "%~dp0.."
if "%1"=="--hidden" (
  start "" wscript.exe "%~dp0flutter-run-hidden.vbs"
  exit /b 0
)
call tools\flutter-direct.cmd run -d R3CW203HFGK %*
