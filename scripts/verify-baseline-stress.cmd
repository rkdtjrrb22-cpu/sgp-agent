@echo off
REM SGP-Agent 하이브리드 v2 베이스라인 스트레스 검증
setlocal
cd /d "%~dp0\.."

echo === Hybrid forensic KPI ===
call dart test test/features/control/sgp_amdahl_gunter_forensic_test.dart
if errorlevel 1 exit /b 1

echo === Hybrid v2 KPI ===
call dart test test/features/control/sgp_hybrid_v2_kpi_test.dart
if errorlevel 1 exit /b 1

echo === Baseline stress (shadow / peak load) ===
call dart test test/features/control/sgp_baseline_stress_test.dart
if errorlevel 1 exit /b 1

echo.
echo All baseline stress suites PASSED.
exit /b 0
