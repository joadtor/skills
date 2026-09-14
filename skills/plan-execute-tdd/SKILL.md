---
name: plan-execute-tdd
description: Use when a plan-draft execution plan should be built test-first — plan-execute with the TDD iron law on every implementer: a failing test before any production code, watched fail, then minimal code and refactor.
---

# Plan Execute (TDD)

## Overview

Everything in `plan-execute`, but every implementer builds **test-first**: no production code without a failing test it watched fail. The plan's scenarios and steps drive the tests; the tests drive the code.

**REQUIRED BACKGROUND:** `plan-execute` — this skill is that executor with the TDD iron law layered onto each implementer. Waves, disjoint-file parallelism, orchestrator commits, the progress file, the 2-round cap, and the final review are all inherited unchanged.

**Core principle:** Tests drive, not just check. If you didn't watch the test fail, you don't know it tests the right thing.

## When to Use

- The plan's work is test-drivable production code — features, bug fixes, behavior changes (most feature work).
- Use plain `plan-execute` when TDD doesn't fit the task — migrations, config, generated code, infra. Tests stay mandatory there, but as a *check*, not a driver.

## The delta: the iron law, per behavior

The only change from `plan-execute` is the implementer's discipline and its evidence contract. Every dispatch carries the iron law:

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Per behavior, not just per task:

1. **RED** — write one minimal failing test for the next behavior.
2. **Watch it fail** — run it; confirm it fails for the right reason (feature missing, not a typo). Mandatory — never skip.
3. **GREEN** — the simplest code that passes (KISS). Nothing extra (YAGNI).
4. **REFACTOR** — clean up while it stays green, until the task's files pass the complexity gate (`plan-execute`'s `scripts/complexity.sh`, no function over 8) — a numeric exit, not a feeling; this is where SOLID earns its place — structure only where it's warranted, never abstraction YAGNI would reject.

Repeat until the task's DoD scenario is green.

- **Test-after is forbidden.** Code written before its test is **deleted and redone** — not kept "as reference," not "adapted."
- The task's `.feature` scenario is the acceptance target and the final test; the unit tests are the test-first steps that reach it. Build the RED tests from the spec's Given/When/Then — don't invent criteria it didn't state.

## The evidence contract (stricter than base)

The per-task gate is `plan-execute`'s — DoD scenario green, tests green, lint green, pristine — **plus** proof the tests came first. The implementer's report must show, per behavior, the **ordered RED-then-GREEN**: the test failing before the code, then passing after. A report that shows only the final green — no watched failure — fails the gate and re-enters the fix loop.

## Common Mistakes

- Writing the code, then the test → that's test-after; the iron law means delete and redo test-first.
- A contrived red (test fails on a typo, not the missing feature) → watch it fail *for the right reason*.
- Reporting only the passing run → the gate needs the ordered RED-then-GREEN.
- Over-building in GREEN → minimal code to pass; refactor after.
