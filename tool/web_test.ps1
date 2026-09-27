# Test bazy v brauzere (packages/local_db/test/browser, Chrome): kopiruet
# web/sqlite3.wasm i web/drift_worker.js v papku testa (server testov
# otdaet tolko papku paketa) i zapuskaet dart test -p chrome.
# Skript v ASCII: Windows PowerShell 5.1 chitaet UTF-8 bez BOM kak ANSI.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pkg = Join-Path $root 'packages\local_db'
$assets = Join-Path $pkg 'test\browser\assets'
New-Item -ItemType Directory -Force $assets | Out-Null
Copy-Item (Join-Path $root 'web\sqlite3.wasm') $assets -Force
Copy-Item (Join-Path $root 'web\drift_worker.js') $assets -Force
Set-Location $pkg
& dart test -p chrome test/browser
exit $LASTEXITCODE
