<#
.SYNOPSIS
  Import a prepared Arkham Horror image pack into frontend/public/img.

.DESCRIPTION
  SourcePath may point either to the img directory itself or to a parent
  directory that contains img. The script syncs the source into
  frontend/public/img with robocopy, then restarts the web container so
  Nginx can serve the local images.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    [switch]$DryRun,
    [switch]$SkipRestart,
    [string]$ContainerName = 'arkhamhorror-rebuild-frontend-web-1'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$destImgDir = Join-Path $repoRoot 'frontend\public\img'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Source path does not exist: $SourcePath"
}

$resolved = Resolve-Path -LiteralPath $SourcePath
$srcLeaf = Split-Path -Leaf $resolved.Path
if ($srcLeaf -ieq 'img') {
    $srcImgDir = $resolved.Path
} else {
    $candidate = Join-Path $resolved.Path 'img'
    if (Test-Path -LiteralPath $candidate) {
        $srcImgDir = (Resolve-Path -LiteralPath $candidate).Path
    } else {
        throw "Source path is neither an img directory nor a parent containing img: $SourcePath"
    }
}

Write-Step "Source image directory: $srcImgDir"
Write-Step "Destination directory:  $destImgDir"

$expected = @('arkham', 'icons')
$found = Get-ChildItem -LiteralPath $srcImgDir -Directory | Select-Object -ExpandProperty Name
$missing = $expected | Where-Object { $_ -notin $found }
if ($missing.Count -eq $expected.Count) {
    throw "Source image directory does not contain arkham or icons subdirectories. Found: $($found -join ', ')"
} elseif ($missing.Count -gt 0) {
    Write-Warn "Source image directory is missing: $($missing -join ', ')"
}

New-Item -ItemType Directory -Force -Path $destImgDir | Out-Null

$roboArgs = @(
    $srcImgDir, $destImgDir,
    '/E',
    '/MT:16',
    '/XF', '*.tmp',
    '/R:1', '/W:1',
    '/NFL', '/NDL'
)
if ($DryRun) { $roboArgs += '/L' }

Write-Step ("robocopy " + ($roboArgs -join ' '))
& robocopy @roboArgs
$rc = $LASTEXITCODE
if ($rc -ge 8) { throw "robocopy failed with exit code $rc" }
Write-Step "robocopy completed with exit code $rc"

if ($DryRun) {
    Write-Step 'DryRun mode: no files were written'
    return
}

if ($SkipRestart) {
    Write-Step 'Skipped web container restart. Run docker compose restart web later if needed.'
    return
}

$running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
if (-not $running) {
    Write-Warn "Container $ContainerName is not running; skipping restart. It will detect local images after startup."
    return
}

Write-Step "Restarting container $ContainerName"
docker compose restart web
if ($LASTEXITCODE -ne 0) { throw 'docker compose restart web failed' }

Start-Sleep -Seconds 3
Write-Step 'Health check http://localhost:3000/health'
try {
    $code = (Invoke-WebRequest -Uri http://localhost:3000/health -UseBasicParsing -TimeoutSec 10).StatusCode
    Write-Host "health -> $code"
} catch {
    Write-Warn "Health check failed (container may still be starting): $($_.Exception.Message)"
}

Write-Step 'Done. Open http://localhost:3000 and hard refresh if the browser cached old image URLs.'
