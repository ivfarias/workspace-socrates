#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-agent.sh --agent <codex|claude|openclaw|custom> --model <model> [options]

Options:
  --description <text>       Task description (used as prompt when no prompt file is provided)
  --prompt-file <path>       File containing full prompt text
  --task-id <id>             Task id (used as label by openclaw runner)
  --reasoning-effort <level> Codex reasoning effort (default: high)
  --command <shell-command>  Command for custom agent type
EOF
}

agent=""
model=""
description=""
prompt_file=""
task_id="agent"
reasoning_effort="high"
custom_command=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    --model) model="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --prompt-file) prompt_file="$2"; shift 2 ;;
    --task-id) task_id="$2"; shift 2 ;;
    --reasoning-effort) reasoning_effort="$2"; shift 2 ;;
    --command) custom_command="$2"; shift 2 ;;
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

if [[ -z "$agent" || -z "$model" ]]; then
  usage
  exit 1
fi

prompt="$description"
if [[ -n "$prompt_file" ]]; then
  if [[ ! -f "$prompt_file" ]]; then
    echo "Prompt file not found: $prompt_file" >&2
    exit 1
  fi
  prompt="$(cat "$prompt_file")"
fi

case "$agent" in
  codex)
    # Do NOT pass --model to Codex — let ~/.codex/config.toml control the model.
    # Passing an explicit model string (e.g. openai/gpt-5-codex) causes auth errors
    # when using a ChatGPT account that doesn't support that model identifier.
    exec codex \
      -c "model_reasoning_effort=$reasoning_effort" \
      --dangerously-bypass-approvals-and-sandbox \
      "$prompt"
    ;;
  claude)
    exec claude \
      --model "$model" \
      --dangerously-skip-permissions \
      -p "$prompt"
    ;;
  openclaw)
    exec openclaw \
      --label "$task_id" \
      --model "$model" \
      --task "$prompt"
    ;;
  custom)
    if [[ -z "$custom_command" ]]; then
      echo "--command is required when --agent custom is used." >&2
      exit 1
    fi
    exec bash -lc "$custom_command"
    ;;
  *)
    echo "Unsupported agent '$agent'. Expected: codex, claude, openclaw, custom." >&2
    exit 1
    ;;
esac
