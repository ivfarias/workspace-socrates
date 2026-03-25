# Socrates Workspace

Socrates is a shareable OpenClaw workspace that runs a deterministic, multi-agent orchestration loop for software delivery.
Instead of ad-hoc prompt sessions, it gives you a repeatable control plane for spawning agent tasks, tracking progress, enforcing done gates, and monitoring retries.

## What it does

* Initializes isolated git worktrees per task/branch.
* Spawns coding agents in dedicated tmux sessions according to their strengths (codex for backend, gemini for ui/ux and claude for frontend).
* Tracks runtime state in .clawdbot/active-tasks.json.
* Monitors each task for session health, PR status, CI status, branch freshness, and reviewer gates.
* Marks tasks done only when configured completion criteria pass.
* Auto-respawns/nudges failed tasks within retry limits.
* Supports both PR-driven delivery and no-PR spec-driven execution.

## How It Works

* `scripts/init-worktree.sh` creates an isolated worktree and optionally installs dependencies.
* `scripts/spawn-agent.sh` launches the selected agent (`codex`, `claude`, `gemini`, `openclaw`, or `custom`) and registers task metadata.
* `scripts/start-monitoring.sh` runs one-shot or looped checks via `scripts/check-agents.sh`.
* `scripts/check-agents.sh` evaluates completion gates and retry policy, then updates task state in-place.
* `scripts/bootstrap-task.sh` chains worktree init + agent spawn into a single command.

## Key Features

* Deterministic orchestration with shell scripts + JSON registry.
* Multi-agent model routing by task type (`backend-complex`, `frontend-ui`, `ux-design`, etc.).
* Concurrency controls:
  * total concurrent agents
  * separate cap for heavy task types
* Retry controls:
  * max attempts
  * auto-respawn on session exit / CI failure / critical review failures
* PR completion gates:
  * PR created
  * CI passed
  * branch up-to-date
  * Codex/Claude/Gemini review signals
  * optional screenshot requirement
* No-PR completion gates via spec file checks:
  * `file_exists`
  * `file_contains` (regex)
  * `command` exit-code validation
* Full observability:
  * runtime launch scripts in `.clawdbot/runtime/`
  * per-task logs in `.clawdbot/logs/`
  * machine-readable task state in `.clawdbot/active-tasks.json`
* Idempotent installer (`install-socrates.sh`) that registers the workspace agent, applies identity/avatar, and preserves existing model defaults unless explicitly overridden.

## Requirements

* `openclaw` CLI
* `git`
* `jq`
* `tmux`
* `gh` (recommended for PR/CI/reviewer checks)
* Optional, depending on agent choice:
  * `codex` CLI
  * `claude` CLI
  * `gemini` CLI

## Easiest Way To Get Started

```bash
git clone https://github.com/ivfarias/workspace-socrates.git ~/.openclaw/workspace-socrates
cd ~/.openclaw/workspace-socrates
./scripts/install-socrates.sh --agent-id socrates
openclaw configure
openclaw agent --agent socrates --message "Hello Socrates"
```

## First Real Task (One Command)

* To create a task you'll need two things: 1) Your repository URL and 2) A general idea of what needs to be built.
* Run /open_agora and tell Socrates what to build.
* If the task isn't clear enough yet, it'll ask you a few questions in order to create the initial task prompt.
* After that, it'll run things on its own.

```bash
./scripts/bootstrap-task.sh \
  --repo /path/to/repo \
  --id feat-example \
  --branch feat/example \
  --agent codex \
  --task-type backend-complex \
  --description "Implement feature X" \
  --prompt-file /path/to/prompt.md
```

Then monitor:

```bash
./scripts/start-monitoring.sh --once
```

Detailed setup guide: [SETUP.md](SETUP.md)
Guia rapido em Portugues (PT-BR): [QUICKSTART.pt-BR.md](QUICKSTART.pt-BR.md)

## Thematic Commands

- Install/register agent: `./scripts/awaken-socrates.sh`
- Spawn one task: `./scripts/summon-interlocutor.sh`
- Init + spawn in one step: `./scripts/convene-council.sh`
- Reviewer gate verification: `./scripts/form-check.sh`

For complete command reference and thematic alias documentation, see **ORCHESTRATION.md § Thematic Aliases**.


## Model Behavior

Installer defaults:
- Inherit each user's existing OpenClaw model setup (no forced override).
- Optional per-agent override: `--model-primary <id>` plus repeatable `--fallback <id>`.
- Optional interactive prompt: `--wizard-model`.
- Optional global defaults write (explicit only): `--set-global-model-defaults`.

## Important Runtime Note

OpenClaw runtime reads global config at `~/.openclaw/openclaw.json`, not only workspace `openclaw.json`.  
The installer updates global config to register this workspace as an agent.

## Sharing Safety

- `openclaw.template.json` is the safe baseline.
- `openclaw.json` is sanitized (no personal routing/credentials).
- Runtime/private artifacts are excluded by `.gitignore`.

## Workflow

- PR mode: `./scripts/bootstrap-task.sh ... --completion-mode pr`
- No-PR mode: `./scripts/init-spec.sh ...` then `./scripts/bootstrap-task.sh ... --completion-mode no-pr-spec`
- Monitor: `./scripts/start-monitoring.sh --once`
- Web search (no API key): `./scripts/ddg-search.sh --query "..." --max-results 5` or `/ddg_search --query "..."`

Full runbook: [ORCHESTRATION.md](ORCHESTRATION.md)
