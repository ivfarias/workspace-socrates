---
name: ralph-loop-coordinator
description: Orchestrates deterministic code review feedback loop until completion. Implements ralph-style cycling (request → implement → re-request) with explicit completion signals and max cycle cap.
---

# Ralph-Loop Coordinator: Deterministic Code Review Cycle

## Overview

After code implementation and simplify cleanup, the ralph-loop-coordinator runs a **deterministic review cycle** until the code is explicitly marked "ready for production" or max cycles exhausted.

**Core principle:** Loop continues until you receive explicit completion signal, not auto-exit on "no issues".

## When to Use

After task reaches `status=done` AND simplify cleanup is complete:
- Phase 9 Stage 2: Code review and refinement
- Orchestrated by: `trigger-phase9.sh` (automatically spawns when `phase9_status = "review_pending"`)
- Manual invocation: Not typical - automation handles this

## The Cycle (Max 5 Iterations)

```
Cycle 1:
  └─ Request → Submit code for review
       ↓
  └─ Receive → Process feedback
       ↓
  └─ Implement → Fix issues
       ↓
  └─ Re-Simplify (optional) → If major changes, catch new issues
       ↓
Cycle 2-5:
  └─ Loop: Request → Implement → ...
       ↓
Exit Conditions:
  ├─ Explicit "ready" signal → ✓ Success
  ├─ Reviewer returns "no issues found" → ✓ Success
  ├─ User signals "ship it" / "complete" → ✓ Success
  ├─ cycle_count >= 5 → ⚠️ Max cycles reached (still deployable)
  └─ User selects "abandon review" → ✗ Cancel (keep branch, don't ship)
```

## Phase 1: Request Code Review

**Input:** Completed & simplified task with ready-to-review code

**Action:**
1. Invoke `requesting-code-review` skill (spawns code-reviewer subagent)
2. Pass: task details, git SHA range (BASE...HEAD), description
3. Wait for code-reviewer subagent response

**Code Reviewer Returns:**
- `strengths` - List of things done well
- `issues` - Array of {priority, description, location, suggestion}
  - Priority: Critical | Important | Minor
  - Critical issues block merge (must fix)
  - Important issues should fix (deployment risk)
  - Minor issues optional (code style, nits)
- `assessment` - Overall readiness statement

## Phase 2: User Decision & Implementation

**Decision Point:** "Review feedback received. Implement fixes?"

**Options:**
1. **"Yes, implement"** → Go to Phase 3
2. **"Ready to ship as-is"** → Mark complete, exit loop
3. **"Abandon all reviews"** → Exit loop, keep branch unmerged

**If "Yes":**

### Phase 3: Implement Fixes

**Critical Issues (MUST fix):**
1. Read issue description & location
2. Understand root cause
3. Implement fix in code
4. Test locally (tests pass)
5. Commit: `git commit -m "fix: [issue description]"`

**Important Issues (should fix):**
1. Evaluate urgency: Does it genuinely affect code quality?
2. If yes → implement same as Critical
3. If no → document why skipping: leave comment in PR or progress log

**Minor Issues (optional):**
1. Polish issues (naming, formatting, etc.)
2. Fix if quick and obvious
3. Skip if time-consuming and low-impact

**After all fixes:**
1. Run tests (must pass)
2. Commit all changes: `git status` should be clean
3. Signal: "Fixes implemented, ready for re-review"

### Phase 4: Re-Simplify (If Major Changes)

If implementation involved significant refactoring:
1. Re-run simplify skill on new commits
2. If simplify finds issues → implement those
3. If clean → proceed to re-request review

If implementation was minor (1-2 line fixes):
- Skip re-simplify, go straight to re-request

## Phase 5: Loop Back to Request

Increment `review_cycles` counter.

**If `review_cycles < 5`:**
1. Invoke `requesting-code-review` again (same process as Phase 1)
2. Repeat Phases 2-5

**If `review_cycles >= 5`:**
1. Ask user: "Max 5 review cycles reached. Code ready to proceed?"
2. If yes → exit loop, mark complete
3. If no → cannot continue (architectural issue - see SYSTEMATIC_DEBUGGING skill)

## Exit: Explicit Completion Signal

Code review loop exits ONLY when you receive ONE of:

1. **"Ready" signal from user**
   - User declares: "Code is ready. Ship it."
   - Store in task: `review_signature = "ready for production"`
   - Result: ✓ Complete, proceed to merge

2. **"No issues" from reviewer**
   - Reviewer returns: "No issues found. Code is clean."
   - Code passes review without requiring fixes
   - Store: `review_signature = "no issues found"` + cycle count
   - Result: ✓ Complete, proceed to merge

3. **Max cycles exhausted**
   - Reached `review_cycles = 5`
   - User confirmed: "Proceed anyway"
   - Store: `review_signature = "max cycles reached (5)"`
   - Result: ⚠️ Proceed (may need architectural review)

## Integration with Task State

**Updates to active-tasks.json:**
- `phase9_status` - Set to `"review_in_progress"` at start, `"review_completed"` at end
- `review_cycles` - Incremented each loop iteration (0-5)
- `review_status` - Current state: `"not_started" → "in_progress" → "complete"`
- `review_signature` - Final completion message (set on exit)

## When Ralph-Loop Cannot Help

If after 5 cycles the code still has critical issues:

1. **Pattern:** Each cycle fixes issues in different layers (function A → function B → architecture)
2. **Sign:** No single fix resolves all issues
3. **Action:** STOP. Don't attempt Cycle 6.
4. **Next:** Use `systematic-debugging` skill to investigate architecture (see SKILL.md)

This is NOT a failed review - this is an architectural signal.

## Examples

### Example 1: Clean Code (Exits Early)

```
Cycle 1:
  Request → "3 issues found: all minor"
  Implement → Fix naming, add docstring
  Re-request → "No issues found"
  Exit → review_signature = "no issues found"
  Result: ✓ 1 cycle complete
```

### Example 2: Iterative Refinement

```
Cycle 1: Remove unused imports (Critical)
  ↓
Cycle 2: Simplify validation logic (Important)
  ↓
Cycle 3: User declares "Ready. Ship it."
  Exit → review_signature = "ready for production"
  Result: ✓ 3 cycles, complete
```

### Example 3: Max Cycles (Needs Architecture Review)

```
Cycles 1-5: Each fixes different layer
  - Cycle 1: Fix function parameter handling
  - Cycle 2: Fix error boundary logic
  - Cycle 3: Fix type consistency
  - Cycle 4: Fix async patterns
  - Cycle 5: Fix retry logic
  ↓
User asked: "Still issues?"
Response: "Yes. This needs refactoring."
Action: STOP. Use systematic-debugging.
```

## Implementation Note

The ralph-loop-coordinator skill is orchestrated by Socrates:
1. After simplify completes (Phase 9 Stage 1)
2. trigger-phase9.sh detects `phase9_status = "review_pending"`
3. Spawns ralph-loop-coordinator skill
4. Skill handles Phases 1-5, loops until completion
5. On completion: trigger-phase9.sh moves to `phase9_status = "finishing_pending"`
6. Then: Auto-invoke `finishing-a-development-branch` skill

Human user does NOT manually invoke - orchestration handles flow.

