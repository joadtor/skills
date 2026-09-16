---
name: mutation-test
description: Use when a branch's tests should be proven to bite — plant one small bug at a time in the production lines the branch changed, run the tests that cover the file, and kill every mutant that survives with a spec-derived test. The LLM is the mutation tool; the bundled scripts only find where a bug could hide.
---

# Mutation Test

## Overview

A green suite proves little on its own: tests that never fail when the code breaks are decoration. This skill breaks the code on purpose — one small, deliberate **mutant** at a time in the lines this branch changed — runs the tests that cover that file, and treats every mutant that **survives** as a bug the suite would have let through. Each survivor is then killed with a test, shown to be equivalent, or raised as a spec gap. Nothing is "accepted".

**Core principle:** who tests the tests? A mutant is a bug you planted. A test that doesn't notice it wouldn't notice the real one.

**You are the mutation tool.** `scripts/mutation-points.sh` only answers *where* a bug could hide in the diff. Choosing, applying, testing, reverting, and resolving each mutant is your work — serially, with evidence, no external tooling.

## When to Use

- After `plan-execute` / `plan-execute-tdd`, before the final review — the branch's new tests are exactly what needs proving.
- On any feature branch whose new code has tests you want to trust before merging.

## When NOT to use

- **The changed files have no tests.** There is nothing to kill; stop and say so — the fix is writing tests (`plan-execute-tdd`), not mutating.
- On a shared branch (`main` / `master` / `develop`), or for config, data, migration, or generated changes — those aren't behaviour.

## Prerequisites

- **A feature branch with committed source.** A mutant is reverted with `git checkout -- <file>`, which only restores committed content, so every production file you'll mutate must be clean in `git status`. Uncommitted test files are fine — they're never mutated.
- **The base** is found the way `code-review-expert` does it (`develop`, then `master`, then `main`, else origin's default); the script does this for you, or pass it explicitly.
- **The spec, if there is one.** Look for the `.feature` in the plan's Context (`docs/plans/`) or `docs/specs/`. It is the authority for what a killing test may assert. No spec → survivors are batch-confirmed with the user (see Resolve).
- **A ledger** at `.skills/mutations/<branch>/ledger.md`. On first use, ensure `.skills/` is ignored **globally** so it never lands in a repo — append it to the global gitignore (`git config --global core.excludesfile`; create and point one if it's unset). On resume: read the ledger, skip every mutant that already has a verdict.

## Step 1 — Find the candidates

```bash
scripts/mutation-points.sh            # or: scripts/mutation-points.sh develop
```

It lists the changed production files against the base, extracts only the **changed lines**, and hands them to `scripts/lang/<lang>.sh` (Ruby, JS/TS, Rust, Python) — regex rules over those lines, one candidate per rule that matches. Output is tab-separated:

```
app/models/order.rb:12   high   delete-call   total >= 100 && customer.active?   # total >= 100 && customer.active?
app/models/order.rb:12   mid    and-or        total >= 100 && customer.active?   total >= 100 || customer.active?
app/models/order.rb:12   low    ge-gt         total >= 100 && customer.active?   total > 100 && customer.active?
```

The script is deliberately dumb. **You are the filter:**

- **Skip** what can't change behaviour: log and print text, error-message wording, comments and docstrings, formatting, type-only lines.
- **Add** what regex can't see when the diff warrants it: a method body replaced by its default return, swapped argument order, a loop bound off by one, a whole branch removed.
- **Severity is the run order per line.** `high` (statement deleted, condition negated, return value dropped) → `mid` (operator or predicate flipped) → `low` (boundary nudged, literal changed). If the line's high mutant **survives**, skip its remaining candidates — the line has no real coverage and one survivor tells the story. If it's **killed**, still run the rest: boundary mutants are where off-by-one bugs hide behind a happy-path test.
- **No cap.** Every changed line with behaviour gets at least one mutant.
- **Module size.** The finder warns when one file yields more than 50 candidates. A module that large is doing too much to harden in one sitting: report it and offer a split *before* mutating it. Don't split on your own.

## Step 2 — The loop, one mutant at a time

Serially, no subagents: two live mutants and one red run tell you nothing about which one died.

1. **Apply** exactly the one-line change with a single Edit. Confirm `git diff --stat` shows one file, one line.
2. **Find the related tests** for that file — never the full suite (it runs 50 minutes on the big apps): the mirrored test file (`app/models/order.rb` → `spec/models/order_spec.rb`), every test file that references the file's class, module, or function names (grep the test tree), and the tests written for the task's scenarios.
3. **Run them.** Red → **KILLED**. Green → **SURVIVED**. Doesn't parse or compile → **INVALID** — the mutant is broken, not the tests; discard it. Hangs → **TIMEOUT** — stop it, discard, note it. Only KILLED and SURVIVED count.
4. **Revert** with `git checkout -- <file>` and confirm `git diff --quiet -- <file>`.
5. **Ledger** one line: file:line, label, mutant, tests run, verdict.

## Step 3 — Resolve every survivor: three buckets, no fourth

- **Kill** — write the test that would have caught it. It comes from the **requirement, not the mutant**: the spec scenario the behaviour belongs to — its Given/When/Then is the test's arrange/act/assert. Then prove it: green on the real code; re-apply the mutant, run, **watch it go red**; revert. A killing test that never saw its mutant die is not evidence.
- **Equivalent** — the change alters no observable behaviour (a dead branch, a boundary that can't occur, a value nothing reads). One-line reason in the ledger, no test.
- **Spec gap** — real behaviour no scenario specifies. Don't invent the rule to kill it; the spec is the authority. Raise it to the user as a question.

**No spec?** Finish the whole loop first. Then present every survivor as one list of proposed behaviours ("an order of exactly 100 still qualifies for the discount — yes?") and let the user confirm, correct, or reject in one pass. Confirmed → kill, in their wording. Rejected → equivalent. One conversation, not one per survivor.

**"Accepted — not worth a test" does not exist.** It's the excuse that hollows the exercise out.

## Gate, score, finish

Done means **every candidate has a verdict and every survivor is in a bucket.** Report the score *before* your kills — `killed / (killed + survived)` — as information about how well the code was tested when it was built; **never gate on a number**, a threshold is just "accept" with a percentage.

Then:

1. Run the related tests once more — all green, new tests included.
2. **Commit once:** `tests: kill N surviving mutants in <scope>`, the ledger's kill list as the body. Don't push.
3. **Hand back:** the score, the kills (file:line → the test), the equivalents with reasons, the spec gaps as questions, and anything invalid or timed out.

### Ledger

```markdown
# mutation-test — feature/guest-checkout · base origin/develop · spec docs/specs/2026-09-10-guest-checkout.feature

| # | file:line | label | mutant | tests run | verdict | resolution |
|---|---|---|---|---|---|---|
| 1 | app/models/order.rb:12 | delete-call | # total >= 100 && … | spec/models/order_spec.rb | KILLED | — |
| 2 | app/models/order.rb:12 | ge-gt | total > 100 | spec/models/order_spec.rb | SURVIVED | killed — order_spec.rb "qualifies at exactly 100" (Scenario: Threshold order gets the discount) |
| 3 | app/models/order.rb:16 | empty-string | logger.info "" | — | SKIPPED | log text |

Score before kills: 1 / 2 = 50%
```

## Adding a language

One file: `scripts/lang/<lang>.sh` — source `_common.sh` with the language's comment marker, declare `rule <severity> <label> <pattern> <replacement> [<skip-pattern>]` lines high → low, call `run "$1"`. Then add the extension to the `case` in `mutation-points.sh`. Patterns are POSIX ERE (no `\b`, no lookaround); a rule prints a candidate only when its replacement actually changes the line.

## Common Mistakes

- Running the full suite per mutant → related tests only; find them by mirror path, symbol grep, and scenario.
- Two mutants live at once, or parallel subagents → serial; one mutant, one run, one verdict.
- Counting a syntax-broken mutant as KILLED → it's INVALID; the tests never ran.
- Writing the killing test from the mutant → from the spec scenario, then watch it fail against the mutant.
- "Accepting" a survivor → kill, equivalent, or spec gap; nothing else.
- Mutating tests, config, migrations, generated code → production lines of the diff only; the script already skips them.
- Gating on a mutation score → the gate is bucket completeness.
- Starting with uncommitted production files → the revert has nothing to restore; commit first.
