# HEARTBEAT.md

## Orchestration Check

Run these in this workspace:

1. `./scripts/start-monitoring.sh --once`
2. `./scripts/check-agents.sh`
3. If a task is stuck, inspect:
   `tmux capture-pane -t <session-name> -p | tail -20`

## Alerting

- Use the operator's configured channel/account in their personal OpenClaw setup.
- Do not hardcode personal phone numbers, names, or private endpoints here.

## Quick Rules

- Do a sanity check within 2-3 minutes after each agent spawn.
- If auth/model/tooling errors appear, escalate immediately (do not wait for next heartbeat).
