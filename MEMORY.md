# MEMORY.md

## Long-Term

- This workspace is focused on orchestrating parallel coding agents with OpenClaw as control plane.
- Deterministic shell scripts + JSON task registry are preferred over prompt-heavy polling for lower cost.
- Done-state is gated by PR + CI + reviewer signals, not just "PR created."
- GitHub-dependent checks require valid `gh` authentication; keep token/session healthy to avoid silent reviewer/CI visibility gaps.
- For internal/ops work without PRs, use spec-driven completion (`completionMode=no-pr-spec`) with explicit evidence checks.
- When spawning Codex agents: avoid forcing invalid model ids; rely on valid local Codex defaults unless a task explicitly requires override.
- Claude Code in `run-agent.sh` must use `--permission-mode bypassPermissions --print` (not `--dangerously-skip-permissions`). `--print` is the correct non-interactive flag; `bypassPermissions` gives full tool access.
- When Codex is rate-limited, switch `.clawdbot/config.json` profiles and `agentDefaults.codex` to `claude-sonnet-4-6`, and use `--agent claude` in spawn calls. Revert when Codex comes back.
- After spawning any coding agent, do a sanity check within 2-3 minutes: `tmux capture-pane -t <session> -p | tail -20`.
- Route completion/failure notifications through each operator's own configured channel (not hardcoded in shared files).
- **`run-agent.sh` bug (2026-03-25, fix in flight on `fix/run-agent-stdin`):** The claude branch passes the prompt as a positional arg (`"$prompt"`) which silently fails for large files. Claude Code requires input via stdin. Fix: `exec claude ... < "$prompt_file"`. Do NOT work around this with wrapper scripts — if a script is broken, report it, write a plan, spawn the correct agent per task-nature rules, stop.
- **Never modify `.clawdbot/config.json`, `.clawdbot/active-tasks.json`, or `scripts/*.sh` directly.** These are infrastructure. Report anomalies, spawn the right agent to fix them.
- **Agent selection is mandatory, not inferred from config profiles.** Task nature determines the agent — backend/scripts → Codex, frontend/UI → Claude, UX/design → Gemini. Never let a config profile override this.
- **Cron watcher pattern for Socrates:** Use the `cron` tool with `sessionTarget: "current"` and `payload.kind: "agentTurn"`. The CLI `--session main --system-event` pattern does not work for this agent.
