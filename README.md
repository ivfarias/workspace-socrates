# Socrates Workspace

Shareable OpenClaw workspace for a Socrates-style orchestration agent.

It includes:
- agent orchestration scripts (`scripts/`)
- task registry + monitor flow (`.clawdbot/`)
- slash-invocable skills (`/bootstrap`, `/init_spec`, `/install_agent`, `/ddg_search`)
- thematic aliases (for a philosophy-themed UX)

## Quick Start

```bash
git clone <repo-url> ~/.openclaw/workspace-socrates
cd ~/.openclaw/workspace-socrates
./scripts/install-socrates.sh --agent-id socrates
openclaw configure
openclaw agent --agent socrates --message "Hello Socrates"
```

Detailed setup guide: [SETUP.md](SETUP.md)
Guia rapido em Portugues (PT-BR): [QUICKSTART.pt-BR.md](QUICKSTART.pt-BR.md)

## Plain vs Thematic Commands

Canonical scripts stay plain-English for reliability. Thematic names are compatibility aliases.

- Install/register agent:
  - Plain: `./scripts/install-socrates.sh`
  - Thematic: `./scripts/awaken-socrates.sh`
- Spawn one task:
  - Plain: `./scripts/spawn-agent.sh`
  - Thematic: `./scripts/summon-interlocutor.sh`
- Init + spawn in one step:
  - Plain: `./scripts/bootstrap-task.sh`
  - Thematic: `./scripts/convene-council.sh`
- Reviewer gate verification:
  - Plain: `./scripts/verify-reviewers.sh`
  - Thematic: `./scripts/form-check.sh`
- Brainstorming-first flow:
  - Plain: `/brainstorming_prompt_file`
  - Thematic: `/open_agora`

Additional thematic aliases:
- Inquiry/spec bootstrap:
  - Plain: `./scripts/init-spec.sh`
  - Thematic: `./scripts/start-elenchus.sh`
  - Thematic: `./scripts/begin-inquiry.sh`
- Deterministic decision gate:
  - Plain: `./scripts/check-agents.sh --no-respawn`
  - Thematic: `./scripts/rule-of-reason.sh`
- One-shot monitor + return status:
  - Plain: `./scripts/start-monitoring.sh --once`
  - Thematic: `./scripts/return-to-agora.sh`
- PR reviewer triad check:
  - Plain: `./scripts/verify-reviewers.sh`
  - Thematic: `./scripts/dialectic-check.sh`

Matching slash aliases are available:
- `/start_elenchus`, `/begin_inquiry`, `/rule_of_reason`, `/return_to_agora`, `/dialectic_check`

## Safe Naming Pattern

If you add your own aliases, use this pattern:

- Keep one stable canonical command (`scripts/<plain-name>.sh`).
- Add optional themed wrappers that only delegate (`exec ./scripts/<plain-name>.sh "$@"`).
- Keep slash names short, lowercase, and OpenClaw-safe (`a-z0-9_`).
- Always document both names side-by-side so new users are not blocked by theme vocabulary.

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
