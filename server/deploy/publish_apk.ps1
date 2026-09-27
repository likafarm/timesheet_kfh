# Vykladka APK dlya telefona operatora na VPS (etap 4.8). Fail v ASCII.
#
#   .\server\deploy\publish_apk.ps1 -Apk installer_output\kfh-1.3.0.apk [-Min 1.3.0]
#
# Kladet APK v /opt/kfh/downloads, pishet tam versions.json (ego otdaet
# GET /client/version) i index.html (stranica https://<domen>/download/).
# -Min - minimalnaya versiya: programmy starshe nee pokazyvayut ekran
# "obnovite programmu" (po umolchaniyu - prezhnyaya minimalnaya ili eta zhe).
# Versiya Windows v versions.json sokhranyaetsya kak byla.
# Tolko s soglasiya vladelca.
param(
    [Parameter(Mandatory = $true)][string]$Apk,
    [string]$Min = "",
    [string]$SshHost = "kfh",
    [string]$Domain = "tab.korovatech.ru"
)
$ErrorActionPreference = "Stop"

$root = git rev-parse --show-toplevel
if (-not $?) { throw "ne git-repozitoriy" }
Set-Location $root

$apkPath = (Resolve-Path $Apk).Path
$name = [System.IO.Path]::GetFileName($apkPath)
if ($name -notmatch '^kfh-(\d+\.\d+\.\d+)\.apk$') { throw "imya APK dolzhno byt kfh-X.Y.Z.apk" }
$version = $Matches[1]
$hash = (Get-FileHash $apkPath -Algorithm SHA256).Hash.ToLower()
$sizeMb = [math]::Round((Get-Item $apkPath).Length / 1MB, 1)

# Tekushchiy spisok versiy s servera (esli est).
$current = ssh $SshHost "cat /opt/kfh/downloads/versions.json 2>/dev/null || echo '{""platforms"":{}}'"
if ($LASTEXITCODE -ne 0) { throw "ssh: oshibka" }
$versions = ($current -join "`n") | ConvertFrom-Json
$platforms = @{}
foreach ($p in $versions.platforms.PSObject.Properties) { $platforms[$p.Name] = $p.Value }
if ($Min -eq "") {
    $Min = $version
    if ($platforms.ContainsKey('android')) { $Min = $platforms['android'].min }
}
$platforms['android'] = [ordered]@{
    latest = $version
    min    = $Min
    url    = "https://$Domain/download/$name"
    sha256 = $hash
}
$json = @{ platforms = $platforms } | ConvertTo-Json -Depth 5

$html = @"
<!DOCTYPE html>
<html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Tabel KFH</title>
<style>body{font-family:sans-serif;max-width:32rem;margin:2rem auto;padding:0 1rem;color:#212121}
a.btn{display:block;background:#2E7D32;color:#fff;text-align:center;padding:1rem;border-radius:8px;
text-decoration:none;font-size:1.2rem}code{word-break:break-all;font-size:.8rem}</style></head>
<body><h1>&#1058;&#1072;&#1073;&#1077;&#1083;&#1100; &#1050;&#1060;&#1061;</h1>
<p>&#1055;&#1088;&#1086;&#1075;&#1088;&#1072;&#1084;&#1084;&#1072; &#1076;&#1083;&#1103; &#1090;&#1077;&#1083;&#1077;&#1092;&#1086;&#1085;&#1072; &#1086;&#1087;&#1077;&#1088;&#1072;&#1090;&#1086;&#1088;&#1072; (Android), &#1074;&#1077;&#1088;&#1089;&#1080;&#1103; $version, $sizeMb &#1052;&#1041;.</p>
<p><a class="btn" href="$name">&#1057;&#1082;&#1072;&#1095;&#1072;&#1090;&#1100; $name</a></p>
<p>SHA-256: <code>$hash</code></p>
</body></html>
"@

$tmp = Join-Path $env:TEMP "kfh-apk"
[System.IO.Directory]::CreateDirectory($tmp) | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $tmp "versions.json"), $json, $utf8)
[System.IO.File]::WriteAllText((Join-Path $tmp "index.html"), $html, $utf8)

Write-Host "APK $name ($sizeMb MB), min $Min, sha256 $hash"
scp -q $apkPath (Join-Path $tmp "versions.json") (Join-Path $tmp "index.html") "${SshHost}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "scp: oshibka" }
# Snachala APK, potom spisok versiy: programma ne uvidit ssylku na fail, kotorogo net.
ssh $SshHost "set -e; install -d -m 755 /opt/kfh/downloads; install -m 644 /tmp/$name /opt/kfh/downloads/$name; install -m 644 /tmp/index.html /opt/kfh/downloads/index.html; install -m 644 /tmp/versions.json /opt/kfh/downloads/versions.json; rm -f /tmp/$name /tmp/index.html /tmp/versions.json; curl -fsS https://$Domain/client/version"
if ($LASTEXITCODE -ne 0) { throw "vykladka APK ne udalas" }
Write-Host ""
Write-Host "Gotovo: https://$Domain/download/"
