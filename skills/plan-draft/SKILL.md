---
name: plan-draft
description: Use when a settled design and its Gherkin spec should be turned into a concrete story-map execution plan (a docs/plans .md file) — a task-execution map plus detailed, test-first tasks (splittable into steps) that each trace back to a scenario.
---

# Plan Draft

## Overview

Turn a settled design and its spec into one execution plan: a **task-execution map** (a story-map grid) plus a single list of **detailed, test-first task specifications**, each tracing back to a scenario in the spec. A large task splits into ordered **steps**. The spec's scenarios are failing acceptance tests; the plan is the concrete, ordered work that turns them green.

**Core principle:** Every scenario is covered by a task, every task traces to a scenario, and each task (or step) is concrete enough to build from — real file paths, real snippets — with a Definition of Done that says "make its scenario pass," test first.

## Principles

- **Iron law — two-way traceability.** No plan ships unless *every* scenario is covered by at least one task **and** every task traces to at least one scenario. "Traces to" means *needed to make it pass*, so enabling/infra tasks are fine — they trace to the scenario they unblock. No orphan tasks, no uncovered scenarios.
- **YAGNI.** Cut tasks no scenario needs. Split a task into steps only when it's big enough to warrant it — don't decompose a one-liner.
- **KISS.** State each fact once — the plan must never contradict itself, and its layout must never encode an order you don't want.

## Prerequisite: a spec

**A plan is always built on a well-defined spec.** Before drafting, get one:

- Spec exists (a `.feature` file, referenced, or in context) → use it.
- No spec → run **`context-pumping-spec`** (interrogate for full context, then write the spec) first, *then* draft the plan.

So calling this skill cold takes an idea all the way to a plan — spec first, plan second.

## The discipline (RED → GREEN → REFACTOR)

Author the plan the way you'd write code test-first:

1. **RED** — read the spec. Each `Scenario` is a currently-failing acceptance test. The plan's whole job is to turn them green.
2. **GREEN** — for each scenario, add the task(s) that turn it green. A task's **Definition of Done is the scenario(s) it makes pass**; a large task splits into ordered **steps**, each with its own *done-when* check. Steps are test-first: the failing check comes before the code that satisfies it.
3. **REFACTOR** — collapse the map to the *simplest* sequence that still covers every scenario. Merge overlaps, order by real dependencies, drop speculative tasks (YAGNI/KISS).
4. **Verify** — before presenting, walk it both ways: every scenario appears in some task's DoD, and every task names at least one scenario. Loop until the iron law holds.

## Output

Write to `docs/plans/YYYY-MM-DD-<topic>.md` (create `docs/plans/` if it doesn't exist). Reference the spec **by path** — never paste it in.

**Stack-agnostic is about this skill, not the plan it writes.** This skill assumes no framework, so the map's columns are *derived* from the work and the examples below are pseudocode. But a real plan is **concrete about the code it targets**: the project's actual language, real file paths, real snippets, schemas, exact identifiers. A vague plan is a failed plan.

Three sections:

- **§1 Context** — goal / why, the spec path, design links, the must-not-break constraints.
- **§2 Task Execution Map** — the grid. **Rows** are the execution sequence; *name* each phase (Foundation, Core Data, Integration…). **Columns** are the technical domains *this* work spans — derive them (`Database | API | UI` suits a web feature; a CLI or pipeline has others). Each cell is a task id + short title.
- **§3 Task Specifications** — one entry per task, and the **single source of status** (`[ ]` on each heading and each step — no second checklist). See the anatomy below.

### Task anatomy

```
### [ ] T5: <title>
- **Domain:** … · **Depends on:** … · **Blocks:** … · **Owner:** _(optional)_
- **Description:** one or two lines.
- **Steps:**                        ← only when the task is big enough to split
  - [ ] **T5.1** <imperative action> — `path/to/file` — *done when:* <concrete check / test>
  - [ ] **T5.2** <imperative action> — `path/to/file`:
    <snippet the step introduces>
    *done when:* <check>
- **Technical Notes:** cross-cutting detail no single step owns _(optional)_
- **DoD:** the `Scenario:`(s) this task turns green.
```

- **Step ids are dotted** (`T5.1`, `T5.2`) so the map cell (`T5`), the task, and its steps cross-reference and the order is explicit.
- **Each step carries a `done when:`** — a concrete check, usually a test.
- Small tasks skip **Steps** entirely; the detail lives in **Technical Notes** instead.

### Worked example (pseudocode — one flat task, one split task)

````markdown
# Execution Plan: Guest Checkout Flow

## 1. Context
- **Goal / why:** Mandatory account creation makes buyers abandon carts. Add a guest flow.
- **Spec:** docs/specs/2026-09-10-guest-checkout.feature
- **Constraint:** Must not break existing authenticated sessions.

## 2. Task Execution Map
| Sequence       | Database / State        | API / Core Logic           | UI / Frontend            |
| :------------- | :---------------------- | :------------------------- | :----------------------- |
| 1. Foundation  | T1: nullable `user_id`  | T2: auth bypass for guests | T3: guest checkout route |
| 2. Core Data   | T4: guest session store | T5: guest checkout endpoint| T6: email form           |

## 3. Task Specifications

### [ ] T1: Make `orders.user_id` nullable
- **Domain:** Database · **Blocks:** T5
- **Description:** `orders.user_id` is a required FK; guest orders need it nullable.
- **Technical Notes:** migration `orders_user_id_nullable` → `alter column orders.user_id -> nullable`; rollback re-asserts NOT NULL (fail if guest orders exist).
- **DoD:** `Scenario: Guest order is stored without an account` passes — inserting an order with `user_id = null` succeeds.

### [ ] T5: Guest checkout endpoint  `POST /checkout/guest`
- **Domain:** API · **Depends on:** T1, T2 · **Blocks:** T6
- **Description:** Backend route that processes a cart for an unauthenticated buyer.
- **Steps:**
  - [ ] **T5.1** Add route + stub handler — `routes`, `controllers/checkout#guest` — *done when:* a request test reaches the handler (red for the behavior).
  - [ ] **T5.2** Validate payload; reject missing/invalid `email` with `400` — *done when:* `Scenario: Missing email in guest checkout` passes.
  - [ ] **T5.3** Create order + charge in ONE transaction:
    ```
    begin transaction
      order  = create Order(user_id: null, ...attrs)
      charge = payment.charge(token, order.total)
      if charge failed -> rollback        # never leave a paid-for-but-absent order
    commit
    ```
    *done when:* `Scenario: Successful guest checkout` passes (`201` + `order_id`); a failed charge rolls the order back.
- **DoD:** `Scenario: Successful guest checkout` and `Scenario: Missing email in guest checkout` both green.
````

The pseudocode and generic paths are only because this skill is stack-agnostic — in a real plan, use the project's actual language, files, and identifiers.

## Rules

- Reference the spec by path; don't embed it.
- Be concrete: every task (or step) names the real files it touches and shows the snippet or schema that matters. No "implement the endpoint" hand-waving.
- Split a task into steps only when it earns it; each step names its file(s) and a `done when:` check.
- Every task heading carries an id (`T1`), each step a dotted id (`T1.1`), so the map, tasks, and steps cross-reference and dependencies (`Depends on` / `Blocks`) read cleanly.
- Plan only the work the spec settled — don't invent scope the scenarios don't ask for.

## Common Mistakes

- Vague tasks — no file paths, no snippets → un-buildable; name real files and show the code that matters.
- Splitting a trivial task into steps → over-decomposition; steps are for tasks big enough to need them.
- A second checklist duplicating the map → one list drifts and the plan contradicts itself; keep §3 as the only task/status list.
- A trailing "QA / Verification" column or phase → encodes test-*after*; put the check in each task/step's `done when`.
- Orphan tasks or uncovered scenarios → breaks the iron law; every task ↔ at least one scenario, both ways.
- Hardcoding `Database | API | UI` columns → lies about non-web work; derive the domains from the work.
- Embedding the spec instead of linking it → the plan and spec drift; reference by path.
- Drafting a plan with no spec → run `context-pumping-spec` first.
