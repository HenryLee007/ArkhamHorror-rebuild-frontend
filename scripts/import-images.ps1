<#
.SYNOPSIS
  从外部图片包（NAS / 本地目录 / 解压后目录）导入 Arkham Horror 卡面资源到项目。

.DESCRIPTION
  适用场景：第一次启动项目、或在新机器上，不想再从 CDN 重新拉 2.9 GB 资源。
  已经从 NAS/朋友处拿到了一份 img 目录（结构应与 frontend/public/img 一致）。
  本脚本把源目录同步到 frontend/public/img，并自动触发 web 容器重启，让 Nginx
  识别新图片。

  目录结构示例（源路径必须是 img 这一层 或 其上一层）：
    <source>/img/
        arkham/
            en/cards/01001.avif
            zh/cards/01001.avif
            investigators/
            tokens/
            ...
        icons/
        ...

  脚本对两种传入路径都兼容：
    -SourcePath D:\backup\arkham\img          # 直接传 img 目录
    -SourcePath D:\backup\arkham              # 传包含 img 子目录的父目录

.PARAMETER SourcePath
  图片源目录（必填）。可以是本地磁盘、移动硬盘、已挂载的 NAS 盘符或 UNC 路径。

.PARAMETER DryRun
  仅打印将要复制什么，不实际落地。

.PARAMETER SkipRestart
  复制完后不重启 web 容器（适合离线恢复）。

.PARAMETER ContainerName
  web 容器名，默认 arkhamhorror-rebuild-frontend-web-1。

.EXAMPLE
  .\scripts\import-images.ps1 -SourcePath D:\nas-mount\arkham-horror-images
  从 NAS 挂载盘导入。

.EXAMPLE
  .\scripts\import-images.ps1 -SourcePath '\\NAS\share\arkham\img' -DryRun
  先预览从 UNC 路径要拷多少。

.EXAMPLE
  .\scripts\import-images.ps1 -SourcePath C:\Users\me\Desktop\arkham-horror-images -SkipRestart
  复制但不重启（稍后手动 docker compose restart web）。
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
$repoRoot    = Split-Path -Parent $PSScriptRoot
$destImgDir  = Join-Path $repoRoot 'frontend\public\img'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Warn($msg) { Write-Host "!!  $msg" -ForegroundColor Yellow }

# 1. 解析源路径：允许传 .../img 或其父目录
if (-not (Test-Path $SourcePath)) { throw "源路径不存在: $SourcePath" }

$resolved = Resolve-Path $SourcePath
$srcLeaf  = Split-Path -Leaf $resolved
if ($srcLeaf -ieq 'img') {
    $srcImgDir = $resolved.Path
} elseif (Test-Path (Join-Path $resolved 'img')) {
    $srcImgDir = (Resolve-Path (Join-Path $resolved 'img')).Path
} else {
    throw "源路径既不是 img 目录，也不包含 img 子目录: $SourcePath"
}
Write-Step "源图片目录: $srcImgDir"
Write-Step "目标目录:   $destImgDir"

# 2. 简单校验源目录结构是否像 arkham 图片包
$expected = @('arkham', 'icons')
$found    = Get-ChildItem -Path $srcImgDir -Directory | Select-Object -ExpandProperty Name
$missing  = $expected | Where-Object { $_ -notin $found }
if ($missing.Count -eq $expected.Count) {
    Write-Warn "源目录没有任何 arkham/icons 子目录，可能不是正确的图片包。已找到: $($found -join ', ')"
    $ans = Read-Host '仍然继续？(y/N)'
    if ($ans -ne 'y') { throw '用户中止' }
} elseif ($missing.Count -gt 0) {
    Write-Warn "源目录缺少子目录: $($missing -join ', ')（部分导入，请确认是否预期）"
}

# 3. 确保目标父目录存在
New-Item -ItemType Directory -Force -Path $destImgDir | Out-Null

# 4. robocopy 同步（/E 保留子树；/XF *.tmp 忽略未完成下载；/MT:16 多线程；/XO 仅更新更新的；/R:1 重试 1 次）
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
# robocopy 退出码：<8 为成功/有警告；>=8 为错误
if ($rc -ge 8) { throw "robocopy 失败，退出码 $rc" }
Write-Step "robocopy 完成，退出码 $rc（<8 均视为成功）"

if ($DryRun) {
    Write-Step '（DryRun 模式，未实际写入）'
    return
}

# 5. 重启 web 容器，让 Nginx 立刻看到新文件
if ($SkipRestart) {
    Write-Step '已跳过 web 容器重启（稍后手动：docker compose restart web）'
    return
}

$running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
if (-not $running) {
    Write-Warn "容器 $ContainerName 未运行，跳过重启。启动后会自动识别本地图片。"
    return
}

Write-Step "重启容器 $ContainerName"
docker compose restart web
if ($LASTEXITCODE -ne 0) { throw 'docker compose restart web 失败' }

# 6. 快速自检
Start-Sleep -Seconds 3
Write-Step '健康检查 http://localhost:3000/health'
try {
    $code = (Invoke-WebRequest -Uri http://localhost:3000/health -UseBasicParsing -TimeoutSec 10).StatusCode
    Write-Host "health -> $code"
} catch {
    Write-Warn "健康检查失败（容器可能仍在启动）：$($_.Exception.Message)"
}

Write-Step '完成。浏览器 Ctrl+F5 强刷 http://localhost:3000 即可看到本地图片。'
