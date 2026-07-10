# SGP-Agent - Windows flutter/dart.bat security warning fix
param(
    [switch]$SkipRegistry,
    [string]$FlutterRoot = $(if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT } else { 'C:\src\flutter' })
)

$ErrorActionPreference = 'Continue'
$projectRoot = Split-Path -Parent $PSScriptRoot

Write-Host '=== SGP-Agent Flutter security fix ===' -ForegroundColor Cyan
Write-Host "Flutter SDK: $FlutterRoot"
Write-Host ''

& (Join-Path $PSScriptRoot 'strip-zone-identifiers.ps1') -FlutterRoot $FlutterRoot -ProjectRoot $projectRoot

$dirs = @(
    (Join-Path $FlutterRoot 'bin'),
    (Join-Path $FlutterRoot 'bin\internal'),
    (Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin'),
    (Join-Path $FlutterRoot 'packages\flutter_tools'),
    (Join-Path $projectRoot 'android'),
    (Join-Path $projectRoot 'tools')
)
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Recurse -Include *.bat,*.cmd,*.exe,*.ps1 -ErrorAction SilentlyContinue |
        ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }
    Write-Host "[Unblock] $dir"
}

if (-not $SkipRegistry) {
    $lowRisk = Join-Path $PSScriptRoot 'add-lowrisk-bat.reg'
    $trusted = Join-Path $PSScriptRoot 'add-flutter-trusted-zone.reg'
    reg import $lowRisk 2>$null
    reg import $trusted 2>$null
    Write-Host '[Registry] LowRiskFileTypes + Trusted zone applied (HKCU)' -ForegroundColor Green
}

Write-Host ''
Write-Host '=== Android Studio (one-time) ===' -ForegroundColor Yellow
Write-Host 'Dart SDK:  C:\src\flutter\bin\cache\dart-sdk'
Write-Host 'Flutter SDK: C:\src\flutter'
Write-Host ''
Write-Host '=== If dialog still appears ===' -ForegroundColor Yellow
Write-Host 'Uncheck [Always ask] and click Run - once per bat file'
Write-Host ''
Write-Host '=== Run without security dialog / hidden cmd ===' -ForegroundColor Green
Write-Host '  cd C:\SGP-Agent'
Write-Host '  scripts\run-android.cmd          (visible console)'
Write-Host '  scripts\run-android.cmd --hidden (no cmd window)'
Write-Host '  tools\flutter-direct.cmd run -d R3CW203HFGK'
