---
name: start-elenchus
description: "Thematic alias for spec initialization. Usage: /start_elenchus --repo <path> --name <spec-name> [--preset basic|build-artifact]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash"] } } }
---

# Start Elenchus

Run the spec scaffold initializer via thematic alias.

## Behavior

- Treat everything after `/start_elenchus` as raw args.
- If no args are provided, run `./scripts/start-elenchus.sh --help`.
- Execute:

```bash
./scripts/start-elenchus.sh <raw args>
```

