# Vykladka instrukciy PDF na stranicu https://<domen>/download/ (shag 4
# "Dalneyshikh rabot"). Fail v ASCII.
#
#   $env:KFH_HELP_PDF="installer_output"; flutter test test/help/help_pdf_test.dart
#   .\server\deploy\publish_help.ps1 [-Dir installer_output]
#
# Kladet instrukcii v /opt/kfh/downloads. Ssylki na nikh uzhe est na
# stranice (download_page.ps1) - ona obnovlyaetsya pri vykladke Windows ili
# APK. Tolko s soglasiya vladelca.
param(
    [string]$Dir = "installer_output",
    [string]$SshHost = "kfh",
    [string]$Domain = "tab.korovatech.ru"
)
$ErrorActionPreference = "Stop"
$root = git rev-parse --show-toplevel
if (-not $?) { throw "ne git-repozitoriy" }
Set-Location $root

$names = @("instrukciya-operator.pdf", "instrukciya-buhgalter.pdf", "instrukciya-administrator.pdf")
$files = @()
foreach ($n in $names) {
    $path = Join-Path $Dir $n
    if (-not (Test-Path $path)) { throw "net $path - snachala sobrat PDF (sm. vyshe)" }
    $files += (Resolve-Path $path).Path
}
$ErrorActionPreference = "Continue"
scp -q @files "${SshHost}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "scp: oshibka" }
$install = ($names | ForEach-Object { "install -m 644 /tmp/$_ /opt/kfh/downloads/$_; rm -f /tmp/$_" }) -join "; "
ssh $SshHost "set -e; install -d -m 755 /opt/kfh/downloads; $install"
if ($LASTEXITCODE -ne 0) { throw "vykladka instrukciy ne udalas" }
foreach ($n in $names) {
    $r = Invoke-WebRequest -UseBasicParsing -Method Head "https://$Domain/download/$n"
    Write-Host "$n : $($r.StatusCode), $($r.Headers['Content-Length']) bayt"
}
Write-Host "Gotovo: https://$Domain/download/"
