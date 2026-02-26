#!/usr/bin/env bash
set -euo pipefail
cd /tmp/openclaw-nopr-1772123903/.worktrees/chore-nopr-spec-smoke
exec /Users/ivanfarias/.openclaw/workspace-ceo/scripts/run-agent.sh --agent custom  --description No\ PR\ spec\ smoke --task-id nopr-spec-smoke --reasoning-effort high --command mkdir\ -p\ artifacts\;\ echo\ \'PASS\ from\ agent\'\ \>\ artifacts/result.txt\;\ sleep\ 3 
