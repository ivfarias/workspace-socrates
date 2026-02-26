#!/usr/bin/env bash
set -euo pipefail
cd /tmp/openclaw-e2e-1772122494/.worktrees/feat-e2e-local-smoke2
exec /Users/ivanfarias/.openclaw/workspace-ceo/scripts/run-agent.sh --agent custom --model github-copilot/claude-opus-4.6 --description Local\ orchestration\ smoke\ test\ 2 --task-id e2e-local-smoke2 --reasoning-effort high --command echo\ \'\[E2E2\]\ agent\ started\'\;\ sleep\ 8\;\ echo\ \'\[E2E2\]\ done\' 
