---
name: context-pumping-loop
description: Use when a plan or idea should be made better, not just clarified or stress-tested — you want a stronger design than the one on the table before building.
---

# Context Pumping Loop

## Overview

Run the `context-pumping` interview, but don't just extract what the user already thinks — at each decision, also **innovate a better option**. Critique and generation feed each other in a loop until the design is genuinely better than the one you started with.

**Core principle:** Grill to expose the decision, brainstorm to improve it, tune the pick, advance. Loop until the design is solid — then stop and get approval.

**REQUIRED BACKGROUND:** the `context-pumping` base engine — this skill is that interview with an innovation step added.

## When to Use

- The user wants the plan made *better*, not just pressure-tested
- There is likely a stronger approach than the one on the table

## The Loop

For each decision, walking the tree in `context-pumping` order:

1. **Grill** — one sharp question exposing an assumption, gap, or risk in the current plan.
2. **Brainstorm — where there's room to improve.** Offer 2–3 *better* options with tradeoffs; lead with your recommendation. YAGNI: cut options and features that don't earn their place. If the current answer is already solid, record it and move on — don't manufacture alternatives.
3. **Decide, then tune.** The user picks (or takes the rec). Then run a short follow-up Q&A to sharpen that choice before you leave it.
4. **Advance** to the next decision. Repeat.

The loop ends when the tree is resolved and the design is better than the one you started with.

## The Gate

When the design is settled, present it and **stop**. Do not write code, scaffold, or take any implementation action until the user approves. The gate is the approval, not the design's length — present, then wait for a yes.

## Common Mistakes

- Manufacturing alternatives for a decision that's already right → only brainstorm where there's room.
- More options instead of better options → YAGNI; lead with a recommendation.
- Picking an option and moving on without tuning it → run the sub-loop first.
- Starting to build once the design "looks done" → the gate is the user's yes.
