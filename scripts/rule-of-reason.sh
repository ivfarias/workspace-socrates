#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: deterministic decision gate over active task registry.
base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -eq 0 ]]; then
  exec "$base_dir/check-agents.sh" --no-respawn
fi
exec "$base_dir/check-agents.sh" "$@"

