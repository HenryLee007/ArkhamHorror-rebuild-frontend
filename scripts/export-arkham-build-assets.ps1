[CmdletBinding()]
param(
  [string]$SourcePath,
  [string]$DestinationPath,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $SourcePath) {
  $SourcePath = Join-Path $scriptRoot "..\frontend\public\img\arkham\cards"
}

if (-not $DestinationPath) {
  $DestinationPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "arkham-build-assets"
}

function Resolve-ExistingDirectory {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    throw "Directory does not exist: $Path"
  }

  return (Resolve-Path -LiteralPath $Path).ProviderPath
}

function Invoke-CheckedRobocopy {
  param(
    [string]$From,
    [string]$To,
    [string]$Pattern
  )

  $args = @($From, $To, $Pattern, "/E", "/MT:16", "/R:1", "/W:1", "/NFL", "/NDL", "/NP")

  if ($DryRun) {
    Write-Host "robocopy $($args -join ' ')"
    return
  }

  & robocopy @args
  $code = $LASTEXITCODE

  if ($code -gt 7) {
    throw "robocopy failed with exit code $code"
  }
}

$sourceFull = Resolve-ExistingDirectory $SourcePath
$destinationFull = [IO.Path]::GetFullPath($DestinationPath)
$optimizedPath = Join-Path $destinationFull "optimized"
$imageRoot = Resolve-ExistingDirectory (Join-Path $scriptRoot "..\frontend\public\img\arkham")

$avifCount = (Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Filter "*.avif" | Measure-Object).Count

if ($avifCount -eq 0) {
  throw "No .avif card images found in $sourceFull"
}

Write-Host "Source: $sourceFull"
Write-Host "Destination: $destinationFull"
Write-Host "Card images: $avifCount .avif files"

if (-not $DryRun) {
  New-Item -ItemType Directory -Force -Path $optimizedPath | Out-Null
}

Invoke-CheckedRobocopy -From $sourceFull -To $optimizedPath -Pattern "*.avif"

$backs = [ordered]@{
  "back_player.jpg" = "player_back.jpg"
  "back_encounter.jpg" = "encounter_back.jpg"
  "back_card.jpg" = "player_back.jpg"
  "back_the_longest_night.jpg" = "encounter_back.jpg"
  "back_artifact.jpg" = "player_back.jpg"
  "back_cthulhu_deck.jpg" = "encounter_back.jpg"
}

foreach ($entry in $backs.GetEnumerator()) {
  $from = Join-Path $imageRoot $entry.Value
  $to = Join-Path $destinationFull $entry.Key

  if (-not (Test-Path -LiteralPath $from -PathType Leaf)) {
    throw "Missing card back image: $from"
  }

  if ($DryRun) {
    Write-Host "copy $from -> $to"
    continue
  }

  Copy-Item -LiteralPath $from -Destination $to -Force
}

Write-Host "arkham.build assets are ready at $destinationFull"
