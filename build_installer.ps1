# build_installer.ps1
# Сборка Windows-установщика для «Учёт рабочего времени КФХ»
# Использование: .\build_installer.ps1

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

$releaseDir = "build\windows\x64\runner\Release"
$outputDir = "installer_output"
$appName = "timesheet_kfh"
# Versiya - edinstvenny istochnik pubspec.yaml ("version: 1.2.3+4" -> "1.2.3")
$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*([0-9.]+)' | Select-Object -First 1
if (-not $versionLine) {
    Write-Host "[ERROR] Ne naidena versiya v pubspec.yaml" -ForegroundColor Red
    exit 1
}
$appVersion = $versionLine.Matches[0].Groups[1].Value
$setupName = "KFH_TimeTracking_Setup_$appVersion"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Sbor ustanovshika  $setupName" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path "$releaseDir\$appName.exe")) {
    Write-Host "[ERROR] Reliz sbork ne naiden: $releaseDir\$appName.exe" -ForegroundColor Red
    Write-Host "Snachalo: flutter build windows --release" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Reliz naiden: $releaseDir\$appName.exe" -ForegroundColor Green
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$iscc = Get-Command iscc -ErrorAction SilentlyContinue
if ($iscc) {
    Write-Host ""
    Write-Host "[INFO] Inno Setup naiden: $($iscc.Source)" -ForegroundColor Green
    Write-Host "[ACTION] Kompiliaciya installer.iss ..." -ForegroundColor Yellow
    Write-Host ""
    & iscc "/DAppVer=$appVersion" installer.iss
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Oshibka sborki ustanovshika (kod $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
    $resultFile = "$outputDir\$setupName.exe"
    $file = Get-Item $resultFile
    $resultSize = [math]::Round($file.Length / 1MB, 1)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Sozdan ustanovshik:" -ForegroundColor Green
    Write-Host "  $resultFile" -ForegroundColor Green
    Write-Host "  Razmer: $resultSize MB" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[WARN] Inno Setup ne naiden." -ForegroundColor Yellow
    Write-Host "[INFO] Skachat Inno Setup: https://jrsoftware.org/isinfo.php" -ForegroundColor Gray
    Write-Host "[INFO] Budet sozdan portativny ZIP-arhiv." -ForegroundColor Yellow
    Write-Host ""

    $zipFile = "$outputDir\$setupName.zip"
    Write-Host "[ACTION] Sozdanie portativnoy versii (ZIP) ..." -ForegroundColor Yellow
    Remove-Item -LiteralPath $zipFile -Force -ErrorAction SilentlyContinue

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "kfh_setup_temp"
    Remove-Item -Recurse -Force -LiteralPath $tempDir -ErrorAction SilentlyContinue

    Write-Host "[ACTION] Kopirovanie failov ..." -ForegroundColor Yellow
    Copy-Item -Recurse -Force -Path $releaseDir -Destination $tempDir

    Write-Host "[ACTION] Arhivaciya ..." -ForegroundColor Yellow

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipFile)

    Remove-Item -Recurse -Force -LiteralPath $tempDir

    $file = Get-Item $zipFile
    $zipSize = [math]::Round($file.Length / 1MB, 1)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Sozdan portativny ZIP-arhiv:" -ForegroundColor Green
    Write-Host "  $zipFile" -ForegroundColor Green
    Write-Host "  Razmer: $zipSize MB" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[INFO] Raspakuyte arhiv v lyubuyu papku i zapustite $appName.exe" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Gotovo!" -ForegroundColor Green