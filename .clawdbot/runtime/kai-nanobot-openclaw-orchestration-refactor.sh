#!/usr/bin/env bash
set -euo pipefail
cd /Users/ivanfarias/Documents/Development/kyte/kai-v2/kai/.worktrees/feat-kai-nanobot-openclaw-orchestration-refactor
exec /Users/ivanfarias/.openclaw/workspace-ceo/scripts/run-agent.sh --agent codex --model openai/gpt-5-codex --description Refactor\ Kai\ orchestration\ to\ contract-compiled\ runtime\ with\ feature\ flags\,\ ContextAssembler\,\ ContractCompiler\,\ HeartbeatOrchestrator\,\ tenant\ safeguards\,\ and\ hardened\ OpenAI\ run\ path --task-id kai-nanobot-openclaw-orchestration-refactor --reasoning-effort high --prompt-file /Users/ivanfarias/Documents/Development/kyte/kai-v2/kai/tasks/prompts/2026-02-26-kai-nanobot-openclaw-orchestration-refactor.md 
