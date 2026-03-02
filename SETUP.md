# Socrates Setup Guide

Use this guide to install Socrates on any machine with OpenClaw.

Portuguese quick start: [QUICKSTART.pt-BR.md](QUICKSTART.pt-BR.md)

## 1) Clone Workspace

```bash
git clone <this-repo-url> ~/.openclaw/workspace-socrates
cd ~/.openclaw/workspace-socrates
```

## 2) Install Agent

```bash
./scripts/install-socrates.sh --agent-id socrates
```

Thematic alias:

```bash
./scripts/awaken-socrates.sh --agent-id socrates
```

## 3) Optional Model Overrides

Only use overrides if you do not want to inherit your current OpenClaw defaults.

```bash
./scripts/install-socrates.sh --agent-id socrates --model-primary claude-sonnet-4.6 --fallback claude-opus-4.6
./scripts/install-socrates.sh --agent-id socrates --wizard-model
```

Optional: make `socrates` the default agent:

```bash
./scripts/install-socrates.sh --agent-id socrates --set-default
```

## 4) Connect Your Auth + Channels

```bash
openclaw configure
```

Use your own accounts/tokens. Do not share credentials.

## 5) Verify

```bash
openclaw agents list --json | jq '.[] | select(.id=="socrates")'
openclaw agent --agent socrates --message "Hello Socrates"
```

## Notes

- Installer updates local global config (`~/.openclaw/openclaw.json`) by default.
- Installer applies identity from `IDENTITY.md`, including avatar when present.
- Installer is idempotent: running again updates the same agent entry.
- By default it inherits existing model setup.
- It only changes model values with `--model-primary`, `--fallback`, or `--wizard-model`.
- It only writes `agents.defaults.model.*` if `--set-global-model-defaults` is passed.
- It configures DuckDuckGo-first web mode:
  - `tools.web.search.enabled=false`
  - `tools.web.fetch.enabled=true`
