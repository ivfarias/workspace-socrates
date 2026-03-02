---
name: form-check
description: "Thematic alias for reviewer gate checks. Usage: /form_check --repo <path> --pr <number>"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "gh"] } } }
---

# Form Check

Run PR reviewer validation via thematic alias.

## Behavior

- Treat everything after `/form_check` as raw args.
- If no args are provided, run `./scripts/form-check.sh --help`.
- Execute:

```bash
./scripts/form-check.sh <raw args>
```

