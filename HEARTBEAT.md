# HEARTBEAT.md

## Active Task Monitor

### kai-nanobot-openclaw-orchestration-refactor
- **Check:** `cat /Users/ivanfarias/.openclaw/workspace-ceo/.clawdbot/active-tasks.json | grep '"status"'`
- **tmux session:** `ceo-kai-nanobot-openclaw-orchestration-refactor`
- **Done when:** status = `done` OR PR created (`prCreated: true`)
- **Action:** Notify Ivan on WhatsApp when done or if status = `failed`
- **Peek at progress:** `tmux capture-pane -t ceo-kai-nanobot-openclaw-orchestration-refactor -p | tail -20`

## Early Sanity Check (do this ~2-3 min after any agent spawn)

After spawning a coding agent, check within 2-3 minutes:
1. `tmux capture-pane -t <session> -p | tail -20` — is it making progress or showing errors?
2. Look for: auth errors, model not found, MCP failures, stalled prompts
3. If anything looks wrong → fix if possible, otherwise WhatsApp Ivan immediately
4. Don't wait for the next heartbeat — act on errors as soon as spotted

## Coding Agent Rules (learned the hard way)

- Never pass `--model` to bootstrap-task.sh for Codex — let it use `~/.codex/config.toml` defaults
- `openai/gpt-5-codex` is NOT a valid model string for Codex CLI — omit model override entirely
- Always do a 2-3 min post-spawn sanity check before declaring "agent is running"
