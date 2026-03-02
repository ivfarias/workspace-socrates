---
name: awaken-socrates
description: "Thematic alias for installer bootstrap. Usage: /awaken_socrates [--agent-id <id>] [--workspace <path>] [--set-default] [--model-primary <id>] [--fallback <id>] [--wizard-model]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "openclaw"] } } }
---

# Awaken Socrates

Run the Socrates installer via thematic alias.

## Behavior

- Treat everything after `/awaken_socrates` as raw args.
- If no args are provided, run `./scripts/awaken-socrates.sh --help`.
- Execute:

```bash
./scripts/awaken-socrates.sh <raw args>
```

