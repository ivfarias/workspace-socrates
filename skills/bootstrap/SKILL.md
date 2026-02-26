---
name: bootstrap
description: "Shortcut command for scripts/bootstrap-task.sh. Usage: /bootstrap --repo <path> --id <task-id> --branch <branch> --agent <codex|claude|openclaw|custom> --description \"...\" [options]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash"] } } }
---

# Bootstrap Task Shortcut

Run `scripts/bootstrap-task.sh` from the workspace root so worktree init + agent spawn happen in one command.

## Behavior

- Treat everything after `/bootstrap` as raw CLI args for the script.
- If no args are provided, run `./scripts/bootstrap-task.sh --help`.
- Execute:

```bash
cd /Users/ivanfarias/.openclaw/workspace-ceo
./scripts/bootstrap-task.sh <raw args>
```

- Return a concise result summary:
  - command run
  - exit status
  - task id/session/worktree lines from output (when present)
  - actionable failure reason if command fails

## Examples

```bash
/bootstrap --repo /path/to/repo --id feat-x --branch feat/x --agent codex --description "Implement X" --prompt-file /path/to/prompt.md
```

```bash
/bootstrap --repo /path/to/repo --id docs-sync --branch chore/docs-sync --agent custom --completion-mode no-pr-spec --spec-file /path/to/repo/.clawdbot/specs/docs-sync.json --description "Refresh docs" --command "npm run docs:build"
```
