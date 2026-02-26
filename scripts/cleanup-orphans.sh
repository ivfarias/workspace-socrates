#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_PATH="$WORKSPACE_ROOT/.clawdbot/active-tasks.json"

usage() {
  cat <<'EOF'
Usage:
  cleanup-orphans.sh [--done-older-hours <n>] [--apply]

Default behavior is dry-run.

What it does:
  - Finds completed tasks older than threshold
  - Finds tasks whose worktree path no longer exists
  - Prints what would be removed from registry
  - With --apply, writes updated registry
EOF
}

done_older_hours=24
apply_changes="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --done-older-hours) done_older_hours="$2"; shift 2 ;;
    --apply) apply_changes="true"; shift ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$REGISTRY_PATH" ]]; then
  echo "Registry not found, nothing to clean."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

now_ms="$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"
age_ms=$((done_older_hours * 60 * 60 * 1000))
cutoff_ms=$((now_ms - age_ms))

remove_ids=""
while IFS= read -r task; do
  id="$(jq -r '.id // ""' <<<"$task")"
  status="$(jq -r '.status // ""' <<<"$task")"
  completed_at="$(jq -r '.completedAt // 0' <<<"$task")"
  worktree="$(jq -r '.worktree // ""' <<<"$task")"
  should_remove="false"

  if [[ "$status" == "done" ]] && [[ "$completed_at" =~ ^[0-9]+$ ]] && (( completed_at < cutoff_ms )); then
    should_remove="true"
  fi
  if [[ -n "$worktree" && ! -d "$worktree" ]]; then
    should_remove="true"
  fi

  if [[ "$should_remove" == "true" && -n "$id" ]]; then
    remove_ids+="${id}"$'\n'
  fi
done < <(jq -c '.[]' "$REGISTRY_PATH")

combined_ids="$(printf "%s" "$remove_ids" | awk 'NF' | sort -u)"

if [[ -z "$combined_ids" ]]; then
  echo "No stale tasks found."
  exit 0
fi

echo "Stale task ids:"
echo "$combined_ids"

if [[ "$apply_changes" != "true" ]]; then
  echo
  echo "Dry run only. Re-run with --apply to update registry."
  exit 0
fi

tmp_file="$(mktemp)"
jq --argjson ids "$(printf '%s\n' "$combined_ids" | jq -Rsc 'split("\n") | map(select(length > 0))')" '
  [ .[] | select((.id as $id | ($ids | index($id))) | not) ]
' "$REGISTRY_PATH" > "$tmp_file"
mv "$tmp_file" "$REGISTRY_PATH"

echo "Removed stale tasks from registry."
