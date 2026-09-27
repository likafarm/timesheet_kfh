# Vykladka servera na VPS s etogo PK (Windows PowerShell 5.1).
# Fail v ASCII: PowerShell 5.1 chitaet UTF-8 bez BOM kak ANSI.
#
#   .\server\deploy\publish.ps1            # iz kornya repozitoriya
#
# Beret rabochuyu kopiyu (tracked + novye neignoriruemye fayly) tolko dlya
# servera, kladet arkhiv na VPS i zapuskaet server/deploy/deploy.sh iz nego.
# Nuzhen SSH-alias "kfh" v ~/.ssh/config (polzovatel deploy).
param(
    [string]$SshHost = "kfh"
)
$ErrorActionPreference = "Stop"

$root = git rev-parse --show-toplevel
if (-not $?) { throw "ne git-repozitoriy" }
Set-Location $root

$rev = (git rev-parse --short HEAD).Trim()
if (git status --porcelain) { $rev = "$rev-dirty" }
$paths = @("pubspec.lock", "packages/domain", "packages/local_db/pubspec.yaml", "server")
$list = Join-Path $env:TEMP "kfh-src-files.txt"
$tar = Join-Path $env:TEMP "kfh-src.tar"

$files = git ls-files -co --exclude-standard -- $paths |
    Where-Object { $_ -notmatch '(^|/)\.dart_tool/' -and $_ -notmatch '(^|/)build/' }
[System.IO.File]::WriteAllLines($list, [string[]]$files)
[System.IO.File]::Delete($tar)  # Remove-Item v PS 5.1 ne ponimaet korotkie imena (3C8A~1)
& "$env:SystemRoot\System32\tar.exe" -cf $tar -T $list
if ($LASTEXITCODE -ne 0) { throw "tar: oshibka" }
Write-Host "revision $rev, files: $($files.Count)"

scp -q $tar "${SshHost}:/tmp/kfh-src.tar"
if ($LASTEXITCODE -ne 0) { throw "scp: oshibka" }

ssh $SshHost "tar -xOf /tmp/kfh-src.tar server/deploy/deploy.sh > /tmp/kfh-deploy.sh && bash /tmp/kfh-deploy.sh /tmp/kfh-src.tar $rev"
if ($LASTEXITCODE -ne 0) { throw "deploy.sh zavershilsya s oshibkoy" }
[System.IO.File]::Delete($tar); [System.IO.File]::Delete($list)
