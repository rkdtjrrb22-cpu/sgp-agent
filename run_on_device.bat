@echo off
REM SGP-Agent 단말 배포 스크립트 — Studio 빌드 대신 Flutter로 직접 설치
set ANDROID_HOME=C:\Android\Sdk
set ANDROID_SDK_ROOT=C:\Android\Sdk
set PUB_CACHE=C:\PubCache
set PATH=%ANDROID_HOME%\platform-tools;%PATH%

cd /d "%~dp0"
echo === 연결 단말 확인 ===
adb devices -l
echo.
echo === SGP-Agent 빌드 및 설치 ===
flutter pub get
flutter run -d android
pause
