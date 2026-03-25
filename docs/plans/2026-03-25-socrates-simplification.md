# Socrates Self-Simplification Plan

> **For Claude:** REQUIRED SUB-SKILL: Use ceo:executing-plans to implement this plan task-by-task.

**Goal:** Remove dead skills, consolidate redundant alias pairs, delete orphaned alias scripts, and tighten structural files (ORCHESTRATION.md, AGENTS.md) so Socrates's own workspace has no dead code, no contradictions, and no skills that shouldn't exist.

**Architecture:** Pure deletion and prose editing — no new code. Changes are in `skills/`, `scripts/`, `ORCHESTRATION.md`, and `AGENTS.md`. No changes to canonical scripts (`bootstrap-task.sh`, `spawn-agent.sh`, etc.) or prompts.

**Tech Stack:** Bash (rm), markdown editing.

---

## Constraints

- Do NOT touch: `bootstrap-task.sh`, `spawn-agent.sh`, `run-agent.sh`, `start-monitoring.sh`, `check-agents.sh`, `trigger-phase9.sh`, `verify-reviewers.sh`, `install-socrates.sh`, `init-worktree.sh`, `cleanup-orphans.sh`, `ci-pr-check.sh`, `ddg-search.sh`
- Do NOT touch: `prompts/`, `.clawdbot/`, `memory/`, `SOUL.md`, `USER.md`, `IDENTITY.md`
- `awaken-socrates.sh` and its skill **stay** — explicitly kept by the user
- After every deletion, verify no remaining file references the deleted item

---

## Task 1: Delete Dead Skills

**Skills to delete:**
- `skills/subagent-driven-development/` — banned by orchestrator contract
- `skills/verification-before-completion/` — superseded by ralph + coding-agent prompt
- `skills/executing-plans/` — superseded by bootstrap-task.sh; nothing references it

**Files:**
- Delete: `skills/subagent-driven-development/` (entire directory)
- Delete: `skills/verification-before-completion/` (entire directory)
- Delete: `skills/executing-plans/` (entire directory)

### Step 1: Confirm nothing references these skills

```bash
grep -rn "subagent-driven-development\|subagent_driven\|verification-before-completion\|verification_before\|executing-plans\|executing_plans" \
  /Users/ivanfarias/.openclaw/workspace-socrates/ \
  --include="*.md" --include="*.sh" --include="*.json" \
  --exclude-dir=".git" --exclude-dir="skills" \
  2>/dev/null
```

Expected: no output (or only hits inside the skills directories themselves).

If any external reference exists, update it before deleting.

### Step 2: Delete the directories

```bash
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/subagent-driven-development
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/verification-before-completion
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/executing-plans
```

### Step 3: Verify gone

```bash
ls /Users/ivanfarias/.openclaw/workspace-socrates/skills/ | grep -E "subagent|verification|executing-plans"
```

Expected: no output.

### Step 4: Commit

```bash
cd /Users/ivanfarias/.openclaw/workspace-socrates
git add -A skills/subagent-driven-development skills/verification-before-completion skills/executing-plans
git commit -m "chore: remove dead skills — subagent-driven-development, verification-before-completion, executing-plans

subagent-driven-development: banned by orchestrator contract (Socrates never implements).
verification-before-completion: fully covered by ralph-loop-coordinator + coding-agent prompt.
executing-plans: superseded by bootstrap-task.sh; nothing references it."
```

---

## Task 2: Delete Redundant Alias Skill/Script Pairs

**Pairs to delete** (script is a one-liner `exec` delegation, skill is just a name for it):

| Alias skill | Alias script | Canonical |
|---|---|---|
| `convene-council` | `convene-council.sh` | `bootstrap` skill + `bootstrap-task.sh` |
| `begin-inquiry` | `begin-inquiry.sh` | `init-spec` skill + `init-spec.sh` |
| `summon-interlocutor` | `summon-interlocutor.sh` | `spawn-agent.sh` |
| `return-to-agora` | `return-to-agora.sh` | `start-monitoring.sh --once` |
| `form-check` | `form-check.sh` | `verify-reviewers.sh` |
| `rule-of-reason` | `rule-of-reason.sh` | `check-agents.sh --no-respawn` |

**Keep:** `awaken-socrates` skill + `awaken-socrates.sh` script (explicitly kept).

**Files:**
- Delete: `skills/convene-council/`, `skills/begin-inquiry/`, `skills/summon-interlocutor/`, `skills/return-to-agora/`, `skills/form-check/`, `skills/rule-of-reason/`
- Delete: `scripts/convene-council.sh`, `scripts/begin-inquiry.sh`, `scripts/summon-interlocutor.sh`, `scripts/return-to-agora.sh`, `scripts/form-check.sh`, `scripts/rule-of-reason.sh`

### Step 1: Confirm no external references to deleted aliases

```bash
grep -rn "convene-council\|convene_council\|begin-inquiry\|begin_inquiry\|summon-interlocutor\|summon_interlocutor\|return-to-agora\|return_to_agora\|form-check\|form_check\|rule-of-reason\|rule_of_reason" \
  /Users/ivanfarias/.openclaw/workspace-socrates/ \
  --include="*.md" --include="*.sh" --include="*.json" \
  --exclude-dir=".git" --exclude-dir="skills" --exclude-dir="scripts" \
  2>/dev/null
```

Expected output: hits only in `ORCHESTRATION.md` (the alias documentation table). Those will be cleaned in Task 4.

### Step 2: Delete alias skills

```bash
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/convene-council
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/begin-inquiry
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/summon-interlocutor
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/return-to-agora
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/form-check
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/rule-of-reason
```

### Step 3: Delete alias scripts

```bash
rm /Users/ivanfarias/.openclaw/workspace-socrates/scripts/convene-council.sh
rm /Users/ivanfarias/.openclaw/workspace-socrates/scripts/begin-inquiry.sh
rm /Users/ivanfarias/.openclaw/workspace-socrates/scripts/summon-interlocutor.sh
rm /Users/ivanfarias/.openclaw/workspace-socrates/scripts/return-to-agora.sh
rm /Users/ivanfarias/.openclaw/workspace-socrates/scripts/form-check.sh
rm /Users/ivanfarias/.openclaw/workspace-socrates/scripts/rule-of-reason.sh
```

### Step 4: Verify

```bash
ls /Users/ivanfarias/.openclaw/workspace-socrates/skills/ | grep -E "convene|begin-inquiry|summon-inter|return-to|form-check|rule-of"
ls /Users/ivanfarias/.openclaw/workspace-socrates/scripts/ | grep -E "convene|begin-inquiry|summon|return-to|form-check|rule-of"
```

Expected: no output on either line.

### Step 5: Commit

```bash
git add -A skills/convene-council skills/begin-inquiry skills/summon-interlocutor \
         skills/return-to-agora skills/form-check skills/rule-of-reason \
         scripts/convene-council.sh scripts/begin-inquiry.sh scripts/summon-interlocutor.sh \
         scripts/return-to-agora.sh scripts/form-check.sh scripts/rule-of-reason.sh
git commit -m "chore: remove redundant alias skill/script pairs

Each deleted alias was a one-liner delegating to a canonical script.
Aliases kept in ORCHESTRATION.md as documentation only — no code needed.
Kept: awaken-socrates (explicitly retained by user).

Removed aliases:
- convene-council → bootstrap-task.sh
- begin-inquiry → init-spec.sh
- summon-interlocutor → spawn-agent.sh
- return-to-agora → start-monitoring.sh --once
- form-check → verify-reviewers.sh
- rule-of-reason → check-agents.sh --no-respawn"
```

---

## Task 3: Consolidate the Three Brainstorming Skills

`open-agora`, `brainstorming`, and `brainstorming-prompt-file` all do overlapping work. The correct split:

- **`open-agora`** — user-facing entrypoint (keep, this is what gets invoked via `/open_agora`)
- **`brainstorming-prompt-file`** — the technical implementation backing `open-agora` (keep)
- **`brainstorming`** — generic creative dialogue that duplicates what `open-agora` does, with no distinct role (delete)

`open-agora` should reference `brainstorming-prompt-file` as its backing implementation.

**Files:**
- Delete: `skills/brainstorming/`
- Modify: `skills/open-agora/SKILL.md` — add one line referencing `brainstorming-prompt-file` as the backing skill for prompt file output

### Step 1: Confirm brainstorming has no unique references

```bash
grep -rn "skills/brainstorming\b\|/brainstorming\b\|brainstorming_prompt\b" \
  /Users/ivanfarias/.openclaw/workspace-socrates/ \
  --include="*.md" --include="*.sh" \
  --exclude-dir=".git" --exclude-dir="skills" \
  2>/dev/null
```

Expected: hits only for `brainstorming-prompt-file` and `brainstorming_prompt_file` (the slash alias). The generic `brainstorming` skill should have no external references.

### Step 2: Delete brainstorming skill

```bash
rm -rf /Users/ivanfarias/.openclaw/workspace-socrates/skills/brainstorming
```

### Step 3: Update open-agora/SKILL.md

Add this line to the Behavior section:

```
- When the output needs to feed directly into a prompt file for bootstrap-task.sh, follow the brainstorming-prompt-file skill for output format.
```

### Step 4: Verify

```bash
ls /Users/ivanfarias/.openclaw/workspace-socrates/skills/ | grep brainstorm
```

Expected: only `brainstorming-prompt-file` remains (plus `open-agora`).

### Step 5: Commit

```bash
git add -A skills/brainstorming skills/open-agora/SKILL.md
git commit -m "chore: consolidate brainstorming skills — remove generic brainstorming, keep open-agora + brainstorming-prompt-file

brainstorming was a duplicate of open-agora with no distinct role.
open-agora is the user-facing entrypoint.
brainstorming-prompt-file is the backing implementation for prompt file output."
```

---

## Task 4: Clean ORCHESTRATION.md

Remove the "Thematic Aliases" section (§2.7) since all alias scripts/skills are now deleted. Replace it with a single-sentence note that the canonical aliases are `awaken-socrates` (install) and `open-agora` (brainstorm). Update any other references to deleted aliases.

**Files:**
- Modify: `ORCHESTRATION.md`

### Step 1: Find all alias references

```bash
grep -n "convene-council\|begin-inquiry\|summon-interlocutor\|return-to-agora\|form-check\|rule-of-reason\|subagent.driven\|verification.before\|executing.plans" \
  /Users/ivanfarias/.openclaw/workspace-socrates/ORCHESTRATION.md
```

### Step 2: Edit ORCHESTRATION.md

- Remove §2.7 "Thematic Aliases (Optional)" section in its entirety
- Add a brief note in its place:

```markdown
## 2.7) Active Aliases

Two thematic aliases remain active:
- `awaken-socrates` / `./scripts/awaken-socrates.sh` — thematic alias for install/bootstrap
- `open-agora` / `/open_agora` — thematic alias for brainstorming entrypoint

All other previously documented aliases have been removed. Use canonical script names directly.
```

- Scan for any remaining references to deleted items and remove them

### Step 3: Verify

```bash
grep -n "convene-council\|begin-inquiry\|summon-interlocutor\|return-to-agora\|form-check\|rule-of-reason" \
  /Users/ivanfarias/.openclaw/workspace-socrates/ORCHESTRATION.md
```

Expected: no output.

### Step 4: Commit

```bash
git add ORCHESTRATION.md
git commit -m "docs: remove deleted alias references from ORCHESTRATION.md

§2.7 replaced with minimal note — only awaken-socrates and open-agora remain as active aliases.
All other alias scripts/skills removed in prior commits."
```

---

## Task 5: Add systematic-debugging invocation rule to AGENTS.md

`systematic-debugging` is a skill that spawned agents should use, but right now nothing tells me *when* to invoke it as orchestrator. The rule is: when tooling breaks (script errors, agent failures, unexpected behavior), invoke `systematic-debugging` before doing anything else — and the conclusion from that skill tells me whether to write a plan + spawn Codex, or escalate to the user.

**Files:**
- Modify: `AGENTS.md`

### Step 1: Find the "When Tooling Breaks" section

```bash
grep -n "When Tooling Breaks\|systematic-debugging" /Users/ivanfarias/.openclaw/workspace-socrates/AGENTS.md
```

### Step 2: Update the section

Find the current "When Tooling Breaks" block and add explicit reference to the skill:

```markdown
## When Tooling Breaks

**REQUIRED SUB-SKILL: Use systematic-debugging before ANY diagnosis attempt.**

If `run-agent.sh`, `bootstrap-task.sh`, or any orchestration script fails:
1. Read `skills/systematic-debugging/SKILL.md` — follow its process to identify root cause
2. Report the root cause and exact error to the user
3. Do NOT attempt to work around it (no wrapper scripts, no manual tmux, no direct agent invocations)
4. Write a plan to fix the broken tool and spawn Codex — then stop and wait
```

### Step 3: Verify

```bash
grep -n "systematic-debugging" /Users/ivanfarias/.openclaw/workspace-socrates/AGENTS.md
```

Expected: at least one hit in the "When Tooling Breaks" section.

### Step 4: Commit

```bash
git add AGENTS.md
git commit -m "docs: wire systematic-debugging skill into When Tooling Breaks rule in AGENTS.md"
```

---

## Task 6: Document internal scripts in ORCHESTRATION.md

`run-agent.sh`, `ci-pr-check.sh`, and `ddg-search.sh` are real scripts called by other scripts but not mentioned in ORCHESTRATION.md. Add a brief internal scripts section so the full picture is documented.

**Files:**
- Modify: `ORCHESTRATION.md`

### Step 1: Add internal scripts section

Add after the scripts table or at the end of §2:

```markdown
## 2.8) Internal Scripts (not invoked directly)

These scripts are called by canonical scripts — do not invoke them directly:

- `run-agent.sh` — called by `spawn-agent.sh`; handles per-agent execution (Codex, Claude, Gemini)
- `ci-pr-check.sh` — called by `check-agents.sh`; evaluates PR/CI signals for a given PR number
- `ddg-search.sh` — DuckDuckGo web search utility; also accessible via `duckduckgo-search` skill
```

### Step 2: Verify

```bash
grep -n "run-agent\|ci-pr-check\|ddg-search" /Users/ivanfarias/.openclaw/workspace-socrates/ORCHESTRATION.md | head -10
```

Expected: hits in the new section.

### Step 3: Commit

```bash
git add ORCHESTRATION.md
git commit -m "docs: document internal scripts in ORCHESTRATION.md

run-agent.sh, ci-pr-check.sh, ddg-search.sh were undocumented.
Added §2.8 Internal Scripts to make the full script surface visible."
```

---

## Verification Checklist

Run after all tasks complete:

```bash
# 1. No deleted skills remain
ls /Users/ivanfarias/.openclaw/workspace-socrates/skills/
# Expected: awaken-socrates, bootstrap, brainstorming-prompt-file, dispatching-parallel-agents,
#           duckduckgo-search, finishing-a-development-branch, init-spec, install-agent,
#           open-agora, ralph-loop-coordinator, receiving-code-review, requesting-code-review,
#           simplify, systematic-debugging, test-driven-development, use-context7,
#           using-git-worktrees, writing-plans

# 2. No deleted scripts remain
ls /Users/ivanfarias/.openclaw/workspace-socrates/scripts/
# Expected: awaken-socrates.sh, bootstrap-task.sh, check-agents.sh, ci-pr-check.sh,
#           cleanup-orphans.sh, ddg-search.sh, init-spec.sh, init-worktree.sh,
#           install-socrates.sh, run-agent.sh, spawn-agent.sh, start-monitoring.sh,
#           trigger-phase9.sh, verify-reviewers.sh

# 3. No orphaned references
grep -rn "subagent-driven\|verification-before-completion\|executing-plans\|convene-council\|begin-inquiry\|summon-interlocutor\|return-to-agora\|form-check\|rule-of-reason" \
  /Users/ivanfarias/.openclaw/workspace-socrates/ \
  --include="*.md" --include="*.sh" \
  --exclude-dir=".git" --exclude-dir=".worktrees" \
  2>/dev/null
# Expected: no output

# 4. Git log shows clean commits
git -C /Users/ivanfarias/.openclaw/workspace-socrates log --oneline -6
```
