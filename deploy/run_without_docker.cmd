@echo off
REM SGP-Agent — Docker 없이 참조 서버·법령 Cron 오프라인 스텁 검증 (Windows)
setlocal
cd /d "%~dp0.."

echo === SGP-Agent offline stub verify (no Docker) ===
echo LAW_SYNC_REQUIRE_LIVE_KEY=false (default stub mode)
echo.

set LAW_SYNC_REQUIRE_LIVE_KEY=false
set SEED_PATH=assets/data/legal_hierarchy_seed.json

echo [1/3] Production env validate...
dart run deploy/validate_production_env.dart
if errorlevel 1 goto :fail

echo.
echo [2/3] Law sync cron (offline stub)...
dart run tool/cron/sync_law_nodes_production.dart
if errorlevel 1 goto :fail

echo.
echo [3/3] Reference server smoke (5s)...
start /B dart run bin/quantum_legal_server.dart
timeout /t 3 /nobreak >nul
curl -s http://127.0.0.1:8080/health
if errorlevel 1 (
  echo WARN: curl health check failed — server may still be starting
) else (
  echo OK — /health responded
)

echo.
echo === Offline stub verify complete ===
echo To run server manually: dart run bin/quantum_legal_server.dart
goto :eof

:fail
echo FATAL: step failed
exit /b 1
