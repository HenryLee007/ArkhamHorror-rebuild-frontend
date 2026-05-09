<#
.SYNOPSIS
  Build the local frontend and copy the dist output into the running web container.

.DESCRIPTION
  Use this after changing frontend/src Vue, i18n, or TypeScript files when the
  Docker web container is already running. The script optionally installs npm
  dependencies, runs npm run build, clears the old container dist assets, and
  copies the new index.html and assets directory into the container.
#>
[CmdletBinding()]
param(
    [string]$ContainerName = 'arkhamhorror-rebuild-frontend-web-1',
    [string]$DistRoot = '/opt/arkham/src/frontend/dist',
    [switch]$Install,
    [string]$Registry = 'https://registry.npmmirror.com'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $repoRoot 'frontend'
$distDir = Join-Path $frontendDir 'dist'
$publicDir = Join-Path $frontendDir 'public'

function Write-Step($msg) {
    Write-Host "==> $msg" -ForegroundColor Cyan
}

Write-Step 'Checking Docker and container status'
$null = docker version --format '{{.Server.Version}}' 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Docker is not running or not installed' }

$running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
if (-not $running) { throw "Container $ContainerName is not running. Start it with docker compose up -d first." }

if (-not (Test-Path -LiteralPath $frontendDir)) {
    throw "Cannot find frontend directory: $frontendDir"
}

Push-Location $frontendDir
try {
    if ($Install) {
        Write-Step "npm install (registry=$Registry)"
        npm install --no-audit --no-fund --registry=$Registry
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
    } elseif (-not (Test-Path -LiteralPath (Join-Path $frontendDir 'node_modules'))) {
        Write-Step "node_modules is missing; running npm install (registry=$Registry)"
        npm install --no-audit --no-fund --registry=$Registry
        if ($LASTEXITCODE -ne 0) { throw 'npm install failed' }
    }

    Write-Step 'npm run build'
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'vite build failed' }

    if (-not (Test-Path -LiteralPath (Join-Path $distDir 'index.html'))) {
        throw "Build output is missing index.html: $distDir"
    }
    if (-not (Test-Path -LiteralPath (Join-Path $distDir 'assets'))) {
        throw "Build output is missing assets/: $distDir"
    }
} finally {
    Pop-Location
}

Write-Step "Clearing old container assets in $DistRoot"
docker exec -u 0 $ContainerName sh -lc "rm -rf $DistRoot/assets; rm -f $DistRoot/index.html $DistRoot/cards.json $DistRoot/cards_*.json"
if ($LASTEXITCODE -ne 0) { throw 'Failed to clear old container frontend assets' }

Write-Step 'Copying index.html'
docker cp (Join-Path $distDir 'index.html') "${ContainerName}:$DistRoot/index.html"
if ($LASTEXITCODE -ne 0) { throw 'docker cp index.html failed' }

Write-Step 'Copying assets/'
docker cp (Join-Path $distDir 'assets') "${ContainerName}:$DistRoot/assets"
if ($LASTEXITCODE -ne 0) { throw 'docker cp assets failed' }

Write-Step 'Copying card data JSON'
foreach ($name in @('cards.json', 'cards_en.json', 'cards_zh.json')) {
    $cardDataPath = Join-Path $publicDir $name
    if (-not (Test-Path -LiteralPath $cardDataPath)) {
        throw "Missing card data file: $cardDataPath"
    }
    docker cp $cardDataPath "${ContainerName}:$DistRoot/$name"
    if ($LASTEXITCODE -ne 0) { throw "docker cp $name failed" }
}

Write-Step 'Done. Hard refresh http://localhost:3000 (Ctrl+F5) to see the new frontend.'
