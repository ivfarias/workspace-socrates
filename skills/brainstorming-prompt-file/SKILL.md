---
name: brainstorming-prompt-file
description: "Use this before spawning coding agents when you need to turn an idea into an execution-ready prompt file for bootstrap-task.sh or spawn-agent.sh."
---

# Brainstorming Ideas Into Agent Prompt Files

## Overview

Turn a rough idea into a concrete prompt file that a coding agent can execute with minimal ambiguity.

This skill is a variation of `brainstorming`, optimized for orchestration workflows where output must feed directly into:
- `--prompt-file` for `bootstrap-task.sh` or `spawn-agent.sh`
- `--completion-mode pr|no-pr-spec`
- optional no-PR spec file checks

## The Process

### 1) Understand The Objective

- Start by checking local project context first (files, docs, recent changes)
- Ask one question at a time
- Prefer multiple choice when possible
- Clarify:
  - target repo
  - desired outcome
  - constraints
  - completion mode (`pr` or `no-pr-spec`)

### 2) Explore Approaches

- Propose 2-3 approaches with trade-offs
- Lead with your recommendation and why
- Keep suggestions practical and YAGNI-focused

### 3) Build The Prompt In Sections

Draft the prompt file incrementally in short sections and validate each section with the user:

1. Goal and business context
2. Scope and non-goals
3. Technical constraints and touched areas
4. Implementation requirements
5. Validation steps and done criteria

If anything is unclear, go back and ask one follow-up question.

### 4) Finalize Execution Inputs

Produce:
- Prompt file content
- Suggested file path (default: `tasks/prompts/YYYY-MM-DD-<topic>.md`)
- Ready-to-run command using `bootstrap-task.sh`

If `completion-mode=no-pr-spec`, also ensure there is a spec file and reference it in the command.
Use `scripts/init-spec.sh` when needed.

## Prompt File Contract

Every generated prompt file should include:

1. **Objective**
2. **Why this matters** (brief business context)
3. **In scope**
4. **Out of scope**
5. **Implementation notes** (files/components/services likely involved)
6. **Constraints** (performance, compatibility, security, no schema changes, etc.)
7. **Validation** (commands/tests/checks to run)
8. **Definition of done**
9. **Output format expected from agent** (summary, files changed, risks)

## Completion-Mode Rules

### `pr` mode

Prompt should instruct the agent to:
- commit and push branch
- open/update PR
- address CI and review comments

### `no-pr-spec` mode

Prompt should instruct the agent to:
- produce required artifacts
- satisfy spec checks in the referenced spec file
- report evidence for each check

## Output Behavior

When the user says the prompt is approved:

1. Write the prompt file to disk
2. Print the exact `bootstrap-task.sh` command to run
3. Ask if they want to spawn immediately

## Key Principles

- One question per message
- Prefer multiple choice
- Remove unnecessary complexity
- Make success criteria explicit
- Optimize for execution quality, not essay quality
