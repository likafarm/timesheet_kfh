# Sborka APK dlya telefona operatora (etap 4.7).
# Klyuch podpisi - vne repozitoriya: %USERPROFILE%\.kfh\android\key.properties
# (sm. android/app/build.gradle.kts). Rezultat - installer_output\kfh-<versiya>.apk
#
# Java ne mozhet sozdat' sluzhebnyy soket vo vremennoy papke s kirillitsey
# v puti profilya ("Unable to establish loopback connection") - poetomu
# vremennaya papka Java - vnutri proekta (build\java_tmp).

param([switch]$Debug)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$tmp = Join-Path $root 'build\java_tmp'
New-Item -ItemType Directory -Force $tmp | Out-Null
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$tmp -Djava.io.tmpdir=$tmp"

$version = (Select-String -Path (Join-Path $root 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$name = $version.Split('+')[0]

Push-Location $root
try {
    if ($Debug) {
        flutter build apk --debug
        $apk = 'build\app\outputs\flutter-apk\app-debug.apk'
        $out = "installer_output\kfh-$name-debug.apk"
    } else {
        flutter build apk --release
        $apk = 'build\app\outputs\flutter-apk\app-release.apk'
        $out = "installer_output\kfh-$name.apk"
    }
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk: kod $LASTEXITCODE" }
    New-Item -ItemType Directory -Force 'installer_output' | Out-Null
    Copy-Item $apk $out -Force
    $hash = (Get-FileHash $out -Algorithm SHA256).Hash.ToLower()
    Write-Host "APK: $out"
    Write-Host "SHA-256: $hash"
} finally {
    Pop-Location
}
