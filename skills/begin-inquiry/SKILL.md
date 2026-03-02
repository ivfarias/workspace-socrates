---
name: begin-inquiry
description: "Alternate thematic alias for spec initialization. Usage: /begin_inquiry --repo <path> --name <spec-name> [--preset basic|build-artifact]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash"] } } }
---

# Begin Inquiry

Alternate thematic entrypoint for no-PR spec scaffold generation.

## Behavior

- Treat everything after `/begin_inquiry` as raw args.
- If no args are provided, run `./scripts/begin-inquiry.sh --help`.
- Execute:

```bash
./scripts/begin-inquiry.sh <raw args>
```

