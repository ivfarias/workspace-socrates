# MEMORY.md

## Long-Term

- This workspace is focused on orchestrating parallel coding agents with OpenClaw as control plane.
- Deterministic shell scripts + JSON task registry are preferred over prompt-heavy polling for lower cost.
- Done-state is gated by PR + CI + reviewer signals, not just "PR created."
- GitHub-dependent checks require valid `gh` authentication; keep token/session healthy to avoid silent reviewer/CI visibility gaps.
- For internal/ops work without PRs, use spec-driven completion (`completionMode=no-pr-spec`) with explicit evidence checks.
- When spawning Codex agents: never pass `--model` override — let Codex use `~/.codex/config.toml` defaults. `openai/gpt-5-codex` is not a valid model string for the Codex CLI.
- After spawning any coding agent, do a sanity check within 2-3 minutes: `tmux capture-pane -t <session> -p | tail -20`. Look for auth errors, stalled prompts, model errors. Don't wait for heartbeat — WhatsApp Ivan immediately if something is wrong.
