---
name: ralph-loop-coordinator
description: Orchestrates deterministic code review feedback loop — simplify → request review → receive and implement feedback → repeat until done. Run this before creating a PR.
---

# Ralph-Loop Coordinator

Runs a deterministic review cycle on completed implementation work before a PR is opened.

**Core principle:** Loop continues until the reviewer explicitly says there is nothing left to fix. Do not exit early.

---

## When to Use

As soon as the implementing agent claims the work is done — before pushing, before creating a PR, before CI.

---

## The Exact Loop (Max 5 Cycles)

```
Cycle N:
  1. /simplify       → clean up the diff (spawns 3 parallel subagents internally)
  2. /requesting-code-review → spawn one reviewer subagent against the diff
  3. /receiving-code-review  → evaluate and implement feedback (Critical + Important)
  4. Run tests + tsc — must be clean before continuing
  5. Commit all fixes
  ↓
  If reviewer says "nothing left" / "done" / "no issues" → EXIT, create PR
  If issues remain → Cycle N+1
  If cycle >= 5 → ask user whether to proceed
```

---

## Step 1: Simplify

Read the `simplify` skill (`skills/simplify/SKILL.md`) and execute it fully.

Simplify spawns 3 parallel subagents (reuse review, quality review, efficiency review). Wait for all three to complete, aggregate findings, fix issues, commit.

Do not skip simplify even if the code looks clean. It catches things a single-pass review misses.

---

## Step 2: Request Code Review

Read the `requesting-code-review` skill (`skills/requesting-code-review/SKILL.md`) and execute it.

- Get the git SHA range (`origin/<base>...HEAD`)
- Dispatch one `code-reviewer` subagent with full context
- Wait for the subagent to return findings

---

## Step 3: Receive and Implement Feedback

Read the `receiving-code-review` skill (`skills/receiving-code-review/SKILL.md`) and execute it.

- Evaluate each finding technically before implementing
- Fix all Critical issues — these block proceeding
- Fix all Important issues — these must be addressed before the PR
- Note Minor issues — optional, fix if quick
- After all fixes: run tests + tsc, both must pass
- Commit all fixes with a clear message

---

## Step 4: Assess and Loop

After implementing feedback:

- If reviewer returned "no issues" / "nothing left" / "we're done" / equivalent → **exit the loop**
- If Critical or Important issues were fixed → **start Cycle N+1 from Step 1**
- If cycle count reaches 5 → stop and ask the user how to proceed

---

## Exit: PR Creation

Only after the loop exits clean:

1. Push the branch
2. Create the PR with a summary of what was built, what was reviewed, and what was fixed
3. Report to the user: PR URL + review summary

---

## What Ralph Does NOT Do

- Does not self-review without spawning subagents — simplify and code-reviewer are mandatory
- Does not create a PR until the loop exits clean
- Does not skip cycles because "the code looks fine"
- Does not exit on Minor-only feedback — Minor issues are not a stop condition
