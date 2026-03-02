---
name: init-spec
description: "Shortcut command for scripts/init-spec.sh. Slash name is sanitized to /init_spec. Usage: /init_spec --repo <path> --name <spec-name> [--preset basic|build-artifact]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash"] } } }
---

# Init Spec Shortcut

Run `scripts/init-spec.sh` from the workspace root to generate no-PR spec files in one command.

## Behavior

- Treat everything after the slash command as raw CLI args for the script.
- If no args are provided, run `./scripts/init-spec.sh --help`.
- Execute:

```bash
cd <workspace-root>
./scripts/init-spec.sh <raw args>
```

- Return:
  - command run
  - exit status
  - created spec path when successful
  - actionable failure reason when unsuccessful

## Command Name Note

OpenClaw sanitizes skill command names to `a-z0-9_`, so this skill is invoked as:

```bash
/init_spec ...
```

You can also call it explicitly via:

```bash
/skill init-spec ...
```

## Examples

```bash
/init_spec --repo /path/to/repo --name docs-sync
```

```bash
/init_spec --repo /path/to/repo --name web-build --preset build-artifact
```
