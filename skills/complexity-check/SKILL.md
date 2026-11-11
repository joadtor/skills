---
name: complexity-check
description: Use when asked to check, measure, or reduce the complexity (cognitive complexity) of the branch's changed code or of a path — reports every function over the limit, then refactors only with the user's agreement, under the test suite. Other skills invoke it as `complexity-check check-only`.
argument-hint: "[setup|check-only] [path...]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/check.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/setup.sh plan *)
---

# Complexity Check

## Overview

Measure the **cognitive complexity** of every function in scope, report the ones over the limit (15 unless the project sets its own), and — only if the user says so — refactor them until they fit, with the full test suite run after every round.

**Core principle:** measure, report, then ask. The numbers come from the script, never from your own count; the decision to change code comes from the user, never from you.

**The project's tool first.** If the project has a cognitive-complexity tool configured (ESLint with sonarjs, Biome, complexipy, gocognit, clippy), the check runs it with the project's limit; otherwise lizard measures — except Ruby, which the skill's own scorer measures (lizard ignores Ruby nesting). Everything runs on this machine; nothing leaves it.

The work is split in two scripts:

- `${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/check.sh [path...]` — measures. Offline, installs nothing; a language it can't measure is skipped, with its files named.
- `${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/setup.sh plan [path...]` / `install lizard` — says whether lizard is needed and missing, then installs it into `~/.cache/joadtor/complexity-check/` once the user agrees. It never installs a project's own tool, and never touches the project.

A project's own tool runs with the project's own config (as its CI would) — the same trust as running its tests. lizard only reads files.

Tools, limits, unparsable files, the refactor playbook and exemption syntax are in `reference.md` — read it before refactoring.

## Modes

| Invocation | Scope | Asks the user? |
|---|---|---|
| `complexity-check` | functions in files changed on the branch vs its base | yes |
| `complexity-check <path>` | every function under the path | yes |
| `complexity-check setup [path...]` | step 1 only; used by other skills before a run | once, if a tool is missing |
| `complexity-check check-only [path...]` | same scope; used by other skills | **never** |

**`setup`** runs step 1 and stops — no check, no report. **`check-only`** (another skill invoked you, often from a subagent that can't ask): run `check.sh` once, return its stdout and stderr verbatim, and stop. No setup, no install, no refactor, no question. A missing tool stays a reported skip.

## 1. Set up — one question, only if something is missing

Run `setup.sh plan [path...]`. Empty output → go to step 2 without asking. Otherwise each line is `lang  tool  version  method  scope`:

- `tool = lizard`, `scope = cache` → ask **once** with `AskUserQuestion`: lizard, its version, the cache path, that the project's files are not touched and only the package is downloaded. Options: **Install** · **Skip** (the languages lizard would measure go unchecked). On Install, run `setup.sh install lizard`.
- `scope = runtime-missing` → a runtime is missing: `uv` for lizard, or `ruby` for the Ruby scorer. Tell the user what to install, and that those languages will be skipped.
- `scope = project-tool-missing` → the project configures its own tool but it isn't installed; tell the user to install the project's dependencies. Never install it yourself — lizard measures that language meanwhile.

If you cannot ask, don't install.

## 2. Check, then report before touching anything

Run `check.sh [path...]`. Each stdout line is `file:line  lang  function  cognitive  score  limit  source`; stderr names skipped languages and files that couldn't be parsed (unchecked — never call those clean). Report to the user **before any edit**:

- every offender: `file:line`, the function, score vs limit, **where the limit came from** (the `source` column — a project setting, or the skill default), and a one-line suggested refactor;
- every skipped language with its unchecked files;
- for each offender, whether any test exercises it (look for its class/function in the test files) — mark **no tests** if none.

Clean → say so, with the skips, and stop. Otherwise ask with `AskUserQuestion`: **Refactor all** · **Pick which** · **Just the report**. "Just the report" means no file changes.

## 3. No tests? Ask before refactoring it

For each chosen offender marked **no tests**, ask before touching it: **Write characterization tests first (recommended)** · **Refactor anyway** · **Skip it**. Characterization tests pin today's behavior and must pass on the unchanged code before the refactor starts. Never add tests the user didn't choose.

## 4. Refactor loop — at most 3 rounds

Each round:

1. Refactor the chosen offenders (playbook in `reference.md`) — behavior must not change.
2. Run the **full** test suite. Red → fix the code until green before anything else; lower complexity with red tests is not progress.
3. Run `check.sh` on the same scope.

Clean → stop and report. Still over → next round, up to **3**.

## 5. After round 3 — the user decides

For each function still over its limit, a short report: score vs limit and source, what the rounds tried, and why it is still over. Recommend one of: **refactor further** (with a concrete plan) · **exempt it** with a disable comment that states the reason · **accept as is** · **raise the limit** in the project config. Ask with `AskUserQuestion`, your recommendation first. No disable comment and no config change without the user's answer. For a function measured by the Ruby scorer (source `skill default`, lang `ruby`) there is no exemption comment yet, so offer only the other options.

## Common Mistakes

- Refactoring before reporting → report first, then ask; "check and fix it" still means show the numbers first.
- Counting branches yourself or quoting the tool's default → use `check.sh`'s score, limit, and source.
- Writing tests for untested code on your own initiative → ask (step 3).
- Exempting, disabling, or raising a limit to make the check pass → the user decides (step 5).
- A fourth round "because it's close" → stop at 3 and hand over.
- Asking or installing in `check-only` mode → return the output and stop.
- Splitting a function so the branches just move into a helper with the same total → that's shuffling, not simplifying; see `reference.md`.
