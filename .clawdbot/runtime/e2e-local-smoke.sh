#!/usr/bin/env bash
set -euo pipefail
cd /tmp/openclaw-e2e-1772122494/.worktrees/feat-e2e-local-smoke
exec /Users/ivanfarias/.openclaw/workspace-ceo/scripts/run-agent.sh --agent custom --model github-copilot/claude-opus-4.6 --description Local\ orchestration\ smoke\ test --task-id e2e-local-smoke --reasoning-effort high --command echo\ \'\[E2E\]\ agent\ started\'\;\ sleep\ 30\;\ echo\ \'\[E2E\]\ done\' 
