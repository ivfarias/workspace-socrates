---
name: dialectic-check
description: "Thematic alias for PR reviewer gate checks. Usage: /dialectic_check --repo <path> --pr <number>"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "gh"] } } }
---

# Dialectic Check

Run PR reviewer triad validation via thematic alias.

## Behavior

- Treat everything after `/dialectic_check` as raw args.
- If no args are provided, run `./scripts/dialectic-check.sh --help`.
- Execute:

```bash
./scripts/dialectic-check.sh <raw args>
```

