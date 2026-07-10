# Remove Zone.Identifier from Flutter/SDK batch files only (fast, safe)
param(
    [string]$FlutterRoot = $(if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT } else { 'C:\src\flutter' }),
    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$removed = 0
$targets = @(
    (Join-Path $FlutterRoot 'bin\*.bat'),
    (Join-Path $FlutterRoot 'bin\internal\*.bat'),
    (Join-Path $ProjectRoot 'android\gradlew.bat'),
    (Join-Path $ProjectRoot 'tools\*.cmd')
)

foreach ($pattern in $targets) {
    $parent = Split-Path $pattern -Parent
    $filter = Split-Path $pattern -Leaf
    if (-not (Test-Path $parent)) { continue }
    Get-ChildItem -Path $parent -Filter $filter -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $stream = Get-Item -LiteralPath $_.FullName -Stream 'Zone.Identifier' -ErrorAction Stop
            $stream | Remove-Item -Force
            $script:removed++
        } catch {
            # no zone stream
        }
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }
}

Write-Host "Zone.Identifier removed from $removed batch/cmd files"
