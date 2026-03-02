---
name: rule-of-reason
description: "Thematic deterministic decision gate over task registry. Usage: /rule_of_reason [--task-id <id>] [--no-respawn]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "jq"] } } }
---

# Rule of Reason

Evaluate active task readiness using deterministic checks.

## Behavior

- Treat everything after `/rule_of_reason` as raw args.
- If no args are provided, run `./scripts/rule-of-reason.sh` (defaults to `--no-respawn`).
- Execute:

```bash
./scripts/rule-of-reason.sh <raw args>
```

