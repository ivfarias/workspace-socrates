#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGISTRY_PATH="$WORKSPACE_ROOT/.clawdbot/active-tasks.json"
CONFIG_PATH="$WORKSPACE_ROOT/.clawdbot/config.json"
RUNTIME_DIR="$WORKSPACE_ROOT/.clawdbot/runtime"
LOG_DIR="$WORKSPACE_ROOT/.clawdbot/logs"
RUNNER="$SCRIPT_DIR/run-agent.sh"

usage() {
  cat <<'EOF'
Usage:
  spawn-agent.sh --id <task-id> --agent <codex|claude|openclaw|custom> --description <text> --worktree <path> [options]

Options:
  --task-type <type>              Task profile key for model routing
  --completion-mode <mode>        pr | no-pr-spec (default: pr)
  --spec-file <path>              Spec JSON for no-pr-spec completion checks
  --model <model>                 Explicit model override
  --branch <branch>               Branch name (auto-detected from worktree if omitted)
  --repo-path <path>              Absolute repo path (auto-detected from worktree if omitted)
  --session <tmux-session>        Session name (default: ceo-<task-id>)
  --prompt-file <path>            Prompt file to feed to the agent
  --max-retries <n>               Retry budget (default from config)
  --notify-on-complete <bool>     true|false (default: true)
  --requires-screenshot <bool>    true|false (default: false)
  --reasoning-effort <level>      Codex reasoning effort (default: high)
  --command <shell-command>       Required when --agent custom

Backward-compatible usage:
  spawn-agent.sh <AGENT_LABEL> <MODEL> <TASK> <WORKTREE_PATH>
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

now_ms() {
  python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
}

json_bool() {
  if [[ "$1" == "true" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

slugify() {
  printf '%s' "$1" | tr -cs '[:alnum:]_-' '-'
}

resolve_model() {
  local task_type="$1"
  local agent="$2"
  local explicit="$3"

  if [[ -n "$explicit" ]]; then
    echo "$explicit"
    return
  fi

  if [[ -f "$CONFIG_PATH" ]]; then
    local profile_model
    profile_model="$(jq -r --arg t "$task_type" '.models.profiles[$t] // empty' "$CONFIG_PATH")"
    if [[ -n "$profile_model" ]]; then
      echo "$profile_model"
      return
    fi

    local agent_default
    agent_default="$(jq -r --arg a "$agent" '.models.agentDefaults[$a] // empty' "$CONFIG_PATH")"
    if [[ -n "$agent_default" ]]; then
      echo "$agent_default"
      return
    fi

    jq -r '.models.default // "github-copilot/claude-sonnet-4-6"' "$CONFIG_PATH"
    return
  fi

  case "$agent" in
    codex) echo "openai/gpt-5-codex" ;;
    claude) echo "github-copilot/claude-sonnet-4-6" ;;
    *) echo "github-copilot/claude-sonnet-4-6" ;;
  esac
}

ensure_registry() {
  mkdir -p "$(dirname "$REGISTRY_PATH")" "$RUNTIME_DIR" "$LOG_DIR"
  if [[ ! -f "$REGISTRY_PATH" ]]; then
    echo "[]" > "$REGISTRY_PATH"
  fi
}

agent=""
task_id=""
task_type="backend-complex"
completion_mode="pr"
spec_file=""
description=""
worktree=""
model=""
branch=""
repo_path=""
session_name=""
prompt_file=""
reasoning_effort="high"
custom_command=""
notify_on_complete="true"
requires_screenshot="false"
max_retries=""

if [[ $# -ge 4 && "$1" != --* ]]; then
  agent="$1"
  model="$2"
  description="$3"
  worktree="$4"
  task_id="$(slugify "$agent-$description")"
else
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agent) agent="$2"; shift 2 ;;
      --id) task_id="$2"; shift 2 ;;
      --task-type) task_type="$2"; shift 2 ;;
      --completion-mode) completion_mode="$2"; shift 2 ;;
      --spec-file) spec_file="$2"; shift 2 ;;
      --description) description="$2"; shift 2 ;;
      --worktree) worktree="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      --branch) branch="$2"; shift 2 ;;
      --repo-path) repo_path="$2"; shift 2 ;;
      --session) session_name="$2"; shift 2 ;;
      --prompt-file) prompt_file="$2"; shift 2 ;;
      --reasoning-effort) reasoning_effort="$2"; shift 2 ;;
      --command) custom_command="$2"; shift 2 ;;
      --max-retries) max_retries="$2"; shift 2 ;;
      --notify-on-complete) notify_on_complete="$2"; shift 2 ;;
      --requires-screenshot) requires_screenshot="$2"; shift 2 ;;
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

if [[ -z "$agent" || -z "$description" || -z "$worktree" ]]; then
  usage
  exit 1
fi

if [[ "$completion_mode" != "pr" && "$completion_mode" != "no-pr-spec" ]]; then
  echo "Invalid completion mode '$completion_mode'. Expected: pr or no-pr-spec." >&2
  exit 1
fi

if [[ -z "$task_id" ]]; then
  task_id="$(slugify "$agent-$description")"
fi

require_cmd jq
require_cmd tmux
ensure_registry

worktree="$(cd "$worktree" && pwd)"
if [[ ! -d "$worktree" ]]; then
  echo "Worktree path not found: $worktree" >&2
  exit 1
fi

if [[ -n "$prompt_file" ]]; then
  prompt_file="$(cd "$(dirname "$prompt_file")" && pwd)/$(basename "$prompt_file")"
  if [[ ! -f "$prompt_file" ]]; then
    echo "Prompt file not found: $prompt_file" >&2
    exit 1
  fi
fi

if [[ -n "$spec_file" ]]; then
  spec_file="$(cd "$(dirname "$spec_file")" && pwd)/$(basename "$spec_file")"
fi
if [[ "$completion_mode" == "no-pr-spec" ]]; then
  if [[ -z "$spec_file" ]]; then
    echo "--spec-file is required when --completion-mode no-pr-spec is used." >&2
    exit 1
  fi
  if [[ ! -f "$spec_file" ]]; then
    echo "Spec file not found: $spec_file" >&2
    exit 1
  fi
fi

if [[ -z "$repo_path" ]]; then
  repo_path="$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$repo_path" ]]; then
  repo_path="$worktree"
fi

if [[ -z "$branch" ]]; then
  branch="$(git -C "$worktree" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
fi

if [[ -z "$max_retries" ]]; then
  if [[ -f "$CONFIG_PATH" ]]; then
    max_retries="$(jq -r '.retryPolicy.maxAttempts // 3' "$CONFIG_PATH")"
  else
    max_retries="3"
  fi
fi

model="$(resolve_model "$task_type" "$agent" "$model")"

if [[ -z "$session_name" ]]; then
  session_name="ceo-$(slugify "$task_id")"
fi

if tmux has-session -t "$session_name" 2>/dev/null; then
  echo "tmux session already exists: $session_name" >&2
  exit 1
fi

max_concurrent=4
max_heavy=2
if [[ -f "$CONFIG_PATH" ]]; then
  max_concurrent="$(jq -r '.limits.maxConcurrentAgents // 4' "$CONFIG_PATH")"
  max_heavy="$(jq -r '.limits.maxConcurrentHeavyAgents // 2' "$CONFIG_PATH")"
fi

running_count="$(jq '[.[] | select(.status=="running" or .status=="retrying")] | length' "$REGISTRY_PATH")"
if (( running_count >= max_concurrent )); then
  echo "Concurrency limit reached: running=$running_count max=$max_concurrent" >&2
  exit 1
fi

is_heavy="false"
if [[ -f "$CONFIG_PATH" ]]; then
  is_heavy="$(jq -r --arg t "$task_type" '.limits.heavyTaskTypes | index($t) != null' "$CONFIG_PATH")"
fi
if [[ "$is_heavy" == "true" ]]; then
  running_heavy="$(jq -r '
    [.[] | select((.status=="running" or .status=="retrying") and (.heavy == true))] | length
  ' "$REGISTRY_PATH")"
  if (( running_heavy >= max_heavy )); then
    echo "Heavy-task limit reached for '$task_type': running=$running_heavy max=$max_heavy" >&2
    exit 1
  fi
fi

launch_script="$RUNTIME_DIR/${task_id}.sh"
timestamp="$(date +%Y%m%d-%H%M%S)"
log_file="$LOG_DIR/${task_id}-${timestamp}.log"
created_at="$(now_ms)"

cmd=("$RUNNER" --agent "$agent" --model "$model" --description "$description" --task-id "$task_id" --reasoning-effort "$reasoning_effort")
if [[ -n "$prompt_file" ]]; then
  cmd+=(--prompt-file "$prompt_file")
fi
if [[ -n "$custom_command" ]]; then
  cmd+=(--command "$custom_command")
fi

printf -v cmd_str '%q ' "${cmd[@]}"
printf -v cd_str '%q' "$worktree"

cat > "$launch_script" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd $cd_str
exec $cmd_str
EOF
chmod +x "$launch_script"

tmux new-session -d -s "$session_name" -c "$worktree" "$launch_script"
tmux pipe-pane -o -t "$session_name" "cat >> '$log_file'"

task_json="$(jq -n \
  --arg id "$task_id" \
  --arg status "running" \
  --arg agent "$agent" \
  --arg model "$model" \
  --arg taskType "$task_type" \
  --arg completionMode "$completion_mode" \
  --arg specFile "$spec_file" \
  --arg description "$description" \
  --arg repo "$(basename "$repo_path")" \
  --arg repoPath "$repo_path" \
  --arg worktree "$worktree" \
  --arg branch "$branch" \
  --arg tmuxSession "$session_name" \
  --arg promptFile "$prompt_file" \
  --arg launchScript "$launch_script" \
  --arg logFile "$log_file" \
  --argjson startedAt "$created_at" \
  --argjson updatedAt "$created_at" \
  --argjson attempt 1 \
  --argjson maxRetries "$max_retries" \
  --argjson notifyOnComplete "$(json_bool "$notify_on_complete")" \
  --argjson requiresScreenshot "$(json_bool "$requires_screenshot")" \
  --argjson isHeavy "$is_heavy" \
  '{
    id: $id,
    status: $status,
    agent: $agent,
    model: $model,
    taskType: $taskType,
    completionMode: $completionMode,
    specFile: $specFile,
    description: $description,
    repo: $repo,
    repoPath: $repoPath,
    worktree: $worktree,
    branch: $branch,
    tmuxSession: $tmuxSession,
    promptFile: $promptFile,
    startedAt: $startedAt,
    updatedAt: $updatedAt,
    attempt: $attempt,
    maxRetries: $maxRetries,
    notifyOnComplete: $notifyOnComplete,
    requiresScreenshot: $requiresScreenshot,
    heavy: $isHeavy,
    sessionAlive: true,
    specEvaluation: null,
    checks: {
      prCreated: false,
      ciPassed: false,
      branchUpToDate: false,
      codexReviewPassed: false,
      claudeReviewPassed: false,
      geminiReviewPassed: false,
      screenshotIncluded: false
    },
    runtime: {
      launchScript: $launchScript,
      logFile: $logFile
    }
  }'
)"

tmp_file="$(mktemp)"
jq --argjson task "$task_json" '
  (map(select(.id != $task.id)) + [$task]) | sort_by(.startedAt)
' "$REGISTRY_PATH" > "$tmp_file"
mv "$tmp_file" "$REGISTRY_PATH"

echo "Spawned $agent task '$task_id' in session '$session_name' with model '$model'."
echo "Registry: $REGISTRY_PATH"
echo "Log file: $log_file"
