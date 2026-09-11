---
name: plan-execute
description: Use when a plan-draft execution plan should be built — run its tasks, parallelizing independent ones across subagents, gating each on its DoD scenario plus tests and lint, committing per task, ending with one review.
---

# Plan Execute

## Overview

Build a settled `plan-draft` plan: read it, run its tasks — fanning independent ones out to parallel subagents — and gate every task on its Definition of Done (the scenario it turns green) plus a green test and lint run. The plan's `Depends on`/`Blocks` and per-task file lists are the execution graph; the linked `.feature` spec is the authority the plan argues from.

**Core principle:** Maximise safe parallelism — one subagent per independent, disjoint-file task — gate each on tests + lint, commit per task, and never call a task done while anything is red.

## Prerequisites

- **A plan *and* its spec.** Normally a `plan-draft` file (`docs/plans/…md`) with a task map, per-task file lists, `Depends on`/`Blocks`, and `DoD = Scenario`. **Read the linked `.feature` spec too** — it is the binding authority (conflicts inside the plan resolve against it), and its **scenarios are the acceptance tests you build**. Execution uses both files throughout: the plan for the graph and files, the spec for the tests.
- **No plan, only a spec + context?** Stop and confirm with the user before going further — offer to run `plan-draft` first to get a real plan. Never execute plan-less silently.
- **Branch.** The plan's Context names the **target branch** — check it out (create it if needed) and work there. It must be a feature branch, never a shared one (`main`/`master`/`develop`); if the plan names a shared branch or none, confirm with the user and branch first.

## When NOT to use

A one-file, single-task change with no sequencing — just make it (with its test); no orchestration needed.

## The execution model

1. **Graph, not phase order.** Build the dependency graph from each task's `Depends on`/`Blocks`. The plan's phases are a reading aid; the graph is the truth.
2. **Waves.** A wave is every task whose dependencies are already done. **Reorder and regroup freely to maximise parallelism** — pull independent tasks together — as far as the graph allows.
3. **Parallel on disjoint files.** Within a wave, tasks whose declared file sets **don't overlap** run as one subagent each, **dispatched in a single message** (multiple dispatch calls in one response run concurrently; one per response is sequential). Tasks that share a file → **serialize** them. Trivial or tightly-coupled tasks → **do inline**; a subagent has to earn its seat.
4. **Direct writes, no worktrees.** Parallel agents write straight to the branch. This is safe *only* because their files are disjoint — which is why an implementer that needs a file outside its set must stop, not write (see the contract).
5. **The orchestrator commits, per task, by file set.** After a wave's implementers report, commit each task on its own (`git add` that task's files, then commit). Never let the parallel agents commit — they share one git index and would race on its lock. One commit per task.

## The per-task gate (never skipped)

A task is done only when, with the run captured as evidence:

- its **DoD scenario passes** — red before the task, green after;
- the **tests** covering the change pass, and nothing else breaks;
- **lint passes** if the project has one (detect the command: package scripts, Makefile, pre-commit, CI, or `CLAUDE.md`);
- output is **pristine** — no errors, no warnings.

**No excuses.** A red test or failing lint is *fixed*, never explained away or deferred — we are part of the app and it ships working. If an implementer can't get there, run **at most 2 fix rounds** (resume the same agent with the gap). Still red after two → **stop and flag it to the user** as a blocker. "Done with caveats" is not a state.

No per-task reviewer subagent — the DoD scenario passing *is* the per-task spec check. Quality review happens once, at the end.

## The implementer contract

Each task goes to a **fresh** subagent that gets only:

- its **one task's brief** — description, technical notes, steps, file list, and `DoD` scenario — plus the relevant spec scenario(s);
- **interfaces and decisions** from completed dependency tasks it builds on;
- a pointer to repo conventions (`CLAUDE.md`).

Never hand it the whole plan or your session history — construct exactly what it needs, and pass anything large as a file to keep your own context clean.

Rules the dispatch carries:

- **Build the tests from the spec.** A task's acceptance test comes straight from its `.feature` scenario — the Gherkin Given/When/Then *is* the test's arrange/act/assert. Don't invent acceptance criteria the spec didn't state.
- **Stay within the declared files.** Need to touch a file outside the set? **Stop and report** — do not write. A surprise overlap breaks the disjoint-files guarantee the whole wave rests on.
- **No nested subagents** — the implementer never spawns its own helpers or reviewer.
- **Return** a short status (`done` / `blocked` / `needs-context`), the test + lint evidence, the files touched, and any concerns.
- **Model by task type:** mechanical and fully-specified (1–2 files, steps + snippets given) → a cheap, fast model; multi-file or judgment work → a standard model; design work or the final review → the most capable. Always name the model when dispatching — omitting it inherits your expensive session model.

## Running the plan

Execute **continuously** — wave after wave, no pausing to ask "should I continue?". Decide small ambiguities yourself and log them.

**Stop and ask only for:** a task at the 2-round cap; an irreversible or destructive operation; a push, publish, or merge to a shared branch; a plan so broken every path is a guess (plus the upfront no-plan and shared-branch gates).

### Progress file

Keep a progress file at `.skills/plans/<plan-title>/progress.md`. On first use, ensure `.skills/` is ignored **globally** so it never lands in a repo — append it to the global gitignore (`git config --global core.excludesfile`; create and point one if it's unset). Its first line names the plan, so a resumed session matches it to this plan. Record, per **task and step**: status, the DoD/test/lint evidence, the commit hash, fix-round outcomes, decisions you made, and which tasks ran together in a wave. Mirror completion into the plan's own `[ ]`→`[x]` checkboxes. On resume: match the plan, skip what's done, continue — the progress file and `git log` outrank your memory after compaction.

## Finish

When every task is done:

1. **One final whole-branch review** — `code-review-expert` for a small branch, or `pr-review`'s angle fan-out for a large one. Feed it the branch diff (`merge-base…HEAD`) and the progress file's parked/deferred items. **Stop at the report — never publish** (that's an outward action).
2. **One bounded fix pass** on the final findings (not one fixer per finding), then stop.
3. **Hand back a report:** what was built, the decisions you made, any parked findings, and the test + lint evidence.

Per-task commits already exist. **Do not** merge, push, or open a PR on your own — those are the user's call.

## Common Mistakes

- Parallelizing tasks that share a file → clobbered writes; only disjoint file sets run together.
- Letting parallel agents commit → they race on the git index; the orchestrator commits per task.
- Following the plan's phase order literally → build the dependency graph and regroup for parallelism.
- Marking a task done with a red test or failing lint → fix it, or hit the cap and stop; never defer.
- Handing an implementer the whole plan or your history → give it one task's brief; keep context lean.
- A per-task reviewer subagent → the DoD scenario is the per-task check; review once at the end.
- Auto-merging or pushing at the end → hand integration to the user.
