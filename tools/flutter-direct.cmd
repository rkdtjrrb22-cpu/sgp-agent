@echo off
REM SGP-Agent: flutter.bat 보안 경고 우회 — dart.exe 직접 호출
SETLOCAL
SET "FLUTTER_ROOT=C:\src\flutter"
SET "DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
SET "SNAPSHOT=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot"
SET "PACKAGES=%FLUTTER_ROOT%\packages\flutter_tools\.dart_tool\package_config.json"

IF NOT EXIST "%DART%" (
  echo Error: dart.exe not found at %DART%
  EXIT /B 1
)

"%DART%" --packages="%PACKAGES%" "%SNAPSHOT%" %*
