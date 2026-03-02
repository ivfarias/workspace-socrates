---
name: summon-interlocutor
description: "Thematic alias for spawning one agent task. Usage: /summon_interlocutor --id <task-id> --agent <codex|claude|gemini|openclaw|custom> --description \"...\" --worktree <path> [options]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "tmux"] } } }
---

# Summon Interlocutor

Run the single-task spawn script via thematic alias.

## Behavior

- Treat everything after `/summon_interlocutor` as raw args.
- If no args are provided, run `./scripts/summon-interlocutor.sh --help`.
- Execute:

```bash
./scripts/summon-interlocutor.sh <raw args>
```

