---
name: install-agent
description: "Shortcut command for scripts/install-socrates.sh. Usage: /install_agent [--agent-id <id>] [--workspace <path>] [--set-default] [--model-primary <id>] [--fallback <id>] [--wizard-model]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "openclaw"] } } }
---

# Install Agent Shortcut

Run `scripts/install-socrates.sh` from this workspace root to register Socrates using native OpenClaw config updates.

## Behavior

- Treat everything after `/install_agent` as raw CLI args.
- If no args are provided, run `./scripts/install-socrates.sh --help`.
- Execute:

```bash
./scripts/install-socrates.sh <raw args>
```

## Examples

```bash
/install_agent --agent-id socrates
```

```bash
/install_agent --agent-id socrates --set-default
```

```bash
/install_agent --agent-id socrates --model-primary claude-sonnet-4.6 --fallback claude-opus-4.6
```
