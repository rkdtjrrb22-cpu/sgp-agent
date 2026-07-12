@echo off
REM SGP-Agent — 크로스 플랫폼 무결성 검증 (Windows: Android + analyze, iOS는 macOS에서 verify-ios-build.sh)
setlocal
cd /d "%~dp0.."

echo === SGP-Agent cross-platform verify ===
call tools\flutter-direct.cmd pub get
if errorlevel 1 exit /b 1

echo.
echo [1/3] dart analyze lib bin tool/cron deploy
dart analyze lib bin tool/cron deploy
if errorlevel 1 exit /b 1

echo.
echo [2/3] dart test (agent core + demo stub)
dart test test\features\agent\sgp_legal_hierarchy_test.dart test\features\agent\sgp_legal_ontology_test.dart test\features\agent\sgp_npa_iam_jwt_test.dart test\features\agent\sgp_npa_iam_jwks_test.dart test\features\agent\sgp_npa_iam_client_test.dart test\features\agent\sgp_demo_field_scenario_test.dart test\features\agent\sgp_legal_ontology_session_test.dart test\features\agent\sgp_production_config_test.dart
if errorlevel 1 exit /b 1

echo.
echo [3/3] Android debug APK
call tools\flutter-direct.cmd build apk --debug
if errorlevel 1 exit /b 1

echo.
echo OK — Android + Dart checks passed.
echo iOS: macOS에서 scripts/verify-ios-build.sh 실행 (flutter build ios --no-codesign)
exit /b 0
