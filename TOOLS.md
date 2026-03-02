# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## WhatsApp

- Add your own alert target(s) here after onboarding.
- Do not commit personal phone numbers or account ids.

## Web Search (DuckDuckGo, No API Key)

- Socrates uses DuckDuckGo search via `uvx` + `duckduckgo-search` (no Brave key required).
- Run directly:
  - `./scripts/ddg-search.sh --query "your topic" --max-results 5`
- Run via slash skill:
  - `/ddg_search --query "your topic" --max-results 5`
- One-time dependency check:
  - `uvx --from duckduckgo-search ddgs --help`

### Runtime Config Note

- The installer sets Brave web search off and keeps web fetch on in `~/.openclaw/openclaw.json`:
  - `tools.web.search.enabled=false`
  - `tools.web.fetch.enabled=true`

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.
