#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/init-worktree.sh"
SPAWN_SCRIPT="$SCRIPT_DIR/spawn-agent.sh"

usage() {
  cat <<'EOF'
Usage:
  bootstrap-task.sh --repo <repo-path> --id <task-id> --branch <branch> --agent <codex|claude|gemini|openclaw|custom> --description <text> [options]

Core options:
  --repo <path>                  Repository root path
  --id <task-id>                 Unique task id for registry/session naming
  --branch <branch>              Branch to create/use for worktree
  --agent <agent>                codex | claude | gemini | openclaw | custom
  --description <text>           Task description
  --phase <phase>                initializer | coding (default: coding)
                                 'initializer' uses prompts/initializer-agent.md template;
                                 'coding' uses prompts/coding-agent.md template.

Worktree options:
  --base <ref>                   Base branch/ref (default: origin/main)
  --worktree-name <name>         Worktree directory name
  --install                      Force dependency install
  --skip-install                 Skip dependency install

Spawn options:
  --task-type <type>             Task type profile (default: backend-complex)
  --completion-mode <mode>       pr | no-pr-spec (default: pr)
  --spec-file <path>             Spec JSON file (required for no-pr-spec)
  --model <model>                Explicit model override
  --prompt-file <path>           Prompt file path
  --reasoning-effort <level>     Codex reasoning effort
  --max-retries <n>              Retry budget
  --notify-on-complete <bool>    true|false
  --requires-screenshot <bool>   true|false
  --command <shell-command>      Required when --agent custom

Example:
  ./scripts/bootstrap-task.sh \
    --repo /path/to/repo \
    --id feat-custom-templates \
    --branch feat/custom-templates \
    --agent codex \
    --task-type backend-complex \
    --description "Implement reusable templates" \
    --prompt-file /path/to/prompt.md
EOF
}

repo=""
task_id=""
branch=""
agent=""
description=""
base_ref="origin/main"
worktree_name=""
task_type="backend-complex"
completion_mode="pr"
spec_file=""
model=""
prompt_file=""
reasoning_effort="high"
max_retries=""
notify_on_complete=""
requires_screenshot=""
custom_command=""
install_flag=""
phase="coding"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --id) task_id="$2"; shift 2 ;;
    --branch) branch="$2"; shift 2 ;;
    --agent) agent="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --base) base_ref="$2"; shift 2 ;;
    --worktree-name) worktree_name="$2"; shift 2 ;;
    --install) install_flag="--install"; shift ;;
    --skip-install) install_flag="--skip-install"; shift ;;
    --task-type) task_type="$2"; shift 2 ;;
    --completion-mode) completion_mode="$2"; shift 2 ;;
    --spec-file) spec_file="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --prompt-file) prompt_file="$2"; shift 2 ;;
    --reasoning-effort) reasoning_effort="$2"; shift 2 ;;
    --max-retries) max_retries="$2"; shift 2 ;;
    --notify-on-complete) notify_on_complete="$2"; shift 2 ;;
    --requires-screenshot) requires_screenshot="$2"; shift 2 ;;
    --command) custom_command="$2"; shift 2 ;;
    --phase) phase="$2"; shift 2 ;;
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

if [[ -z "$repo" || -z "$task_id" || -z "$branch" || -z "$agent" || -z "$description" ]]; then
  usage
  exit 1
fi

if [[ ! -x "$INIT_SCRIPT" || ! -x "$SPAWN_SCRIPT" ]]; then
  echo "Required scripts missing or not executable in $SCRIPT_DIR" >&2
  exit 1
fi

init_cmd=("$INIT_SCRIPT" --repo "$repo" --branch "$branch" --base "$base_ref")
if [[ -n "$worktree_name" ]]; then
  init_cmd+=(--worktree-name "$worktree_name")
fi
if [[ -n "$install_flag" ]]; then
  init_cmd+=("$install_flag")
fi

init_output="$("${init_cmd[@]}")"
echo "$init_output"

worktree_path="$(awk -F': ' '/Worktree ready:/ {print $2}' <<<"$init_output" | tail -n 1)"
if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
  echo "Unable to resolve worktree path from init output." >&2
  exit 1
fi

# ── Item 6: Auto-select prompt template based on --phase if no explicit --prompt-file ──
if [[ -z "$prompt_file" ]]; then
  case "$phase" in
    initializer)
      candidate="$SCRIPT_DIR/../prompts/initializer-agent.md"
      if [[ -f "$candidate" ]]; then
        prompt_file="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
        echo "Phase 'initializer': using prompt template $prompt_file"
      fi
      ;;
    coding|*)
      candidate="$SCRIPT_DIR/../prompts/coding-agent.md"
      if [[ -f "$candidate" ]]; then
        prompt_file="$(cd "$(dirname "$candidate")" && pwd)/$(basename "$candidate")"
        echo "Phase 'coding': using prompt template $prompt_file"
      fi
      ;;
  esac
fi

spawn_cmd=(
  "$SPAWN_SCRIPT"
  --id "$task_id"
  --agent "$agent"
  --task-type "$task_type"
  --completion-mode "$completion_mode"
  --description "$description"
  --worktree "$worktree_path"
  --branch "$branch"
  --repo-path "$repo"
  --reasoning-effort "$reasoning_effort"
)

if [[ -n "$model" ]]; then
  spawn_cmd+=(--model "$model")
fi
if [[ -n "$spec_file" ]]; then
  spawn_cmd+=(--spec-file "$spec_file")
fi
if [[ -n "$prompt_file" ]]; then
  spawn_cmd+=(--prompt-file "$prompt_file")
fi
if [[ -n "$max_retries" ]]; then
  spawn_cmd+=(--max-retries "$max_retries")
fi
if [[ -n "$notify_on_complete" ]]; then
  spawn_cmd+=(--notify-on-complete "$notify_on_complete")
fi
if [[ -n "$requires_screenshot" ]]; then
  spawn_cmd+=(--requires-screenshot "$requires_screenshot")
fi
if [[ -n "$custom_command" ]]; then
  spawn_cmd+=(--command "$custom_command")
fi
spawn_cmd+=(--phase "$phase")

"${spawn_cmd[@]}"

echo "Bootstrap complete for task '$task_id'."
