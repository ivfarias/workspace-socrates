---
name: convene-council
description: "Thematic alias for bootstrap (init worktree + spawn). Usage: /convene_council --repo <path> --id <task-id> --branch <branch> --agent <codex|claude|gemini|openclaw|custom> --description \"...\" [options]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "tmux"] } } }
---

# Convene Council

Run bootstrap orchestration in one command via thematic alias.

## Behavior

- Treat everything after `/convene_council` as raw args.
- If no args are provided, run `./scripts/convene-council.sh --help`.
- Execute:

```bash
./scripts/convene-council.sh <raw args>
```

