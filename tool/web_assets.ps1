# Faily bazy dlya brauzera v web/ (etap 5.2):
#   web/sqlite3.wasm    - SQLite v WebAssembly iz reliza paketa sqlite3 toy zhe
#                         versii, chto v pubspec.lock (sverka sha256 nizhe);
#   web/drift_worker.js - fonovyy obrabotchik drift, sobiraetsya iz
#                         tool/web/drift_worker.dart (versiya drift - iz lock).
# Zapuskat posle smeny versii sqlite3 ili drift. Rezultat hranitsya v git.
# Skript v ASCII: Windows PowerShell 5.1 chitaet UTF-8 bez BOM kak ANSI.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# sha256 sqlite3.wasm po versiyam paketa sqlite3 (dobavlyat pri obnovlenii,
# svereniy s relizom na GitHub).
$wasmSha256 = @{
    '3.5.1' = '13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4'
}

function Get-LockedVersion([string]$name) {
    $lock = Get-Content (Join-Path $root 'pubspec.lock') -Raw
    $m = [regex]::Match($lock, "(?ms)^  ${name}:\s*\n.*?^    version: `"([^`"]+)`"")
    if (-not $m.Success) { throw "Net paketa $name v pubspec.lock" }
    return $m.Groups[1].Value
}

$sqliteVersion = Get-LockedVersion 'sqlite3'
$driftVersion = Get-LockedVersion 'drift'
Write-Host "sqlite3 $sqliteVersion, drift $driftVersion"

$expected = $wasmSha256[$sqliteVersion]
if (-not $expected) {
    throw "Net kontrolnoy summy sqlite3.wasm dlya sqlite3 $sqliteVersion - dobavte v skript"
}

$wasm = Join-Path $root 'web\sqlite3.wasm'
$url = "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-$sqliteVersion/sqlite3.wasm"
$tmp = "$wasm.download"
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
$actual = (Get-FileHash $tmp -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) {
    Remove-Item $tmp
    throw "sqlite3.wasm: sha256 $actual, ozhidalos $expected"
}
Move-Item -Force $tmp $wasm
Write-Host "web/sqlite3.wasm: ok ($actual)"

$worker = Join-Path $root 'web\drift_worker.js'
& dart compile js -O4 -o $worker tool/web/drift_worker.dart
if ($LASTEXITCODE -ne 0) { throw 'Ne sobralsya drift_worker.js' }
Remove-Item -ErrorAction SilentlyContinue "$worker.deps", "$worker.map"
# Pometka versii - dlya proverki v testah (test/web_assets_test.dart).
Set-Content -Encoding ascii (Join-Path $root 'tool\web\drift_worker.version') $driftVersion
Write-Host "web/drift_worker.js: ok (drift $driftVersion)"
