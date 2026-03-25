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
- Starts a dedicated tmux session (`socrates-<task-id>`)
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

## 2.7) Thematic Aliases (Optional)

The orchestration layer supports Socratic naming aliases without changing core behavior.
Plain commands remain canonical; aliases are wrappers.

- Install/register Socrates:
  - Plain: `./scripts/install-socrates.sh`
  - Alias: `./scripts/awaken-socrates.sh`
- Spawn one task:
  - Plain: `./scripts/spawn-agent.sh`
  - Alias: `./scripts/summon-interlocutor.sh`
- Init + spawn in one step:
  - Plain: `./scripts/bootstrap-task.sh`
  - Alias: `./scripts/convene-council.sh`
- Reviewer gate checks:
  - Plain: `./scripts/verify-reviewers.sh`
  - Alias: `./scripts/form-check.sh`
- Brainstorming-first prompt/spec drafting:
  - Plain: `/brainstorming_prompt_file`
  - Alias: `/open_agora`
- No-PR spec scaffold bootstrap:
  - Plain: `./scripts/init-spec.sh`
  - Alias: `./scripts/begin-inquiry.sh`
- Deterministic registry decision gate:
  - Plain: `./scripts/check-agents.sh --no-respawn`
  - Alias: `./scripts/rule-of-reason.sh`
- One-shot monitor status return:
  - Plain: `./scripts/start-monitoring.sh --once`
  - Alias: `./scripts/return-to-agora.sh`
- PR reviewer triad gate:
  - Plain: `./scripts/verify-reviewers.sh`
  - Alias: `./scripts/form-check.sh`

Compatibility rule:
- Any new theme alias should only delegate to a canonical script.
- Automation and docs should reference both names side-by-side.
- Slash equivalents exist for chat mode:
  - `/start_elenchus`, `/begin_inquiry`, `/rule_of_reason`, `/return_to_agora`, `/dialectic_check`

## 2.8) Harness Patterns (Agent Reliability)

These conventions are applied automatically when using `bootstrap-task.sh`. They implement the
*Agent-Computer Interface* (ACI) patterns from the harness engineering research.

### Progress File (Item 1)

Every spawned task automatically creates `.agent-progress.md` in the worktree if it doesn't exist.
Agents must:
- Read it at **session start** (before writing any code)
- Update it at **session end** (before the final commit)

The registry tracks it as `progressFile`.

### JSON Feature List (Item 2)

Use `init-spec.sh --with-feature-list` to generate both a completion spec and a `feature_list.json`
at the repo root. See `prompts/feature_list.template.json` for the expected schema.

Rules enforced in agent prompts:
- Never remove or modify feature descriptions
- Only set `passes: true` after end-to-end verification

### Startup Sequence (Item 3)

See `STARTUP.md` for the canonical 6-step startup sequence. It is embedded in `prompts/coding-agent.md`
and `prompts/initializer-agent.md`.

### Lint-on-Edit & Search Cap (Items 4–5)

Enforced via prompt instructions in `prompts/coding-agent.md`:
- Run linter on every modified file; revert on failure
- Cap all search output at 50 lines; narrow query if truncated

### Phase-Based Bootstrapping (Item 6)

`bootstrap-task.sh` accepts `--phase initializer|coding`:

```bash
# Phase 1: scaffolding session (creates init.sh, feature_list.json, .agent-progress.md)
./scripts/bootstrap-task.sh \
  --repo /path/to/repo \
  --id feat-init \
  --branch feat/my-feature \
  --agent claude \
  --phase initializer \
  --description "Build a user authentication system"

# Phase 2+: coding sessions (pick next feature, implement, verify, commit)
./scripts/bootstrap-task.sh \
  --repo /path/to/repo \
  --id feat-coding-001 \
  --branch feat/my-feature \
  --agent codex \
  --phase coding \
  --description "Implement user authentication"
```

When `--prompt-file` is omitted, `bootstrap-task.sh` auto-selects:
- `prompts/initializer-agent.md` for `--phase initializer`
- `prompts/coding-agent.md` for `--phase coding`

You can always override with an explicit `--prompt-file`.

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
*/10 * * * * cd /path/to/workspace-socrates && ./scripts/start-monitoring.sh --once >> .clawdbot/logs/cron-monitor.log 2>&1
15 2 * * * cd /path/to/workspace-socrates && ./scripts/cleanup-orphans.sh --done-older-hours 24 --apply >> .clawdbot/logs/cron-cleanup.log 2>&1
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

## 7) Model Mapping

Two layers are configured independently:

- Socrates agent runtime (`openclaw.json`): can use `github-copilot/*` models.
- Orchestration task routing (`.clawdbot/config.json`): routes direct Codex/Claude/Gemini models for spawned coding tasks.

Current task routing defaults in `.clawdbot/config.json`:
- `backend-complex` -> `gpt-5.3-codex`
- `frontend-ui` -> `claude-sonnet-4.6`
- `ux-design` -> `gemini-2.5-pro`

## 8) Reviewer Verification

```bash
./scripts/verify-reviewers.sh --repo /path/to/repo --pr 123
```

This validates whether Codex/Claude/Gemini reviewer signals are present on a PR.

## 9) Post-Completion Review Pipeline (Automated)

When `check-agents.sh` detects a task has met all done criteria, Phase 9 automation triggers:

### Architecture: Modular Orchestration

Post-completion orchestration is separated into focused layers:
- **check-agents.sh** - Detects done transitions, sets `phase9_status = "simplify_pending"`
- **trigger-phase9.sh** - Orchestrates Phase 9 workflow (spawns simplify, tracks completion)
- **start-monitoring.sh** - Calls trigger-phase9.sh after every check-agents run

This keeps each script focused and maintainable.

### Active-Tasks Schema: Phase 9 Fields

When a task is spawned, these fields track post-completion workflow:

```json
{
  "id": "task-id",
  "status": "done",
  "phase9_status": "simplify_pending|simplify_running|review_pending|review_in_progress|review_completed|finishing_pending",
  "simplify_completed": false,
  "review_cycles": 0,
  "review_status": "not_started|in_progress|complete",
  "review_signature": ""
}
```

**Field meanings:**
- `phase9_status` - Current stage of post-completion pipeline
- `simplify_completed` - Simplify pass finished (cleanup committed)
- `review_cycles` - Count of review-implement cycles (0-5)
- `review_status` - Explicit completion signal from review loop
- `review_signature` - Agent's final message ("ready", "complete", etc.)

### Stage 1: Automatic Simplify Review

When task reaches `done` status:

1. `check-agents.sh` detects transition → sets `phase9_status = "simplify_pending"`
2. `trigger-phase9.sh` (called by `start-monitoring.sh`) → spawns simplify task
   - Task ID: `<task-id>-simplify`
   - Runs: `simplify` skill (3 parallel agents: reuse review, quality review, efficiency review)
   - Worktree: Same as parent task
   - Branch: Same as parent task
3. Simplify runs 3 agents reviewing changed files
4. Issues found and fixed → changes committed
5. When simplify task reaches done:
   - `trigger-phase9.sh` propagates: `simplify_completed = true`
   - Updates parent task: `phase9_status = "review_pending"`

```bash
# Example simplify completion spec generated automatically:
{
  "completionMode": "no-pr-spec",
  "checks": [
    {"type": "file_contains", "path": ".socrates/simplify-report.json", "pattern": "session_complete"},
    {"type": "command", "command": "npm test && echo ok"}
  ]
}
```

### Stage 2: Deterministic Code Review Loop (ralph-loop-coordinator)

After simplify completes:

1. `check-agents.sh` detects done transition for `<task-id>-simplify`
2. `trigger-phase9.sh` propagates to parent: `phase9_status = "review_pending"`
3. `trigger-phase9.sh` detects parent with `review_pending` → spawns ralph-loop task
   - Task ID: `<task-id>-ralph`
   - Runs: `ralph-loop-coordinator` skill (orchestrates review cycles)
   - Worktree: Same as parent task
   - Branch: Same as parent task
4. Ralph-loop cycles (max 5):
   - Cycle 1-N: Request review → User implements → Re-request
   - Exit condition: "ready" signal OR "no issues found" OR cycle >= 5
5. When ralph-loop task reaches done:
   - `trigger-phase9.sh` propagates: `review_completed = true`, `review_cycles = N`, `review_signature = "..."`
   - Updates parent task: `phase9_status = "finishing_pending"`

**See:** `skills/ralph-loop-coordinator/SKILL.md` for full review loop details.

```bash
# Ralph-loop spawning (automatic, no user action needed)
trigger-phase9.sh sees: task.phase9_status = "review_pending"
  ↓
Spawns: <task-id>-ralph via bootstrap-task.sh
  ↓
Ralph orchestrates: request → implement → re-request
  ↓
On completion: propagates to parent, moves to Stage 3
```

### Stage 3: Branch Completion

After review complete:

1. Invoke `finishing-a-development-branch` skill
2. Present merge options (merge to main, create PR, keep, discard)
3. User chooses integration path

## 10) Dynamic Task Monitoring via Cron

Socrates uses OpenClaw's cron API to poll task status every 3 minutes while agents are working.

### Create Watcher (after spawning a task)

```bash
openclaw cron add \
  --name "task-watcher-<TASK_ID>" \
  --at "3m" \
  --session main \
  --system-event "Active task check: run ./scripts/start-monitoring.sh --once in workspace-socrates, then report any status changes to the user. If a task reached 'done', trigger the review pipeline per §9." \
  --wake now
```

### Re-schedule (on each cron trigger, if tasks still running)

```bash
# Same command — cron expired after firing, so re-create it
openclaw cron add \
  --name "task-watcher-<TASK_ID>" \
  --at "3m" \
  --session main \
  --system-event "Active task check: run monitoring and report." \
  --wake now
```

### Cleanup (when no tasks remain)

```bash
# List and remove all task-watcher crons
openclaw cron list | grep "task-watcher"
openclaw cron rm <job-id>
```

### Why Cron, Not Heartbeat?

Heartbeat interval is a fixed config value (currently 5m). Cron allows on-demand 3-minute polling that self-terminates when no tasks remain — no wasted tokens during idle periods.
