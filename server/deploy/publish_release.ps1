# Vykladka vypuska celikom (Windows PowerShell 5.1). Fail v ASCII:
# PowerShell 5.1 chitaet UTF-8 bez BOM kak ANSI.
#
#   .\server\deploy\publish_release.ps1                 # iz kornya repozitoriya
#   .\server\deploy\publish_release.ps1 -From web       # prodolzhit s shaga
#
# Poryadok (snachala server, potom programmy):
#   server   - publish.ps1 (kopiya bazy -> migracii -> zapusk -> /health)
#   web      - publish_web.ps1 -SkipBuild (gotovaya build\web)
#   windows  - publish_windows.ps1 (installer_output\KFH_TimeTracking_Setup_<ver>.exe)
#   android  - publish_apk.ps1 (installer_output\kfh-<ver>.apk)
#   help     - publish_help.ps1 (installer_output\instrukciya-*.pdf)
#
# Vse fayly sobirayutsya ZARANEE (sm. CLAUDE.md, razdel "Komandy"); skript
# tolko proveryaet, chto oni est i chto versiya exe sovpadaet s pubspec.yaml.
# SSH s etogo PK inogda rvetsya ("Connection closed") - pri oshibke shaga
# skript sprashivaet, povtorit li ego (shagi mozhno povtoryat).
# Minimalnye versii: veb - eta zhe versiya; Windows i Android - prezhnie.
param(
    [ValidateSet("server", "web", "windows", "android", "help")]
    [string]$From = "server",
    [string]$SshHost = "kfh",
    [string]$Domain = "tab.korovatech.ru"
)
$ErrorActionPreference = "Stop"

$root = git rev-parse --show-toplevel
if (-not $?) { throw "ne git-repozitoriy" }
Set-Location $root

$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)')
if (-not $m.Success) { throw "net versii v pubspec.yaml" }
$version = $m.Groups[1].Value
$serverPubspec = Get-Content (Join-Path $root 'server\pubspec.yaml') -Raw
$serverVersion = [regex]::Match($serverPubspec, '(?m)^version:\s*(\S+)').Groups[1].Value

$installer = "installer_output\KFH_TimeTracking_Setup_$version.exe"
$apk = "installer_output\kfh-$version.apk"
$exe = "build\windows\x64\runner\Release\timesheet_kfh.exe"
$help = @("instrukciya-operator.pdf", "instrukciya-buhgalter.pdf", "instrukciya-administrator.pdf", "instrukciya-prodazhi.pdf")

# --- proverka gotovykh faylov -------------------------------------------
$problems = @()
if (-not (Test-Path "build\web\index.html")) { $problems += "net build\web - flutter build web --release --base-href /app/ --no-web-resources-cdn --no-source-maps" }
if (-not (Test-Path $installer)) { $problems += "net $installer" }
if (-not (Test-Path $apk)) { $problems += "net $apk - .\build_apk.ps1" }
foreach ($h in $help) {
    if (-not (Test-Path "installer_output\$h")) { $problems += "net installer_output\$h" }
}
if (Test-Path $exe) {
    $exeVersion = (Get-Item $exe).VersionInfo.ProductVersion
    if (-not $exeVersion.StartsWith($version)) { $problems += "exe $exeVersion, a v pubspec.yaml $version - peresobrat Windows" }
}
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    throw "ne vse fayly vypuska gotovy"
}

Write-Host "Vypusk: server $serverVersion, programmy $version (veb, Windows, Android)" -ForegroundColor Cyan
Write-Host "  $installer"
Write-Host "  $apk"
$answer = Read-Host "Vykladyvat na $Domain s shaga '$From'? (da/net)"
if ($answer -notin @("da", "d", "y", "yes")) { Write-Host "Otmeneno."; exit 1 }

# --- shagi ----------------------------------------------------------------
$steps = [ordered]@{
    server  = { & "$root\server\deploy\publish.ps1" -SshHost $SshHost }
    web     = { & "$root\server\deploy\publish_web.ps1" -SkipBuild -SshHost $SshHost -Domain $Domain }
    windows = { & "$root\server\deploy\publish_windows.ps1" -Installer $installer -SshHost $SshHost -Domain $Domain }
    android = { & "$root\server\deploy\publish_apk.ps1" -Apk $apk -SshHost $SshHost -Domain $Domain }
    help    = { & "$root\server\deploy\publish_help.ps1" -SshHost $SshHost -Domain $Domain }
}

$started = $false
foreach ($name in $steps.Keys) {
    if ($name -eq $From) { $started = $true }
    if (-not $started) { continue }
    while ($true) {
        Write-Host ""
        Write-Host "=== $name ===" -ForegroundColor Cyan
        try {
            & $steps[$name]
            break
        } catch {
            Write-Host "Shag '$name' ne udalsya: $($_.Exception.Message)" -ForegroundColor Red
            $again = Read-Host "Povtorit shag '$name'? (da - povtorit, net - ostanovitsya)"
            if ($again -notin @("da", "d", "y", "yes")) {
                Write-Host "Ostanovleno. Prodolzhit potom: .\server\deploy\publish_release.ps1 -From $name" -ForegroundColor Yellow
                exit 1
            }
        }
    }
}

# --- itog -----------------------------------------------------------------
Write-Host ""
$health = Invoke-RestMethod "https://$Domain/health"
Write-Host "Server: $($health.version), baza: $($health.db)"
$versions = Invoke-RestMethod "https://$Domain/client/version"
Write-Host "Versii programm na servere: $($versions | ConvertTo-Json -Compress -Depth 4)"
if ($health.version -ne $serverVersion) {
    Write-Host "Vnimanie: server otvechaet $($health.version), ozhidalas $serverVersion" -ForegroundColor Yellow
}
Write-Host "Gotovo: https://$Domain/download/ , veb - https://$Domain/app/" -ForegroundColor Green
