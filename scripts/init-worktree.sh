#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH="$WORKSPACE_ROOT/.clawdbot/config.json"

usage() {
  cat <<'EOF'
Usage:
  init-worktree.sh --repo <repo-path> --branch <branch> [options]

Options:
  --base <base-branch>       Base branch/ref (default: origin/main)
  --worktree-name <name>     Worktree directory name (default: branch with "/" replaced by "-")
  --install                  Force dependency install
  --skip-install             Skip dependency install

Backward-compatible usage:
  init-worktree.sh <TASK_LABEL> <BRANCH> <BASE_BRANCH> <REPO_PATH>
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

slugify_branch() {
  echo "$1" | tr '/' '-'
}

repo_path=""
branch=""
base_branch="origin/main"
worktree_name=""
install_override=""

if [[ $# -ge 4 && "$1" != --* ]]; then
  branch="$2"
  base_branch="$3"
  repo_path="$4"
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_path="$2"; shift 2 ;;
      --branch) branch="$2"; shift 2 ;;
      --base) base_branch="$2"; shift 2 ;;
      --worktree-name) worktree_name="$2"; shift 2 ;;
      --install) install_override="true"; shift ;;
      --skip-install) install_override="false"; shift ;;
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
fi

if [[ -z "$repo_path" || -z "$branch" ]]; then
  usage
  exit 1
fi

require_cmd git
require_cmd jq

repo_path="$(cd "$repo_path" && pwd)"

if [[ ! -d "$repo_path/.git" ]]; then
  echo "Not a git repository: $repo_path" >&2
  exit 1
fi

if [[ -z "$worktree_name" ]]; then
  worktree_name="$(slugify_branch "$branch")"
fi

worktree_root_rel=".worktrees"
if [[ -f "$CONFIG_PATH" ]]; then
  worktree_root_rel="$(jq -r '.worktrees.root // ".worktrees"' "$CONFIG_PATH")"
fi

if [[ "$worktree_root_rel" = /* ]]; then
  worktree_root="$worktree_root_rel"
else
  worktree_root="$repo_path/$worktree_root_rel"
fi

if [[ "$worktree_root_rel" != /* ]]; then
  ignore_line="${worktree_root_rel%/}/"
  if ! git -C "$repo_path" check-ignore -q "$worktree_root_rel"; then
    if ! grep -Fxq "$ignore_line" "$repo_path/.gitignore" 2>/dev/null; then
      echo "$ignore_line" >> "$repo_path/.gitignore"
      echo "Added '$ignore_line' to $repo_path/.gitignore to prevent accidental worktree commits."
    fi
  fi
fi

mkdir -p "$worktree_root"
worktree_dir="$worktree_root/$worktree_name"

if [[ -e "$worktree_dir" ]]; then
  echo "Worktree directory already exists: $worktree_dir" >&2
  exit 1
fi

if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$repo_path" worktree add "$worktree_dir" "$branch"
else
  git -C "$repo_path" worktree add "$worktree_dir" -b "$branch" "$base_branch"
fi

install_dependencies="true"
if [[ -f "$CONFIG_PATH" ]]; then
  install_dependencies="$(jq -r '.worktrees.installDependencies // true' "$CONFIG_PATH")"
fi
if [[ -n "$install_override" ]]; then
  install_dependencies="$install_override"
fi

if [[ "$install_dependencies" == "true" ]]; then
  install_command=""
  if [[ -f "$CONFIG_PATH" ]]; then
    install_command="$(jq -r '.worktrees.installCommand // ""' "$CONFIG_PATH")"
  fi

  pushd "$worktree_dir" >/dev/null
  if [[ -n "$install_command" ]]; then
    bash -lc "$install_command"
  elif [[ -f "package.json" ]]; then
    if command -v pnpm >/dev/null 2>&1; then
      pnpm install --prefer-offline
    else
      npm install
    fi
  elif [[ -f "Cargo.toml" ]]; then
    cargo build
  elif [[ -f "pyproject.toml" ]] && command -v poetry >/dev/null 2>&1; then
    poetry install
  elif [[ -f "requirements.txt" ]]; then
    python3 -m pip install -r requirements.txt
  elif [[ -f "go.mod" ]]; then
    go mod download
  else
    echo "No known dependency manifest found in $worktree_dir; skipping install."
  fi
  popd >/dev/null
fi

echo "Worktree ready: $worktree_dir"
