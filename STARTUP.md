# STARTUP.md — Agent Session Startup Sequence

Every coding agent session must complete these steps **before writing any code**.

## Mandatory Startup Steps

```
1. pwd                          → confirm you are in the right worktree
2. cat .agent-progress.md       → understand what was done last session
3. cat feature_list.json        → identify the next incomplete feature
4. git log --oneline -10        → review recent commit history
5. bash init.sh                 → start the dev environment (if init.sh exists)
6. [run smoke test]             → if startup test fails, fix it before adding new code
```

Only after all six steps: pick **exactly one** feature to work on.

## Search Cap Rule

Never let a search flood your context:

```bash
grep -rn "pattern" src/ | head -50   # always cap output
```

If results are truncated → narrow the query. Do not search more broadly.

## Lint-on-Edit Rule

After every file change: run the linter on the modified file.  
If linting fails: revert and fix before continuing.

## Session End Checklist

```
1. git add -A && git commit -m "feat: <what you built>"
2. Update .agent-progress.md (what was done, what remains, state of code)
3. Confirm tests still pass
```

The session is not done until there is a clean commit and `.agent-progress.md` is updated.

---

*This file is the canonical reference. The `prompts/coding-agent.md` template embeds these rules directly into agent prompts.*
