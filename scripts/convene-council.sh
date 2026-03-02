#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: init worktree + spawn task in one command.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap-task.sh" "$@"

