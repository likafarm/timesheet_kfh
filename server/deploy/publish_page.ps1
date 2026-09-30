# Perestroit tolko stranicu https://<domen>/download/ po tekushchemu
# versions.json na servere (bez vykladki novykh faylov). Fail v ASCII.
#
#   .\server\deploy\publish_page.ps1
#
# Tolko s soglasiya vladelca.
param(
    [string]$SshHost = "kfh",
    [string]$Domain = "tab.korovatech.ru"
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "download_page.ps1")

$current = ssh $SshHost "cat /opt/kfh/downloads/versions.json"
if ($LASTEXITCODE -ne 0) { throw "ssh: oshibka" }
$versions = ($current -join "`n") | ConvertFrom-Json
$platforms = @{}
foreach ($p in $versions.platforms.PSObject.Properties) { $platforms[$p.Name] = $p.Value }
$html = New-DownloadPage $platforms $Domain

$tmp = Join-Path $env:TEMP "kfh-page"
[System.IO.Directory]::CreateDirectory($tmp) | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $tmp "index.html"), $html, $utf8)
$ErrorActionPreference = "Continue"
scp -q (Join-Path $tmp "index.html") "${SshHost}:/tmp/kfh-index.html"
if ($LASTEXITCODE -ne 0) { throw "scp: oshibka" }
ssh $SshHost "set -e; install -m 644 /tmp/kfh-index.html /opt/kfh/downloads/index.html; rm -f /tmp/kfh-index.html"
if ($LASTEXITCODE -ne 0) { throw "vykladka stranicy ne udalas" }
Write-Host "Gotovo: https://$Domain/download/"
