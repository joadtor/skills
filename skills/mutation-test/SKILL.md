---
name: mutation-test
description: Use when a branch's tests should be proven to bite — plant one small bug at a time in the production lines the branch changed (in compiled languages, all built in once behind runtime switches), run the tests that cover the file, and kill every mutant that survives with a spec-derived test. The LLM is the mutation tool; the bundled scripts only find where a bug could hide.
---

# Mutation Test

## Overview

A green suite proves little on its own: tests that never fail when the code breaks are decoration. This skill breaks the code on purpose — one small, deliberate **mutant** at a time in the lines this branch changed — runs the tests that cover that file, and treats every mutant that **survives** as a bug the suite would have let through. Each survivor is then killed with a test, shown to be equivalent, or raised as a spec gap. Nothing is "accepted".

**Core principle:** who tests the tests? A mutant is a bug you planted. A test that doesn't notice it wouldn't notice the real one.

**You are the mutation tool.** `scripts/mutation-points.sh` only answers *where* a bug could hide in the diff. Choosing, applying, testing, reverting, and resolving each mutant is your work — serially, with evidence, no external tooling. In a compiled language, the mutants of one build are planted together as a **schema** — compiled once, switched on one at a time at runtime (Step 3b).

## When to Use

- After `plan-execute` / `plan-execute-tdd`, before the final review — the branch's new tests are exactly what needs proving.
- On any feature branch whose new code has tests you want to trust before merging.

## When NOT to use

- **The changed files have no tests.** There is nothing to kill; stop and say so — the fix is writing tests (`plan-execute-tdd`), not mutating.
- On a shared branch (`main` / `master` / `develop`), or for config, data, migration, or generated changes — those aren't behaviour.

## Prerequisites

- **A feature branch with committed source.** A mutant is reverted with `git checkout -- <file>`, which only restores committed content, so every production file you'll mutate must be clean in `git status`. Uncommitted test files are fine — they're never mutated.
- **The base** is found the way `code-review-expert` does it (`develop`, then `master`, then `main`, else origin's default); the script does this for you. Or pass it: a branch on origin is diffed as `origin/<branch>...HEAD`; any other ref (a commit, a tag) as `<ref>..HEAD` — use that to mutate just one plan's work on a long branch.
- **The spec, if there is one.** Look for the `.feature` in the plan's Context (`docs/plans/`) or `docs/specs/`. It is the authority for what a killing test may assert. No spec → survivors are batch-confirmed with the user (see Resolve).
- **A ledger** at `.skills/mutations/<branch>/ledger.md`. On first use, ensure `.skills/` never lands in a repo — if `.skills/.gitignore` is missing, create it containing `*` (it ignores the whole folder, itself included; never touch the user's global gitignore). On resume: read the ledger, skip every mutant that already has a verdict. Rows carry a `schema` column (build unit + switch id, e.g. `rdp-core#7`; `—` for interpreted languages), and a compiled pass logs its build command and duration once per batch.

## Step 1 — Find the candidates

```bash
scripts/mutation-points.sh            # or: scripts/mutation-points.sh develop   |   scripts/mutation-points.sh 244dd55
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
- **Severity is the run order per line.** `high` (statement deleted, condition negated, return value dropped) → `mid` (operator or predicate flipped) → `low` (boundary nudged, literal changed). If the line's high mutant **survives**, skip its remaining candidates — the line has no real coverage and one survivor tells the story. If it's **killed**, still run the rest: boundary mutants are where off-by-one bugs hide behind a happy-path test. The order matters only within a line; across lines any order is fine.
- **No cap.** Every changed line with behaviour gets at least one mutant.
- **Module size.** The finder warns when one file yields more than 50 candidates. A module that large is doing too much to harden in one sitting: report it and offer a split *before* mutating it. Don't split on your own.

## Step 2 — Calibrate the resource budget

Mutants are meant to break code, and broken code can turn a loop infinite or let an allocation grow without bound. Test runners also start one worker per core by default. Run unguarded, a single bad mutant can freeze the machine. Find out how much the machine can take by measuring safe runs first, never by crashing it.

1. **Baseline the clean code.** Run the related tests (see Step 3a.2) once, unmutated, starting **low**: 1–2 workers (`PARALLEL_TEST_PROCESSORS=2`, `jest --maxWorkers=2`, `pytest` without `-n` or `-n 2`, `cargo test -j 2 -- --test-threads=2`), under `nice -n 10`, wrapped in `/usr/bin/time -l` (macOS) or `/usr/bin/time -v` (Linux) to get wall time and peak memory.
2. **Scale up while there's room.** If the baseline used a small share of the cores and RAM, add one worker step and measure again. Stop at the first step where load approaches the core count or memory passes half of the free RAM, then go back one step. Every step is a measured run on clean code. Never test the limit with a mutant.
3. **Set the budget:** timeout = 3× the calibrated wall time (at least 30 s); memory ceiling = 3× the calibrated peak, capped at half the free RAM. Record workers, timeout, and ceiling in the ledger header and reuse them for every mutant.

Every mutant run then goes through the guard:

```bash
timeout -k 10 <timeout>s nice -n 10 <related test command>   # no `timeout`? use gtimeout (brew install coreutils)
```

On Linux, also run `ulimit -v <ceiling-in-KB>` inside the same subshell. macOS ignores `ulimit -v`, so there you check the run's memory with `ps -o rss= -p <pid>` while it runs and kill it if it passes the ceiling — for runs of a few seconds the timeout alone is enough. Long runs go in the background so a stuck mutant doesn't block you.

## Step 3a — Interpreted languages (edit → run → revert)

Ruby, Python, JS/TS under vitest/jest. Serially, no subagents: two live mutants and one red run tell you nothing about which one died.

1. **Apply** exactly the one-line change with a single Edit. Confirm `git diff --stat` shows one file, one line.
2. **Find the related tests** for that file — never the full suite (it runs 50 minutes on the big apps): the mirrored test file (`app/models/order.rb` → `spec/models/order_spec.rb`), every test file that references the file's class, module, or function names (grep the test tree), and the tests written for the task's scenarios. Nothing found (a component mounted only by its parent)? Search for tests of the parent chain; the full suite is the last resort, and the ledger says so.
3. **Run them under the Step 2 guard.** Red → **KILLED**. Green → **SURVIVED**. Doesn't parse or compile → **INVALID** — the mutant is broken, not the tests; discard it. Exceeds the timeout or the memory ceiling → **TIMEOUT** — make sure no runner or worker process is still alive (`pgrep -f <runner>`), discard, note it. Only KILLED and SURVIVED count.
4. **Revert** with `git checkout -- <file>` and confirm `git diff --quiet -- <file>`.
5. **Ledger** one line: file:line, label, mutant, tests run, verdict.

Field notes:

- **TS under vitest/jest is not type-checked** — esbuild strips types, so a mutant `tsc` rejects (`return;` in a fn returning `boolean`, dropping `?.` on a possibly-undefined value) still runs and gets a misleading verdict. Check with `tsc`; what it rejects is INVALID (field test: 13 of 93 candidates).
- **JSX markup-only candidates** (`className`, `type="button"`, layout spans, i18n label keys) are log text: skip them unless a scenario asserts them.

## Step 3b — Compiled languages (schema → build once → run per switch)

Rust, Go, Java/Kotlin, C#, Swift, C/C++. Rebuilding per mutant costs a build each; instead plant every mutant behind its own runtime switch, build once, and run once per switch — still exactly **one mutant live per run**. Field test (Rust, two crates): 13 mutants, 1 build (13 s), 13 runs, 0 recompiles.

1. **Group into as few builds as possible.** One batch when one test command builds every unit (`cargo test -p config -p rdp-core --lib`, Go `./...`, a multi-module Gradle task) — a dependency's mutants then reach its dependents' tests too. Only when no single command covers them, batch per build unit (Cargo crate, Go package, Maven/Gradle module, .NET project), leaf-first, so one batch never forces another's rebuild.
2. **Plant the schema.** Number the mutants in ledger order and rewrite each original line into a form that picks original or mutant by id (see "Compiled languages — rewrite shapes"). The switch is ONE environment variable with a project-unique name (`RDP_MUT=7`), read at runtime — never a build flag. Pre-filter candidates that can't compile first (statement deletion on the second line of a split `let`, `return Default::default()` in a fn returning `Result`, `while let None = x` dropping a binding the body uses, `format!("", args)` whose arguments are left unused): INVALID up front (field test: 5 of 21). Skip, with a reason, a mutant identical to the original (`return None` → `Default::default()` when the type's default is `None`) and a semantic duplicate (negate-condition vs drop-negation, or eq-neq, on the same condition). **Plant with a script, not by hand:** a list of (file, exact original text, rewrite), asserting each original occurs exactly once in its file and each file's line count is unchanged — that keeps the ledger's line numbers valid.
3. **Prove the schema inert.** Build, then run the related tests with no switch set: as green as before planting. Red means a rewrite changes behaviour when off — fix it before any mutant runs. Log the build command and duration.
4. **Compile errors are per rewrite.** If the build fails, find the offending rewrite(s) (build after each file, or bisect by halves), mark each INVALID, restore its original line, rebuild. One bad rewrite never discards the batch.
5. **Run once per switch,** in severity order, under the Step 2 guard, filtered to the related tests — libtest takes several filters after `--`: `RDP_MUT=7 cargo test -p config -p rdp-core --lib -- catalogue_sync applications::sync`. Loop it in one shell command printing `M<id> KILLED|SURVIVED compiles=<n> <failing tests>`; `compiles` (the count of `Compiling` lines) must be 0, and the failing test names are the ledger's evidence — prefix them with their crate/package when several units share module names (`config::tests::ports`). A line whose high mutant survived skips its remaining switches.
6. **Kills reuse the schema.** Keep it planted while writing the killing tests (Step 4): adding a test file costs one rebuild, then "green on the real code" is a run with no switch and "watch it fail" is `RDP_MUT=<id>` on the same build. If the kills must wait for the user (no spec), revert now and re-plant with the same script when the answers come.
7. **Revert last:** `git checkout -- <every file in the schema>`, then `git diff --quiet` on them. Rebuild before the next batch if batches share artifacts.

## Step 4 — Resolve every survivor: three buckets, no fourth

- **Kill** — write the test that would have caught it. It comes from the **requirement, not the mutant**: the spec scenario the behaviour belongs to — its Given/When/Then is the test's arrange/act/assert. Then prove it: green on the real code; re-apply the mutant, run, **watch it go red**; revert. A killing test that never saw its mutant die is not evidence.
- **Equivalent** — the change alters no observable behaviour (a dead branch, a boundary that can't occur, a value nothing reads). One-line reason in the ledger, no test.
- **Spec gap** — real behaviour no scenario specifies. Don't invent the rule to kill it; the spec is the authority. Raise it to the user as a question.

**No spec?** Finish the whole loop first. Mark the clear equivalents yourself, each with its reason (they need no answer). Then present every remaining survivor as one list of proposed behaviours ("an order of exactly 100 still qualifies for the discount — yes?") and let the user confirm, correct, or reject in one pass. Confirmed → kill, in their wording. Rejected → equivalent. One conversation, not one per survivor.

**"Accepted — not worth a test" does not exist.** It's the excuse that hollows the exercise out.

## Compiled languages — rewrite shapes

`m(n)` is shorthand for the inline check — in Rust `(std::env::var("RDP_MUT").as_deref() == Ok("7"))`. Plant it inline, not as a helper fn: a helper adds lines and shifts every line number the ledger points at. In condition position (`if m(n) {`) drop the outer parentheses, or rustc warns `unused_parens` on every switch — harmless, but noise.

```
delete-call        call(x)?;                →  if !m(1) { call(x)?; }
negate-condition   if a > b {               →  if (a > b) != m(2) {
return-default     return v;                →  if m(3) { return Default::default(); } return v;
some-none          Some(x)                  →  (if m(4) { None } else { Some(x) })
and-or             a && b                   →  (if m(5) { a || b } else { a && b })
eq-neq / ge-gt …   a >= b                   →  (if m(6) { a > b } else { a >= b })
true-false         true                     →  (!m(7))
number-plus-one    n                        →  (if m(8) { n + 1 } else { n })
empty-string       "text"                   →  (if m(9) { "" } else { "text" })
false-true (arg)   f(a, false)              →  f(a, m(10))
macro literal      warn!(e = %err, "text"); →  if m(11) { warn!(e = %err, ""); } else { warn!(e = %err, "text"); }
two on one line    return (state, false);   →  if m(12) { return Default::default(); } return (state, m(13));
several, one expr  if n > 10 {              →  if (if m(14) { n >= 10 } else if m(15) { n > 10 + 1 } else { n > 10 }) != m(16) {
```

- Both arms have the same type; only the selected arm evaluates, so a value moved in one arm only is fine (`&if m(n) { error } else { error.without_url() }`).
- Keep each rewrite on its mutant's own line(s), so revert and ledger stay line-addressed.
- Where an expression can't host a runtime branch — `const` / `static` initialisers, attribute arguments, `match` patterns, macro-internal tokens, type positions — use the Step 3a loop (edit → build → run → revert) for that mutant only, and say so in the ledger.
- Don't lint (clippy, golangci-lint …) a planted schema; the rewrites aren't meant to pass.

Same shape elsewhere: Go `os.Getenv("RDP_MUT") == "7"`, Java/Kotlin `"7".equals(System.getenv("RDP_MUT"))`, C# `Environment.GetEnvironmentVariable("RDP_MUT") == "7"`, Swift `ProcessInfo.processInfo.environment["RDP_MUT"] == "7"`, C/C++ `getenv`.

## Gate, score, finish

Done means **every candidate has a verdict and every survivor is in a bucket.** Report the score *before* your kills — `killed / (killed + survived)` — as information about how well the code was tested when it was built; **never gate on a number**, a threshold is just "accept" with a percentage.

Then:

1. Run the related tests once more — all green, new tests included.
2. **Commit once:** `tests: kill N surviving mutants in <scope>`, the ledger's kill list as the body. Don't push.
3. **Hand back:** the score, the kills (file:line → the test), the equivalents with reasons, the spec gaps as questions, and anything invalid or timed out.

### Ledger

```markdown
# mutation-test — feature/guest-checkout · base origin/develop · spec docs/specs/2026-09-10-guest-checkout.feature
budget: 2 workers · timeout 90s · memory 3 GB (baseline 28s, 1 GB peak)
batch pricing: `cargo test -p pricing --lib` · 2 mutants, 1 build (11 s), inert run green, 2 runs, 0 recompiles

| # | file:line | label | schema | mutant | tests run | verdict | resolution |
|---|---|---|---|---|---|---|---|
| 1 | app/models/order.rb:12 | delete-call | — | # total >= 100 && … | spec/models/order_spec.rb | KILLED | — |
| 2 | app/models/order.rb:12 | ge-gt | — | total > 100 | spec/models/order_spec.rb | SURVIVED | killed — order_spec.rb "qualifies at exactly 100" (Scenario: Threshold order gets the discount) |
| 3 | app/models/order.rb:16 | empty-string | — | logger.info "" | — | SKIPPED | log text |
| 4 | crates/pricing/src/lib.rs:40 | negate-condition | pricing#1 | if (qty > 0) != m(1) | pricing::discount | KILLED | — |
| 5 | crates/pricing/src/lib.rs:44 | some-none | pricing#2 | None | pricing::discount | KILLED | — |

skipped: 1 log/markup text · 0 duplicate · 0 identical to original · 0 cannot compile · 0 test file
Score before kills: 3 / 4 = 75%
```

## Adding a language

One file: `scripts/lang/<lang>.sh` — source `_common.sh` with the language's comment marker, declare `rule <severity> <label> <pattern> <replacement> [<skip-pattern>]` lines high → low, call `run "$1"`. Then add the extension to the `case` in `mutation-points.sh`. Patterns are POSIX ERE (no `\b`, no lookaround); a rule prints a candidate only when its replacement actually changes the line. A compiled language also needs its rewrite shapes under "Compiled languages — rewrite shapes" and its build-unit rule in Step 3b.1.

## Common Mistakes

- Running the full suite per mutant → related tests only; find them by mirror path, symbol grep, and scenario.
- Two mutants live at once, or parallel subagents → serial; one mutant, one run, one verdict.
- Running mutants with the runner's default workers and no timeout or memory limit → calibrate on clean code first (Step 2), then guard every run.
- Leaving worker processes alive after a TIMEOUT → check none are left before the next mutant, or the load builds up run after run.
- Counting a syntax-broken mutant as KILLED → it's INVALID; the tests never ran.
- Writing the killing test from the mutant → from the spec scenario, then watch it fail against the mutant.
- "Accepting" a survivor → kill, equivalent, or spec gap; nothing else.
- Mutating tests, config, migrations, generated code → production lines of the diff only; the script already skips them.
- Gating on a mutation score → the gate is bucket completeness.
- Starting with uncommitted production files → the revert has nothing to restore; commit first.
- Passing the switch as a build flag (cfg, `-D`, feature, RUSTFLAGS) → a rebuild per mutant; read an environment variable at runtime.
- A build script that reads the variable (`cargo:rerun-if-env-changed`, generated code) → also a rebuild per mutant; pick a name nothing in the build reads.
- Skipping the inert check → a rewrite that changes behaviour when off makes every verdict in the batch meaningless.
- Marking a whole batch INVALID for one compile error → isolate the bad rewrite, keep the rest.
- Not reverting every schema file → a switch left in production code; `git diff --quiet` on the batch's files before the next batch and at the end, and grep the variable name in the source.
- A test harness that clears the environment → its tests silently run unmutated; note it in the ledger.
- Running the formatter on a planted schema (`cargo fmt --all` to tidy a killing test) → it reformats the production files too; format only the test files (`rustfmt <file>`), or after the revert.
- Planting candidates that can't compile → the batch build has to bisect them out; pre-filter them as INVALID.
