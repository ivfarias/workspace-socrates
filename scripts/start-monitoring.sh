#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH="$WORKSPACE_ROOT/.clawdbot/config.json"
LOG_DIR="$WORKSPACE_ROOT/.clawdbot/logs"
CHECK_SCRIPT="$SCRIPT_DIR/check-agents.sh"

usage() {
  cat <<'EOF'
Usage:
  start-monitoring.sh [--interval-seconds <n>] [--once]

Examples:
  ./scripts/start-monitoring.sh --once
  ./scripts/start-monitoring.sh --interval-seconds 600
EOF
}

interval_seconds=""
run_once="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval-seconds) interval_seconds="$2"; shift 2 ;;
    --once) run_once="true"; shift ;;
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

if [[ -z "$interval_seconds" ]]; then
  if [[ -f "$CONFIG_PATH" ]]; then
    interval_seconds="$(jq -r '.monitoring.intervalSeconds // 600' "$CONFIG_PATH")"
  else
    interval_seconds="600"
  fi
fi

if [[ ! -x "$CHECK_SCRIPT" ]]; then
  echo "Missing checker script: $CHECK_SCRIPT" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
monitor_log="$LOG_DIR/monitor.log"

if [[ "$run_once" == "true" ]]; then
  "$CHECK_SCRIPT" | tee -a "$monitor_log"
  exit $?
fi

echo "Starting monitoring loop. Interval: ${interval_seconds}s"
echo "Log: $monitor_log"

while true; do
  {
    echo
    echo "=== Monitor tick $(date '+%Y-%m-%d %H:%M:%S') ==="
    "$CHECK_SCRIPT"
  } | tee -a "$monitor_log"
  sleep "$interval_seconds"
done
