#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

target_ref="${1:-dev}"
upstream_ref="${2:-upstream/main}"
sync_ref="${3:-WORKTREE}"

root="$(git rev-parse --show-toplevel)"
stamp="$(date +%Y%m%d%H%M%S)"
out_dir="${ARKHAM_TC_BASELINE_DIR:-/tmp/arkham-tc-baselines-$stamp}"
mkdir -p "$out_dir"

worktrees=()
prepared_worktree=""

cleanup() {
  for dir in "${worktrees[@]:-}"; do
    git -C "$root" worktree remove --force "$dir" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT

prepare_worktree() {
  local label="$1"
  local ref="$2"
  local dir="$out_dir/$label-worktree"

  if [ "$ref" = "WORKTREE" ] || [ "$ref" = "." ]; then
    if [ ! -e "$root/frontend/node_modules" ]; then
      (cd "$root/frontend" && npm ci)
    fi
    prepared_worktree="$root"
    return 0
  fi

  git -C "$root" worktree add --detach "$dir" "$ref" >/dev/null
  worktrees+=("$dir")

  if [ ! -e "$dir/frontend/node_modules" ]; then
    if [ -d "$root/frontend/node_modules" ]; then
      ln -s "$root/frontend/node_modules" "$dir/frontend/node_modules"
    else
      (cd "$dir/frontend" && npm ci)
    fi
  fi

  prepared_worktree="$dir"
}

run_tc() {
  local label="$1"
  local dir="$2"
  local log="$out_dir/$label.log"
  local code_file="$out_dir/$label.exit"

  set +e
  (cd "$dir/frontend" && npm run tc) >"$log" 2>&1
  local code=$?
  set -e

  printf '%s\n' "$code" >"$code_file"
  grep -E '^src/.*: error TS[0-9]+' "$log" \
    | sed -E 's/^([^(:]+)(\([0-9]+,[0-9]+\)): /\1: /' \
    | sed -E 's#/[[:graph:]]+/frontend/src/#src/#g' \
    | sort -u >"$out_dir/$label.errors" || true
  sed -E 's/: error TS[0-9]+:.*$//' "$out_dir/$label.errors" \
    | sort -u >"$out_dir/$label.files" || true
}

prepare_worktree target "$target_ref"
target_dir="$prepared_worktree"
prepare_worktree upstream "$upstream_ref"
upstream_dir="$prepared_worktree"
prepare_worktree sync "$sync_ref"
sync_dir="$prepared_worktree"

run_tc target "$target_dir"
run_tc upstream "$upstream_dir"
run_tc sync "$sync_dir"

cat "$out_dir/target.errors" "$out_dir/upstream.errors" | sort -u >"$out_dir/known.errors"
cat "$out_dir/target.files" "$out_dir/upstream.files" | sort -u >"$out_dir/known.files"

comm -23 "$out_dir/sync.errors" "$out_dir/known.errors" >"$out_dir/sync-only.errors" || true
comm -23 "$out_dir/sync.files" "$out_dir/known.files" >"$out_dir/sync-only.files" || true

printf 'tc baseline output: %s\n' "$out_dir"
printf 'target %s exit: %s, error lines: %s, files: %s\n' \
  "$target_ref" "$(cat "$out_dir/target.exit")" "$(wc -l <"$out_dir/target.errors")" "$(wc -l <"$out_dir/target.files")"
printf 'upstream %s exit: %s, error lines: %s, files: %s\n' \
  "$upstream_ref" "$(cat "$out_dir/upstream.exit")" "$(wc -l <"$out_dir/upstream.errors")" "$(wc -l <"$out_dir/upstream.files")"
printf 'sync %s exit: %s, error lines: %s, files: %s\n' \
  "$sync_ref" "$(cat "$out_dir/sync.exit")" "$(wc -l <"$out_dir/sync.errors")" "$(wc -l <"$out_dir/sync.files")"
printf 'sync-only normalized errors: %s\n' "$(wc -l <"$out_dir/sync-only.errors")"
printf 'sync-only files: %s\n' "$(wc -l <"$out_dir/sync-only.files")"

if [ -s "$out_dir/sync-only.errors" ]; then
  printf '\nSync-only normalized tc errors:\n'
  sed -n '1,80p' "$out_dir/sync-only.errors"
  printf '\nInspect full details in %s/sync-only.errors\n' "$out_dir"
elif [ -s "$out_dir/sync-only.files" ]; then
  printf '\nFiles with sync-only tc errors:\n'
  sed -n '1,80p' "$out_dir/sync-only.files"
  printf '\nInspect full details in %s/sync-only.errors\n' "$out_dir"
else
  printf '\nNo sync-only tc errors relative to target/upstream baselines.\n'
fi
