---
name: context-pumping
description: Use when a plan, idea, or design needs its hidden assumptions, gaps, and open decisions surfaced before building. The base interview engine the other context-pumping skills build on.
---

# Context Pumping

## Overview

Pump the context out of the user's head and onto the table. Interview them relentlessly about the plan or idea — one question at a time — until you both share a clear, complete understanding of what's being built and why.

**Core principle:** One question at a time. Walk the decision tree; resolve each decision before the one that depends on it.

## When to Use

- A plan or design needs stress-testing before anyone writes code
- A rough idea needs sharpening into something concrete
- You're about to build and want the assumptions surfaced first

Works from either a rough idea or an existing plan. Not for trivial changes where the design is already obvious.

## The Method

1. **Explore first.** If a question can be answered by reading the code, docs, or history, answer it yourself — don't ask.
2. **One question at a time.** Several questions at once is bewildering. Wait for the answer before asking the next.
3. **Recommend an answer.** Every question carries your recommended answer and why — the user reacts to a proposal, they don't start from a blank page.
4. **Walk the tree.** Order questions by dependency: resolve the decision others hinge on first, then move down its branches.
5. **Stop at shared understanding.** When the tree is resolved and you could build it without guessing, you're done.

## Rules

- One question per message. If a topic needs more, break it into several questions.
- Prefer concrete options (A / B / C) over open-ended when you can.
- Never batch questions to "save time" — it loses the user.
- Explore the codebase instead of asking anything it can answer.

## Common Mistakes

- Several questions in one message → ask one, wait.
- Asking what the code already answers → go read it.
- A blank question with no recommendation → always lead with your pick.
- Jumping to a design before the tree is resolved → keep pumping until it is.
