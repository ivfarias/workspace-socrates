# Coding Agent Prompt Template
#
# Usage: copy this file to your task's --prompt-file, then append your task-specific instructions.
# The scaffold below MUST remain intact; add your task description after the "## Task" section.

## Startup Sequence (complete before writing any code)

Before writing any code, run these steps in order:

1. `pwd` — confirm you are in the correct worktree directory
2. Read `.agent-progress.md` if it exists — understand what was done last session and what remains
3. Read `feature_list.json` if it exists — identify the next feature where `"passes": false`
4. `git log --oneline -10` — review recent commits to understand recent progress
5. Run the project sanity test if one is defined in `init.sh` or documented in `README.md`
6. Only AFTER completing steps 1–5: pick exactly ONE feature or task to work on this session

If the sanity test fails on startup, fix the existing breakage before touching anything new.

## Search and Navigation Rules

When searching for code or files, always limit output to prevent context flooding:

- Use `grep -n "pattern" file | head -50` — cap at 50 lines
- Use `grep -rn "pattern" dir --include="*.ts" | head -50`
- If results are truncated, **narrow your query** — do not search more broadly
- Never use `cat` to dump entire files; use `sed -n 'START,ENDp' file` for specific ranges
- Use `git show HEAD:path/to/file | sed -n '1,100p'` to inspect file segments from history

The rule: if your search returns more than 50 lines, your query is too broad. Narrow it.

## Lint Before Moving On

After every file edit:

1. Run the project linter on the modified file (e.g. `eslint src/foo.ts`, `ruff check src/foo.py`, `tsc --noEmit`)
2. If linting fails, **revert and fix before proceeding** — do not pile new changes on top of a broken edit
3. Syntax errors caught immediately are cheap; syntax errors discovered at test time are expensive

## Working on a Feature

- Work on **one feature at a time** — do not start a second feature until the first is verified end-to-end
- After implementing a feature, verify it works (tests, manual check, or browser if available)
- Update `feature_list.json` — set `"passes": true` only after end-to-end verification
- **It is unacceptable to remove or modify feature descriptions in `feature_list.json`**
- **It is unacceptable to set `"passes": true` without actual verification**

## Session End (required before closing)

Before finishing your session:

1. Commit your work: `git add -A && git commit -m "feat: <description of what was implemented>"`
2. Update `.agent-progress.md` — document what you did, what's left, and the current state of the code
3. Leave the codebase in a clean, working state (tests pass, no broken imports, no TODO left mid-implementation)

The session is not done until `.agent-progress.md` is updated and there is a clean git commit.

---

## Task

<!-- Insert your task-specific instructions below this line -->
