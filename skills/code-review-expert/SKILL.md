---
name: code-review-expert
description: Use when reviewing a diff or branch for real bugs, security, performance, or quality problems — solo, or as the per-angle engine pr-review fans out. Confidence-gated, plain-word review. (For a whole PR with fan-out and publishing, use pr-review.)
---

# Code Review Expert

## Overview

Review a change the way an expert does: check every dimension, but report **only findings you can prove in the code** — each graded by how sure you are (**confidence**) and how much it matters (**severity**), written in plain words.

**Core principle:** A review is trustworthy only when every finding is grounded in the real code. Suppress what you can't prove — a confident nit beats a guessed-at catastrophe.

## When to Use

- Reviewing a diff or branch (or one angle of a larger review)
- Solo, or as the per-angle reviewer that `pr-review` fans out
- You want findings you can act on, not a wall of maybes

When NOT to use: a trivial one-line diff (just read it), or non-code content.

## Scope — what to review

Default to the branch delta against its base. Detect the base branch in this order, first that exists on the remote: **`develop` → `master` → `main`**. A branch the user names overrides this; if none of the three exists, ask the user (or fall back to the remote's default branch).

```bash
base=$(for b in develop master main; do
  git rev-parse --verify --quiet "origin/$b" >/dev/null && echo "$b" && break
done)
# none of the three on the remote? fall back to the remote's default branch
[ -z "$base" ] && base=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
git diff "origin/$base...HEAD"        # three dots: only what this branch adds
```

**Only flag what this diff introduces or touches.** Never report pre-existing issues outside the change.

## Score every finding on two axes

**Confidence (0–100) — is it real?** This is the gate.

| Score | Meaning |
|---|---|
| 0 | Not real — you can't point to it, or it's pre-existing |
| 25 | Might be real, might be a misread |
| 50 | Probably real, but you have doubts |
| 70 | You opened the code and confirmed it — **report threshold** |
| 100 | Certain — the code plainly shows it |

**Report only findings with confidence ≥ 70.** Below that, drop it — don't hedge, don't list it.

**Severity — how much does it matter?** A label, kept separate from confidence:

- 🔴 **blocking** — must fix before merge (bug, security hole, data loss)
- 🟡 **important** — should fix; a real problem, not fatal
- 🟢 **nit** — minor; take it or leave it

Every finding carries both. A certain nit ships (🟢, conf 95). A scary bug you're only guessing at does **not** (would-be 🔴, conf 40 → dropped).

## Ground every finding (this is what earns confidence ≥ 70)

Before you report anything:

- **Open the `file:line`** and confirm the code actually says what you claim. Can't find it? Drop it.
- **Re-derive the cause** from the surrounding code, models, and config — don't trust a first impression.
- **Check the project's own rules first** (`CLAUDE.md` or equivalent). A finding that breaks an explicit project convention is high-confidence; a style opinion the project never stated is not.

## What to look for

Tech-agnostic — the same patterns repeat across languages:

- **Correctness & edge cases** — nil/empty, off-by-one, wrong branch taken, race conditions
- **Security & authorization** — input validation, injection, exposed secrets, tenant/data isolation
- **Error handling** — failures swallowed, wrong error surfaced, missing rollback
- **Performance** — N+1 queries, needless loops, heavy work in a hot path
- **Tests** — is the new behavior covered? do the tests check behavior, not internals?
- **Conventions** — does it match the project's stated rules and the surrounding patterns?
- **Maintainability** — clear names, functions doing one thing (past cyclomatic complexity 8 they rarely do), no dead code

## Writing findings

- **Plain, simple words.** Name the concrete behavior. No jargon, no review-process speak.
- **Small but detailed enough** — one clear sentence on what's wrong and what it causes, not a cryptic phrase.
- **Evidence is mandatory** — quote the offending code so anyone can verify it.
- **Recommended fix only if there's a real one.** No clean fix? Say what's wrong and stop.

## Output format

```markdown
Reviewed: <scope, e.g. origin/develop...HEAD>

## 🔴 Blocking
- **<short title>** — `path/file:42` — <plain words: what's wrong + what it causes> — _conf 85_
  ↳ evidence: `<offending code>`
  ↳ fix: <recommended fix>

## 🟡 Important
- (none)

## 🟢 Nitpicking
- **<short title>** — `path/file:88` — <what's wrong + its effect> — _conf 90_
  ↳ evidence: `<offending code>`
```

Always print all three sections; write `- (none)` when one is empty — an empty section means "checked, nothing here." No praise or summary section.

## Common mistakes

- Reporting a hunch you can't point to in the code → drop it (confidence < 70)
- Jargon or long-winded explanations → plain words, one sentence
- Flagging pre-existing issues → only what the diff touches
- Padding with praise or a summary → findings only
- One big block per finding → one compact bullet + evidence (+ fix if any)
- Mixing "is it real" with "does it matter" → keep confidence and severity separate
