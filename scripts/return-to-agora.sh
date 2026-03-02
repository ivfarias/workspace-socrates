#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: one-shot monitor tick by default, loop if args are provided.
base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ $# -eq 0 ]]; then
  exec "$base_dir/start-monitoring.sh" --once
fi
exec "$base_dir/start-monitoring.sh" "$@"

