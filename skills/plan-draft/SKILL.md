---
name: plan-draft
description: Use when a settled design and its Gherkin spec should be turned into a story-map execution plan (a docs/plans .md file) — a task map plus test-first tasks that each trace back to a scenario.
---

# Plan Draft

## Overview

Turn a settled design and its spec into one execution plan: a **story-map task grid** plus a single list of **test-first tasks**, each tracing back to a scenario in the spec. The spec's scenarios are failing acceptance tests; the plan is the ordered work that turns them green.

**Core principle:** Every scenario is covered by a task, every task traces to a scenario, and each task's Definition of Done is "make its scenario pass" — test first.

## Principles

- **Iron law — two-way traceability.** No plan ships unless *every* scenario is covered by at least one task **and** every task traces to at least one scenario. "Traces to" means *needed to make it pass*, so enabling/infra tasks are fine — they trace to the scenario they unblock. No orphan tasks, no uncovered scenarios.
- **YAGNI.** Cut tasks no scenario needs. A task that isn't on the path to a green scenario doesn't belong in the plan.
- **KISS.** State each fact once. The plan must never contradict itself, and its layout must never encode an order you don't want.

## Prerequisite: a spec

**A plan is always built on a well-defined spec.** Before drafting, get one:

- Spec exists (a `.feature` file, referenced, or in context) → use it.
- No spec → run **`context-pumping-spec`** (interrogate for full context, then write the spec) first, *then* draft the plan.

So calling this skill cold takes an idea all the way to a plan — spec first, plan second.

## The discipline (RED → GREEN → REFACTOR)

Author the plan the way you'd write code test-first:

1. **RED** — read the spec. Each `Scenario` is a currently-failing acceptance test. The plan's whole job is to turn them green.
2. **GREEN** — for each scenario, add the task(s) that turn it green. A task's **DoD is the scenario(s) it makes pass**, written test-first: ① a failing test asserts the scenario ② code makes it pass ③ refactor.
3. **REFACTOR** — collapse the task map to the *simplest* sequence that still covers every scenario. Merge overlaps, order by real dependencies, drop speculative tasks (YAGNI/KISS).
4. **Verify** — before presenting, walk it both ways: every scenario appears in some task's DoD, and every task names at least one scenario. Loop until the iron law holds.

## Output

Write to `docs/plans/YYYY-MM-DD-<topic>.md` (create `docs/plans/` if it doesn't exist). Reference the spec **by path** — never paste it in.

```markdown
# Plan: <topic>

## 1. Context
- **Goal / why:** one or two lines
- **Spec:** docs/specs/YYYY-MM-DD-<topic>.feature
- **Constraints:** the must-not-breaks

## 2. Task Map
<!-- rows = execution sequence; columns = the technical domains THIS work spans -->
| Sequence | <Domain A> | <Domain B> | <Domain C> |
| :------- | :--------- | :--------- | :--------- |
| Phase 1  | T1 …       | T2 …       | T3 …       |
| Phase 2  | T4 …       | T5 …       |            |

## 3. Tasks
### [ ] T1: <title>
- **Domain / Depends on / Blocks:** …   <!-- Owner: optional -->
- **DoD:** ① failing test for `Scenario: <name>` ② passes ③ refactor
```

- **Columns are derived, not fixed.** `Database | API | UI` suits a web feature; a CLI, a pipeline, or a library has other domains (`Parser | Core | Output`, `Ingest | Transform | Load`). Use the domains *this* work actually spans.
- **The task list is the one source of status.** The `[ ]` checkbox lives on each task heading in §3 — not in a second checklist that would drift out of sync with the map.
- **Verification lives in the DoD** (step ①), so tests come first. Verification that no single task owns (a manual QA pass, a security review) may get its own section — but a per-task acceptance test never gets exiled to the end.

## Rules

- Reference the spec; don't embed it.
- Every task heading carries an id (`T1`) so the map and the task list cross-reference, and dependencies (`Depends on` / `Blocks`) read cleanly.
- Plan only the work the spec settled — don't invent scope the scenarios don't ask for.

## Common Mistakes

- A second checklist duplicating the map → one list drifts and the plan contradicts itself; keep §3 as the only task/status list.
- A trailing "QA / Verification" column or phase → encodes test-*after*; put the test in each task's DoD.
- Orphan tasks or uncovered scenarios → breaks the iron law; every task ↔ at least one scenario, both ways.
- Hardcoding `Database | API | UI` columns → lies about non-web work; derive the domains from the work.
- Embedding the spec instead of linking it → the plan and spec drift; reference by path.
- Drafting a plan with no spec → run `context-pumping-spec` first.
