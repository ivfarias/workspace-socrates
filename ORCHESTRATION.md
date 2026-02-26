# OpenClaw Agent Swarm Runbook

This workspace is set up to run a deterministic, low-overhead orchestration loop for Codex/Claude/OpenClaw agents.

## 1) Initialize a Worktree

```bash
./scripts/init-worktree.sh \
  --repo /path/to/repo \
  --branch feat/custom-templates \
  --base origin/main
```

Default worktree root and dependency-install behavior are controlled by `.clawdbot/config.json`.

## 2) Spawn an Agent Task

```bash
./scripts/spawn-agent.sh \
  --id feat-custom-templates \
  --agent codex \
  --completion-mode pr \
  --task-type backend-complex \
  --description "Implement reusable configuration templates" \
  --worktree /path/to/repo/.worktrees/feat-custom-templates \
  --branch feat/custom-templates \
  --repo-path /path/to/repo \
  --prompt-file /path/to/prompt.md \
  --requires-screenshot false
```

What happens automatically:
- Starts a dedicated tmux session (`ceo-<task-id>`)
- Stores runtime metadata in `.clawdbot/active-tasks.json`
- Creates launch script in `.clawdbot/runtime/`
- Captures terminal logs in `.clawdbot/logs/`
- Enforces concurrency caps from `.clawdbot/config.json`

## 2.5) Bootstrap in One Command

```bash
./scripts/bootstrap-task.sh \
  --repo /path/to/repo \
  --id feat-custom-templates \
  --branch feat/custom-templates \
  --agent codex \
  --task-type backend-complex \
  --description "Implement reusable configuration templates" \
  --prompt-file /path/to/prompt.md
```

This chains `init-worktree.sh` and `spawn-agent.sh`.

No-PR spec-based example:

```bash
./scripts/bootstrap-task.sh \
  --repo /path/to/repo \
  --id docs-sync \
  --branch chore/docs-sync \
  --agent custom \
  --completion-mode no-pr-spec \
  --spec-file /path/to/repo/.clawdbot/specs/docs-sync.json \
  --description "Refresh docs artifacts" \
  --command "npm run docs:build"
```

Create spec file in one command:

```bash
./scripts/init-spec.sh --repo /path/to/repo --name docs-sync
```

Then pass the generated file to `--spec-file` in `bootstrap-task.sh` or `spawn-agent.sh`.

## 2.6) OpenClaw Slash Shortcuts

This workspace includes two user-invocable skills mapped to slash commands:

- `/bootstrap ...` → runs `./scripts/bootstrap-task.sh`
- `/init_spec ...` → runs `./scripts/init-spec.sh`

Example:

```bash
/bootstrap --repo /path/to/repo --id feat-custom-templates --branch feat/custom-templates --agent codex --description "Implement reusable templates" --prompt-file /path/to/prompt.md
```

```bash
/init_spec --repo /path/to/repo --name docs-sync
```

Important: skill slash names are sanitized to `a-z0-9_` by OpenClaw. That is why `init-spec` is exposed as `/init_spec`.
If you prefer the original skill name, use:

```bash
/skill init-spec --repo /path/to/repo --name docs-sync
```

## 3) Monitor Tasks

One-off check (cron-friendly):

```bash
./scripts/start-monitoring.sh --once
```

Daemon loop (every N seconds):

```bash
./scripts/start-monitoring.sh --interval-seconds 600
```

The monitor:
- Checks tmux session liveness
- Finds PRs for tracked branches
- Evaluates CI and review signals via `gh`
- Updates status (`running`, `retrying`, `done`, `needs_attention`)
- Auto-respawns or nudges agents up to retry limit

Example crontab:

```bash
*/10 * * * * cd /Users/ivanfarias/.openclaw/workspace-ceo && ./scripts/start-monitoring.sh --once >> .clawdbot/logs/cron-monitor.log 2>&1
15 2 * * * cd /Users/ivanfarias/.openclaw/workspace-ceo && ./scripts/cleanup-orphans.sh --done-older-hours 24 --apply >> .clawdbot/logs/cron-cleanup.log 2>&1
```

## 4) Done Criteria

`completionMode=pr` (default):
- task is marked `done` only when these checks are true:
- `prCreated`
- `ciPassed`
- `branchUpToDate`
- `codexReviewPassed`
- `claudeReviewPassed`
- `geminiReviewPassed`

If `requiresScreenshot=true` on a task, PR body must include an image.

`completionMode=no-pr-spec`:
- task is marked `done` only when:
- agent session has exited
- all checks in `specFile` pass

Supported no-PR spec checks:
- `file_exists`
- `file_contains` (regex pattern)
- `command` (exit code match, optional `cwd`, optional `expectExit`)

Example spec file:

```json
{
  "checks": [
    { "type": "file_exists", "path": "dist/index.js" },
    { "type": "file_contains", "path": "README.md", "pattern": "Generated on" },
    { "type": "command", "cwd": ".", "command": "npm run test:smoke", "expectExit": 0 }
  ]
}
```

Adjust required checks in `.clawdbot/config.json` under:

```json
"doneCriteria": {
  "requiredChecks": [...]
}
```

## 5) Cost + RAM Controls

Configured in `.clawdbot/config.json`:
- `limits.maxConcurrentAgents`
- `limits.maxConcurrentHeavyAgents`
- `limits.heavyTaskTypes`
- `models.profiles` (task-type based model routing)
- `retryPolicy.maxAttempts`

Recommended defaults for 16GB RAM:
- Keep `maxConcurrentAgents` at `3-4`
- Keep heavy UI/E2E work to `1-2` concurrent tasks
- Route heartbeat/monitoring to cheaper models
- Route only complex backend tasks to Codex-level models

## 6) Registry Contract

Task state lives in:

- `.clawdbot/active-tasks.json`

Key fields include:
- `id`, `status`, `attempt`, `maxRetries`
- `agent`, `model`, `taskType`
- `tmuxSession`, `worktree`, `branch`, `repoPath`
- `checks.*` (PR/CI/review/screenshot signals)
- `runtime.launchScript`, `runtime.logFile`

## 7) OpenClaw Model Mapping

`openclaw.json` is pre-wired for cost-aware defaults:
- Primary: `github-copilot/claude-sonnet-4-6`
- Heartbeat: `github-copilot/claude-haiku-4-5`
- Sub-agents: `github-copilot/claude-sonnet-4-6`
- Image model: `openai/gpt-4o`
- TTS summaries: `openai/gpt-4.1-mini`

Per-skill model overrides can be added under `skills.<name>.config.model`.

## 8) Reviewer Verification

```bash
./scripts/verify-reviewers.sh --repo /path/to/repo --pr 123
```

This validates whether Codex/Claude/Gemini reviewer signals are present on a PR.
