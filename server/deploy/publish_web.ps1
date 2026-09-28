# Vykladka veb-versii na VPS (etap 5.5). Fail v ASCII.
#
#   .\server\deploy\publish_web.ps1 [-Min 1.4.0] [-SkipBuild]
#
# Sobiraet veb-versiyu (flutter build web, adres /app/, CanvasKit iz sborki),
# kladet ee v /opt/kfh/web/releases/<vremya>-<versiya> i pereklyuchaet ssylku
# /opt/kfh/web/app celikom (otkrytye vkladki dogruzhayut staruyu versiyu do
# obnovleniya stranicy). Hranyatsya 3 poslednih vypuska. Zatem pishet versiyu
# web v /opt/kfh/downloads/versions.json (GET /client/version): -Min -
# minimalnaya versiya (po umolchaniyu - eta zhe: otkrytye vkladki staroy
# versii prosyat obnovit stranicu). Versii Windows i Android ne menyayutsya.
# Nuzhen Caddyfile s /app/ (server 0.3.0). Tolko s soglasiya vladelca.
param(
    [string]$Min = "",
    [switch]$SkipBuild,
    [string]$SshHost = "kfh",
    [string]$Domain = "tab.korovatech.ru"
)
$ErrorActionPreference = "Stop"
# ssh/scp/flutter pishut progress v stderr - v PowerShell 5.1 pri "Stop" eto
# oshibka posredi vykladki. Uspekh proveryaetsya po $LASTEXITCODE.
$nativeErrors = "Continue"

$root = git rev-parse --show-toplevel
if (-not $?) { throw "ne git-repozitoriy" }
Set-Location $root

$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw
$m = [regex]::Match($pubspec, '(?m)^version:\s*(\d+\.\d+\.\d+)')
if (-not $m.Success) { throw "net versii v pubspec.yaml" }
$version = $m.Groups[1].Value
if ($Min -eq "") { $Min = $version }

$web = Join-Path $root 'build\web'
if (-not $SkipBuild) {
    Write-Host "Sborka veb-versii $version..."
    $ErrorActionPreference = $nativeErrors
    & flutter build web --release --base-href /app/ --no-web-resources-cdn --no-source-maps | Select-Object -Last 3
    $code = $LASTEXITCODE
    $ErrorActionPreference = "Stop"
    if ($code -ne 0) { throw "flutter build web: oshibka" }
}
$built = (Get-Content (Join-Path $web 'version.json') -Raw | ConvertFrom-Json).version
if ($built -ne $version) { throw "v build\web versiya $built, a v pubspec.yaml $version - soberite zanovo" }
if ((Get-Content (Join-Path $web 'index.html') -Raw) -notmatch '<base href="/app/">') {
    throw "build\web sobran ne dlya adresa /app/ - soberite bez -SkipBuild"
}

# Tekushchiy spisok versiy s servera (esli est).
$ErrorActionPreference = $nativeErrors
$current = ssh $SshHost "cat /opt/kfh/downloads/versions.json 2>/dev/null || echo '{""platforms"":{}}'"
$code = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($code -ne 0) { throw "ssh: oshibka" }
$versions = ($current -join "`n") | ConvertFrom-Json
$platforms = [ordered]@{}
foreach ($p in $versions.platforms.PSObject.Properties) { $platforms[$p.Name] = $p.Value }
$platforms['web'] = [ordered]@{
    latest = $version
    min    = $Min
    url    = "https://$Domain/app/"
}
$json = @{ platforms = $platforms } | ConvertTo-Json -Depth 5

$tmp = Join-Path $env:TEMP "kfh-web"
# Remove-Item v PS 5.1 ne ponimaet korotkie imena (3C8A~1).
if ([System.IO.Directory]::Exists($tmp)) { [System.IO.Directory]::Delete($tmp, $true) }
[System.IO.Directory]::CreateDirectory($tmp) | Out-Null
$archive = Join-Path $tmp "kfh-web.tgz"
# *.symbols - otladochnye simvoly CanvasKit, na servere ne nuzhny.
& tar -czf $archive -C $web --exclude "*.symbols" .
if ($LASTEXITCODE -ne 0) { throw "tar: oshibka" }
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Join-Path $tmp "versions.json"), $json, $utf8)
$sizeMb = [math]::Round((Get-Item $archive).Length / 1MB, 1)
Write-Host "Veb-versiya $version ($sizeMb MB v arkhive), min $Min"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
# Imya vypuska nachinaetsya so vremeni: po imeni vypuski i sortiruyutsya
# (vremya izmeneniya papok tar beret iz arkhiva).
$release = "$stamp-$version"
$ErrorActionPreference = $nativeErrors
scp -q $archive (Join-Path $tmp "versions.json") "${SshHost}:/tmp/"
if ($LASTEXITCODE -ne 0) { throw "scp: oshibka" }
# Snachala faily i ssylka, potom spisok versiy: programma ne poprosit
# obnovitsya do versii, kotoroy eshche net na servere.
$remote = @(
    "set -e",
    "W=/opt/kfh/web",
    "install -d -m 755 `$W/releases",
    "D=`$W/releases/$release",
    "mkdir `$D",
    "tar -xzf /tmp/kfh-web.tgz -C `$D",
    "chmod -R a+rX `$D",
    "test -f `$D/index.html",
    "ln -sfn releases/$release `$W/app.new",
    "mv -T `$W/app.new `$W/app",
    "cd `$W/releases && ls -1 | sort | head -n -3 | grep -vx '$release' | xargs -r rm -rf",
    "install -m 644 /tmp/versions.json /opt/kfh/downloads/versions.json",
    "rm -f /tmp/kfh-web.tgz /tmp/versions.json",
    "curl -fsS https://$Domain/app/version.json",
    "echo",
    "curl -fsS https://$Domain/client/version"
) -join "; "
ssh $SshHost $remote
if ($LASTEXITCODE -ne 0) { throw "vykladka veb-versii ne udalas" }
Write-Host ""
Write-Host "Gotovo: https://$Domain/app/"
