---
name: complexity-check
description: Use when asked to check, measure, or reduce the cyclomatic complexity of the branch's changed code or of a path — reports every function over its language's limit, then refactors only with the user's agreement, under the test suite. Other skills invoke it as `complexity-check check-only`.
argument-hint: "[setup|check-only] [path...]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/check.sh *), Bash(${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/setup.sh plan *)
---

# Complexity Check

## Overview

Measure the complexity of every function in scope with each language's own tool, report the ones over the limit, and — only if the user says so — refactor them until they fit, with the full test suite run after every round.

**Core principle:** measure, report, then ask. The numbers come from the script, never from your own count; the decision to change code comes from the user, never from you.

The work is split in two scripts:

- `${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/check.sh [path...]` — measures. Offline, installs nothing; a language whose tool is missing is skipped, with its files named.
- `${CLAUDE_PLUGIN_ROOT}/skills/complexity-check/scripts/setup.sh plan [path...]` / `install <tool>…` — lists the missing tools, then installs only the ones the user approved into `~/.cache/joadtor/complexity-check/`. Never into the project.

Limits per language, the install methods, and the refactor playbook are in `reference.md` — read it before refactoring.

## Modes

| Invocation | Scope | Asks the user? |
|---|---|---|
| `complexity-check` | functions in files changed on the branch vs its base | yes |
| `complexity-check <path>` | every function under the path | yes |
| `complexity-check setup [path...]` | step 1 only; used by other skills before a run | once, if a tool is missing |
| `complexity-check check-only [path...]` | same scope; used by other skills | **never** |

**`setup`** runs step 1 and stops — no check, no report. **`check-only`** (another skill invoked you, often from a subagent that can't ask): run `check.sh` once, return its stdout and stderr verbatim, and stop. No setup, no install, no refactor, no question. A missing tool stays a reported skip.

## 1. Set up — one question, only if something is missing

Run `setup.sh plan [path...]`. Empty output → go to step 2 without asking. Otherwise each line is `lang  tool  version  method  scope`; ask **once** with `AskUserQuestion`, listing every tool with its version and the cache path, and say plainly that the project's files are not touched:

- `scope = global-toolchain` (clippy) → say it changes the user's Rust toolchain via `rustup`, not the cache.
- `scope = runtime-missing` → not installable here; tell the user what to install, and that language will be skipped.

Options: **Install all** · **Pick which** · **Skip** (those languages go unchecked). Then run `setup.sh install` with exactly the approved tools. If you cannot ask, don't install.

## 2. Check, then report before touching anything

Run `check.sh [path...]`. Each stdout line is `file:line  lang  function  metric  score  limit  source`; stderr names skipped languages and bypassed configs. Report to the user **before any edit**:

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

For each function still over its limit, a short report: score vs limit and source, what the rounds tried, and why it is still over. Recommend one of: **refactor further** (with a concrete plan) · **exempt it** with a disable comment that states the reason · **accept as is** · **raise the limit** in the project config. Ask with `AskUserQuestion`, your recommendation first. No disable comment and no config change without the user's answer.

## Common Mistakes

- Refactoring before reporting → report first, then ask; "check and fix it" still means show the numbers first.
- Counting branches yourself or quoting the tool's default → use `check.sh`'s score, limit, and source.
- Writing tests for untested code on your own initiative → ask (step 3).
- Exempting, disabling, or raising a limit to make the check pass → the user decides (step 5).
- A fourth round "because it's close" → stop at 3 and hand over.
- Asking or installing in `check-only` mode → return the output and stop.
- Splitting a function so the branches just move into a helper with the same total → that's shuffling, not simplifying; see `reference.md`.
