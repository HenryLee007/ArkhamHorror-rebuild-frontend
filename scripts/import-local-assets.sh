#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${1:-"$HOME/Desktop"}"
dry_run="${DRY_RUN:-0}"
skip_restart="${SKIP_RESTART:-0}"

main_source="${MAIN_IMAGES_SOURCE:-"$source_root/arkham-horror-images"}"
build_source="${BUILD_ASSETS_SOURCE:-"$source_root/arkham-build-assets"}"

main_dest="$repo_root/.local-assets/arkham-horror-images/img"
build_dest="$repo_root/.local-assets/arkham-build-assets"

step() {
  printf '==> %s\n' "$1"
}

warn() {
  printf '!!  %s\n' "$1" >&2
}

resolve_img_source() {
  local path="$1"
  if [[ -d "$path/img" ]]; then
    printf '%s\n' "$path/img"
  elif [[ -d "$path/arkham" || -d "$path/icons" ]]; then
    printf '%s\n' "$path"
  else
    return 1
  fi
}

sync_dir() {
  local src="$1"
  local dest="$2"

  mkdir -p "$dest"

  local args=(-a --delete --exclude '*.tmp')
  if [[ "$dry_run" == "1" ]]; then
    args+=(--dry-run --itemize-changes)
  fi

  step "rsync $src/ -> $dest/"
  rsync "${args[@]}" "$src/" "$dest/"
}

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but was not found." >&2
  exit 1
fi

if [[ ! -d "$main_source" ]]; then
  echo "Main image source does not exist: $main_source" >&2
  exit 1
fi

if [[ ! -d "$build_source" ]]; then
  echo "arkham.build asset source does not exist: $build_source" >&2
  exit 1
fi

main_img_source="$(resolve_img_source "$main_source")" || {
  echo "Main image source must be an img directory or a parent containing img: $main_source" >&2
  exit 1
}

if [[ ! -d "$build_source/optimized" ]]; then
  warn "arkham.build source has no optimized directory: $build_source"
fi

step "Main images source:      $main_img_source"
step "arkham.build source:     $build_source"
step "Local assets root:       $repo_root/.local-assets"

sync_dir "$main_img_source" "$main_dest"
sync_dir "$build_source" "$build_dest"

if [[ "$dry_run" == "1" ]]; then
  step "Dry run complete. No files were written."
  exit 0
fi

if [[ "$skip_restart" == "1" ]]; then
  step "Skipped Docker refresh. Run 'docker compose up -d web' when ready."
  exit 0
fi

step "Refreshing web container mounts"
(cd "$repo_root" && docker compose up -d web)

step "Health check http://localhost:3000/health"
if ! curl -fsS http://localhost:3000/health >/dev/null; then
  warn "Health check failed; the container may still be starting."
fi

step "Done."
