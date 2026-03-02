# MEMORY.md

## Long-Term

- This workspace is focused on orchestrating parallel coding agents with OpenClaw as control plane.
- Deterministic shell scripts + JSON task registry are preferred over prompt-heavy polling for lower cost.
- Done-state is gated by PR + CI + reviewer signals, not just "PR created."
- GitHub-dependent checks require valid `gh` authentication; keep token/session healthy to avoid silent reviewer/CI visibility gaps.
- For internal/ops work without PRs, use spec-driven completion (`completionMode=no-pr-spec`) with explicit evidence checks.
- When spawning Codex agents: avoid forcing invalid model ids; rely on valid local Codex defaults unless a task explicitly requires override.
- After spawning any coding agent, do a sanity check within 2-3 minutes: `tmux capture-pane -t <session> -p | tail -20`.
- Route completion/failure notifications through each operator's own configured channel (not hardcoded in shared files).
- **NEVER pass prompt file content inline via `$(cat file)` or shell substitution into tmux/codex commands.** The content gets interpreted as shell commands and explodes. Always write a wrapper script (`/tmp/run-<task>.sh`) that reads the file internally and passes it as a variable, then execute the wrapper. Pattern:
  ```bash
  cat > /tmp/run-task.sh << 'SCRIPT'
  #!/bin/bash
  cd /path/to/repo
  PROMPT=$(cat /path/to/prompt.md)
  codex --full-auto exec "$PROMPT"
  SCRIPT
  chmod +x /tmp/run-task.sh
  tmux send-keys -t <session> "/tmp/run-task.sh" Enter
  ```
