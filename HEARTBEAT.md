# HEARTBEAT.md

## State-Aware Heartbeat Logic

On every heartbeat, follow this decision tree:

### Step 1: Check for Active Tasks

```bash
# Get counts in one pass to avoid parsing JSON twice
eval $(jq -r 'map(select(.status | in({"running":1, "retrying":1, "done":1}))) | "ACTIVE=\(map(select(.status != "done")) | length)\nDONE=\(map(select(.status == "done")) | length)"' .clawdbot/active-tasks.json)
```

### Step 2: If Tasks Are Running (ACTIVE > 0)

1. Run: `./scripts/start-monitoring.sh --once`
2. If a task **changed status** (new `done`, `needs_attention`, or `retrying`) → message the user
3. If a task reached **`done`** → trigger the review pipeline (see ORCHESTRATION.md §9):
   - Spawn a `simplify` review session against the task's worktree
   - Report results to user
   - Ask if they want a deeper code review
4. Verify cron watcher exists: `openclaw cron list | grep "task-watcher"`
   - If no watcher exists → re-create it (it may have expired or been deleted):
     ```bash
     openclaw cron add --name "task-watcher-<id>" --at "3m" --session main \
       --system-event "Active task check: run monitoring and report." --wake now
     ```
5. If tasks are still running and nothing changed → `HEARTBEAT_OK`

### Step 3: If Tasks Just Completed (ACTIVE == 0, DONE > 0 recently)

1. Remove leftover task-watcher crons: `openclaw cron rm <job-id>`
2. Report final status to user if not already reported
3. Fall through to Step 4

### Step 4: If No Tasks Running (ACTIVE == 0)

Fall back to normal periodic checks (rotate through 2–4 per day):

- **Emails** — urgent unread messages?
- **Calendar** — upcoming events in next 24–48h?
- **Mentions** — Twitter/social notifications?
- **Weather** — relevant if your human might go out?

If nothing needs attention → `HEARTBEAT_OK`

## Alerting Rules

- Use the operator's configured channel/account, not hardcoded endpoints.
- Do a sanity check within 2–3 minutes after each agent spawn.
- If auth/model/tooling errors appear, escalate immediately (don't wait for next heartbeat).

## Quick Truth Table

| Active Tasks? | Status Changed? | Action |
|---|---|---|
| Yes | Yes (done/attention/retry) | Message user, trigger review if done |
| Yes | No | `HEARTBEAT_OK` (watcher is polling) |
| No | N/A | Cleanup watchers, normal heartbeat checks |
