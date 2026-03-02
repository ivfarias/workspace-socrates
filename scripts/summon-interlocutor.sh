#!/usr/bin/env bash
set -euo pipefail

# Thematic alias: spawn one agent task in an existing worktree.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/spawn-agent.sh" "$@"

