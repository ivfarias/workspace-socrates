---
name: duckduckgo-search
description: "No-key web search via DuckDuckGo. Usage: /ddg_search --query \"...\" [--max-results 5] [--region us-en] [--timelimit d|w|m|y]"
user-invocable: true
metadata: { "openclaw": { "requires": { "bins": ["bash", "uvx"] } } }
---

# DuckDuckGo Search

Run no-key web search through DuckDuckGo using the local script.

## Behavior

- Treat everything after `/ddg_search` as raw args for `scripts/ddg-search.sh`.
- If no args are provided, run:

```bash
./scripts/ddg-search.sh --help
```

- Execute:

```bash
./scripts/ddg-search.sh <raw args>
```

- Return a concise summary:
  - query used
  - top result titles/links
  - note if search returned zero results

## Examples

```bash
/ddg_search --query "OpenClaw agent setup" --max-results 5
```

```bash
/ddg_search --query "tmux send-keys examples" --region us-en --timelimit m
```
