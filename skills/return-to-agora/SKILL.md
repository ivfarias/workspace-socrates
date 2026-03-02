---
name: return-to-agora
description: "Thematic alias for monitoring tick. Usage: /return_to_agora [--once] [--interval-seconds <n>]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash"] } } }
---

# Return to Agora

Run monitor checks and return current orchestration status.

## Behavior

- Treat everything after `/return_to_agora` as raw args.
- If no args are provided, run `./scripts/return-to-agora.sh` (defaults to one monitor tick).
- Execute:

```bash
./scripts/return-to-agora.sh <raw args>
```

