# Vykladka ustanovshika Windows na VPS (etap 6.5). Fail v ASCII.
#
#   .\server\deploy\publish_windows.ps1 -Installer installer_output\KFH_TimeTracking_Setup_1.7.0.exe [-Min 1.2.0]
#
# Kladet ustanovshik v /opt/kfh/downloads, pishet versiyu windows v
# versions.json (GET /client/version: url, sha256, razmer) i obnovlyaet
# stranicu https://<domen>/download/. Programma dlya Windows vidit novuyu
# versiyu i stavit ee sama (knopka "Ustanovit", sverka SHA-256).
# -Min - minimalnaya versiya: programmy starshe nee ne sinkhroniziruyutsya do
# obnovleniya (po umolchaniyu - prezhnyaya minimalnaya, a esli versii Windows
# eshche ne bylo - 1.2.0, pervaya s sinkhronizaciey: nikogo ne ostanavlivaem).
# Na servere khranyatsya 2 poslednikh ustanovshika. Versii Android i veb ne
# menyayutsya. Tolko s soglasiya vladelca.
param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [string]$Min = "",
    [string]$SshHost = "kfh",
    [string]$Domain = "tab.korovatech.ru"
)
$ErrorActionPreference = "Stop"
# ssh/scp pishut progress v stderr - v PowerShell 5.1 pri "Stop" eto
# oshibka posredi vykladki. Uspekh proveryaetsya po $LASTEXITCODE.
$nativeErrors = "Continue"
. (Join-Path $PSScriptRoot "download_page.ps1")

$path = (Resolve-Path $Installer).Path
$name = [System.IO.Path]::GetFileName($path)
if ($name -notmatch '^KFH_TimeTracking_Setup_(\d+\.\d+\.\d+)\.exe$') {
    throw "imya ustanovshika dolzhno byt KFH_TimeTracking_Setup_X.Y.Z.exe"
}
$version = $Matches[1]
$hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $path).Length

# Tekushchiy spisok versiy s servera (esli est).
$ErrorActionPreference = $nativeErrors
$current = ssh $SshHost "cat /opt/kfh/downloads/versions.json 2>/dev/null || echo '{""platforms"":{}}'"
if ($LASTEXITCODE -ne 0) { throw "ssh: oshibka" }
$ErrorActionPreference = "Stop"
$versions = ($current -join "`n") | ConvertFrom-Json
$platforms = @{}
foreach ($p in $versions.platforms.PSObject.Properties) { $platforms[$p.Name] = $p.Value }
$previous = $null
if ($platforms.ContainsKey('windows')) { $previous = $platforms['windows'] }
if ($Min -eq "") {
    $Min = "1.2.0"
    if ($previous) { $Min = $previous.min }
}
$platforms['windows'] = [ordered]@{
    latest = $version
    min    = $Min
    url    = "https://$Domain/download/$name"
    sha256 = $hash
    size   = $size
}
$json = @{ platforms = $platforms } | ConvertTo-Json -Depth 5
$html = New-DownloadPage $platforms $Domain

# Ostavit' na servere etot i predydushchiy ustanovshik.
$keep = @($name)
if ($previous -and $previous.url) {
    $keep += [System.IO.Path]::GetFileName(([Uri]$previous.url).AbsolutePath)
}

# Komandy dlya servera - otdel'nym sh-skriptom: kavychki v komandnoy stroke
# ssh iz PowerShell 5.1 nenadezhny. Snachala ustanovshik, potom spisok versiy:
# programma ne uvidit ssylku na fail, kotorogo net.
$sh = @"
set -e
install -d -m 755 /opt/kfh/downloads
install -m 644 /tmp/$name /opt/kfh/downloads/$name
install -m 644 /tmp/kfh-index.html /opt/kfh/downloads/index.html
install -m 644 /tmp/kfh-versions.json /opt/kfh/downloads/versions.json
rm -f /tmp/$name /tmp/kfh-index.html /tmp/kfh-versions.json
cd /opt/kfh/downloads
for f in KFH_TimeTracking_Setup_*.exe; do
  case " $($keep -join ' ') " in
    *" `$f "*) ;;
    *) rm -f -- "`$f" ;;
  esac
done
curl -fsS https://$Domain/client/version
"@

$tmp = Join-Path $env:TEMP "kfh-win"
[System.IO.Directory]::CreateDirectory($tmp) | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $tmp "kfh-versions.json"), $json, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tmp "kfh-index.html"), $html, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tmp "kfh-win.sh"), ($sh -replace "`r`n", "`n"), $utf8)

Write-Host "Windows $name ($([math]::Round($size / 1MB, 1)) MB), min $Min, sha256 $hash"
$ErrorActionPreference = $nativeErrors
scp -q $path (Join-Path $tmp "kfh-versions.json") (Join-Path $tmp "kfh-index.html") (Join-Path $tmp "kfh-win.sh") "${SshHost}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "scp: oshibka" }
# Proksi SSH s etogo PK inogda rvet soedinenie do sshd (kod 255) - togda
# povtor cherez pauzu; faily uzhe lezhat v /tmp.
for ($try = 1; $try -le 5; $try++) {
    ssh $SshHost "sh /tmp/kfh-win.sh; r=`$?; rm -f /tmp/kfh-win.sh; exit `$r"
    if ($LASTEXITCODE -ne 255) { break }
    Write-Host "ssh: soedinenie oborvano, povtor cherez 60 s ($try/5)"
    Start-Sleep -Seconds 60
}
if ($LASTEXITCODE -ne 0) { throw "vykladka ustanovshika ne udalas" }
foreach ($f in "kfh-versions.json", "kfh-index.html", "kfh-win.sh") {
    [System.IO.File]::Delete((Join-Path $tmp $f))
}
Write-Host ""
Write-Host "Gotovo: https://$Domain/download/"
