<#
.SYNOPSIS
  本地构建前端并热更新到运行中的 web 容器，不重启、不重建镜像。

.DESCRIPTION
  适用场景：修改了 frontend/src 下的 Vue / i18n / TS 源码后，希望立刻在
  http://localhost:3000 看到效果。本脚本执行：
    1. (可选) npm install（通过 -Install 开关触发）
    2. npm run build          —— 产出 frontend/dist/{index.html, assets/}
    3. 清理容器内旧 dist/index.html 与 dist/assets
    4. docker cp 新产物覆盖

  注意：vite.config.js 已设置 build.copyPublicDir=false，故 dist 不会包含
  public/img。容器内现有的 img/fonts/cards*.json 等静态资源保持不动。

.PARAMETER ContainerName
  目标 web 容器名。默认 arkhamhorror-rebuild-frontend-web-1。

.PARAMETER DistRoot
  容器内前端根目录。默认 /opt/arkham/src/frontend/dist。

.PARAMETER Install
  构建前先执行 npm install（首次运行 / package.json 变动后使用）。

.PARAMETER Registry
  npm install 使用的 registry，默认淘宝镜像。

.EXAMPLE
  .\scripts\deploy-frontend.ps1
  常规：build + 推到容器。

.EXAMPLE
  .\scripts\deploy-frontend.ps1 -Install
  首次或依赖变更：先 install 再 build + 推送。
#>
[CmdletBinding()]
param(
    [string]$ContainerName = 'arkhamhorror-rebuild-frontend-web-1',
    [string]$DistRoot      = '/opt/arkham/src/frontend/dist',
    [switch]$Install,
    [string]$Registry      = 'https://registry.npmmirror.com'
)

$ErrorActionPreference = 'Stop'
$repoRoot    = Split-Path -Parent $PSScriptRoot
$frontendDir = Join-Path $repoRoot 'frontend'
$distDir     = Join-Path $frontendDir 'dist'

function Write-Step($msg) {
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# 0. 前置检查
Write-Step '检查 docker 与容器状态'
$null = docker version --format '{{.Server.Version}}' 2>$null
if ($LASTEXITCODE -ne 0) { throw 'Docker 未运行或未安装' }

$running = docker ps --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
if (-not $running) { throw "容器 $ContainerName 未运行，请先 docker compose up -d" }

if (-not (Test-Path $frontendDir)) { throw "找不到 frontend 目录: $frontendDir" }

Push-Location $frontendDir
try {
    # 1. 可选 install
    if ($Install) {
        Write-Step "npm install (registry=$Registry)"
        npm install --no-audit --no-fund --registry=$Registry
        if ($LASTEXITCODE -ne 0) { throw 'npm install 失败' }
    } elseif (-not (Test-Path (Join-Path $frontendDir 'node_modules'))) {
        Write-Step "首次检测到缺少 node_modules，自动 npm install (registry=$Registry)"
        npm install --no-audit --no-fund --registry=$Registry
        if ($LASTEXITCODE -ne 0) { throw 'npm install 失败' }
    }

    # 2. build
    Write-Step 'npm run build'
    npm run build
    if ($LASTEXITCODE -ne 0) { throw 'vite build 失败' }

    if (-not (Test-Path (Join-Path $distDir 'index.html'))) {
        throw "构建产物缺失 index.html: $distDir"
    }
    if (-not (Test-Path (Join-Path $distDir 'assets'))) {
        throw "构建产物缺失 assets/: $distDir"
    }
} finally {
    Pop-Location
}

# 3. 清理容器旧产物（文件 hash 变化时必须清理，否则旧 JS 会残留）
Write-Step "清理容器内旧 dist/index.html 与 dist/assets"
docker exec $ContainerName sh -lc "rm -rf $DistRoot/assets; rm -f $DistRoot/index.html"
if ($LASTEXITCODE -ne 0) { throw '容器内清理失败' }

# 4. 推送新产物
Write-Step '推送 index.html'
docker cp (Join-Path $distDir 'index.html') "${ContainerName}:$DistRoot/index.html"
if ($LASTEXITCODE -ne 0) { throw 'docker cp index.html 失败' }

Write-Step '推送 assets/'
docker cp (Join-Path $distDir 'assets') "${ContainerName}:$DistRoot/assets"
if ($LASTEXITCODE -ne 0) { throw 'docker cp assets 失败' }

Write-Step '完成，浏览器强刷 http://localhost:3000 (Ctrl+F5) 查看新版本'
