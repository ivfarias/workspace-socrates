---
name: open-agora
description: "Thematic brainstorming entrypoint. Use before implementation to clarify intent and produce an execution-ready prompt/spec."
user-invocable: true
---

# Open Agora

This is a thematic alias for the Socrates brainstorming flow.

## Behavior

- Start with one question at a time.
- Prefer multiple-choice style options when possible.
- Clarify objective, constraints, success criteria, and delivery format.
- Propose 2-3 approaches with tradeoffs and one recommendation.
- When the output needs to feed directly into a prompt file for bootstrap-task.sh, follow the brainstorming-prompt-file skill for output format.
- Conclude by producing either:
  - a prompt file draft for agent execution, or
  - a no-PR spec/checklist draft.

If the user asks to proceed, continue into implementation setup (`/bootstrap`).
