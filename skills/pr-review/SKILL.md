---
name: pr-review
description: Use when asked to review a pull request (especially "open N agents", "review the PR against <branch>", split findings into blocking vs nitpicking, score severity, or post the review as GitHub inline comments / request changes). Covers fan-out multi-agent review and publishing the result via the gh API.
---

# Parallel PR Review & Publish

## Overview

Review a PR by fanning out **independent review agents**, each focused on one angle, then **verify every finding against the actual code**, consolidate, **always severity-score & filter**, and publish as a single GitHub review with inline comments **only after confirming with the user**.

**Core principle:** One agent per independent review dimension → verify each finding → merge → score & filter → confirm → post once.

## Defaults (always apply unless the user overrides)

- **10 agents** — fan out the 10 angles in the table below.
- **Always verify before trusting** — every finding must be contrasted against the real code before it survives. Discard anything not grounded in the diff/files. Never skip this step.
- **Always score & filter** — score every issue 0–10 and drop anything **below 4**. Never skip this step, even if not explicitly asked.
- **Always confirm before publishing** — never post to GitHub without an explicit go-ahead from the user this turn. Present the scored report first, then ask whether to publish.
- **Standard publish format** — once the user says publish, use this shape unless they override it:
  - `event: REQUEST_CHANGES`.
  - Top-level `body` is the **empty string `""`** — all content lives in the inline comments. (The field must be present; `""` is accepted by the API.)
  - Every inline comment `@mention`s the PR author.
  - **No scores in published comments** — scores/confidence stay in the chat report only.
  - **Plain language** — write each comment so it's easy to understand at a glance: short sentences, name the concrete behavior, no review-process jargon.

## When to Use

- "Open N agents and review this PR against `<branch>`"
- "Split the report into blocking vs nitpicking"
- "Score each issue 0–10, drop anything below X"
- "Add these as PR comments / request changes / @mention the author"

When NOT to use: a tiny diff where one pass suffices — just review inline or use `/code-review`.

## Workflow

### 1. Get the diff
```bash
git fetch origin <base>            # e.g. develop / master
git diff origin/<base>...HEAD --stat
git diff origin/<base>...HEAD       # full diff for context
```
Use `...` (merge-base) so you only see what the PR adds, not base drift.

### 2. Fan out review agents (parallel, one message, multiple Agent calls)
Dispatch all agents in a **single message** — multiple Agent calls in one response run in parallel; one per response runs sequentially. **Default: 10 agents**, each assigned **one distinct angle** so they don't overlap:

| # | Angle |
|---|-------|
| 1 | Security, authorization & multi-tenancy isolation |
| 2 | Edge cases, race conditions & data integrity |
| 3 | Error handling, error codes & response patterns |
| 4 | API contract, REST design & serialization consistency |
| 5 | Service-layer architecture & project conventions |
| 6 | DB efficiency, queries & N+1 risks |
| 7 | Test coverage & quality |
| 8 | Routing & controller patterns |
| 9 | i18n / message completeness |
| 10 | Linter, style & repo rules |

Give each agent a prompt from this sample — fill `<angle>` from the table above (one distinct angle per agent), plus `<base>` and `<files>`:

```text
Invoke the `code-review-expert` skill, then review this PR through ONE lens only: <angle>.

- Stay strictly within this angle. The other agents cover the other angles, so don't review
  their points — overlap just produces duplicate findings.
- Scope: run `git diff origin/<base>...HEAD` and read it yourself. Flag only what this diff
  introduces or touches — never pre-existing issues.
- Focus files: <files>.
- Report in `code-review-expert`'s output format: the three severity sections, every finding
  with a confidence score and an evidence quote of the offending code. Report only what you
  can point to in the code. If your angle is clean, say so.
```

The review method comes from `code-review-expert`, so no external reviewer agent is required — any capable agent type works.

### 3. Verify & weigh each finding (ALWAYS — guards against hallucinated reviews)
Parallel agents will sometimes invent issues, misread the diff, cite the wrong line, flag intended behavior, or contradict each other. Before anything is consolidated, **contrast every finding against the actual code** and assign a verdict. Do not take an agent's word for it.

For each finding, check:
- **Grounded?** Open the cited `file:line` (Read / Serena) and confirm the offending code actually exists and says what the agent claims. If you can't locate it, **discard the finding.**
- **Correct?** Does the claimed cause-and-effect actually hold given the surrounding code, models, config, and project conventions? Re-derive it; don't trust the narrative.
- **In scope?** Is it introduced or touched by *this* PR (in the `origin/<base>...HEAD` diff), not pre-existing tech debt? Mark pre-existing issues as such or drop them.
- **Cross-agent agreement?** If two agents agree, confidence rises. If they conflict, resolve it by reading the code — pick the side the code supports.
- **Confidence:** keep the agent's self-reported confidence, but override it with your own after verification.

For anything non-obvious or high-impact (security, data loss, a claimed day-0 bug), **adversarially verify**: dispatch a fresh skeptic agent (or re-read yourself) whose job is to *refute* the finding. A finding that can't survive a refutation attempt gets downgraded or dropped.

Output of this step: a deduped list of findings, each tagged **confirmed / uncertain / discarded** with a one-line evidence note (the code you saw). Only **confirmed** (and explicitly-flagged uncertain) findings move on.

### 4. Consolidate
Merge the confirmed findings, dedupe overlaps, attribute briefly. Present as Blocking vs Nitpicking.

### 5. Severity-score & filter (ALWAYS — not optional)
Score each issue 0 (style nit) → 10 (day-0 bug). **Drop anything below 4** (the agreed default threshold). Map each surviving issue to the **exact file:line where the inline comment should land** — confirm line numbers by Reading the real files (diff line ≠ file line). Present the scored, filtered report to the user.

### 6. Confirm, then publish (ALWAYS ask first)
**Never publish without an explicit confirmation this turn.** After presenting the scored report, ask the user whether to publish — and say you'll use the **standard publish format** (see Defaults) unless they want something different. Only on a clear "yes" do you proceed to "Publishing" below.

## Publishing a review with inline comments

Get the metadata, then POST one review with all comments batched.

```bash
gh pr view <N> --json number,headRefOid,author,baseRefName
```
- `headRefOid` → `commit_id` in the payload.
- `author.login` → who to `@mention` (if asked).

Build a JSON payload (see `review-payload-template.json`) and post:
```bash
gh api repos/<owner>/<repo>/pulls/<N>/reviews --method POST --input payload.json
```

Each comment object: `path`, `line`, `side: "RIGHT"`, `body`.
`event` is one of `REQUEST_CHANGES` | `COMMENT` | `APPROVE`.

## Critical gotchas (learned the hard way)

- **The top-level `body` field must be present, but `""` works.** For `REQUEST_CHANGES`, `body: ""` is accepted (verified 2026-07-17 via `gh api`) — and it's the standard format: empty top-level body, everything in inline comments. Omitting the field entirely is what fails.
- **Comment `line` must be part of the diff** for that commit, or the API rejects it. Newly-added blocks are safe; for context lines pick an added/changed line nearby. If a finding lives in a file *outside* the diff (e.g. a bypass in another controller), anchor the comment on the diff line that ships the affected code and explain the cross-file path in the body.
- **Diff against the PR's real base.** `gh pr view --json baseRefName` — feature PRs sometimes target another feature branch, not develop/master. Findings and anchors must come from `origin/<baseRefName>...HEAD`, or you'll flag (and anchor on) code that isn't in the PR.
- **Confirm line numbers against the real file** with Read before posting — agents report approximate lines.
- **Multiple comments can target the same line** (e.g. two issues on one line) — just add two objects.
- **Lead format:** `@author` mention first, then a severity dot (🔴/🟠/🟡/🟢), then the finding. No numeric scores. Prefix lower-severity items with `[nitpicking]` if requested.
- **Each comment should explain:** what / why it happens / what it can cause / how to fix / alternatives. Keep that structure consistent.
- Verify success: response JSON has `"state": "CHANGES_REQUESTED"` (or `COMMENTED`).

## Comment body template

```
@<author>

🔴 **<Short title>**

**What:** <the problem, quoting the offending expression>
**Why it happens:** <root cause / why the code does this>
**What it can cause:** <concrete impact / failure mode>
**How to fix:**
```<lang>
<fix snippet>
```
**Alternatives:** <other valid approaches or "none needed">
```

Fill every slot in plain, easy-to-follow language (translate the labels if the user asked for another language, e.g. 問題/影響/修正案/代替案). No scores or confidence percentages in the body.

## Common mistakes

- Overlapping agent angles → duplicate findings. Keep each angle disjoint.
- Posting comments one-by-one instead of one batched review → noisy notifications.
- Omitting the top-level `body` field → API error. Send `body: ""` (the standard format), not no field at all.
- Putting scores/confidence in published comments → they belong in the chat report only.
- Diffing against develop/master when the PR's `baseRefName` is another branch → out-of-scope findings and rejected anchors.
- Trusting agent line numbers blindly → "line must be part of the diff" errors.
- Publishing without asking first → never do this; confirmation is mandatory every time.
- Skipping the 0–10 scoring/filter step → always score and drop <4, even when the user only said "review".
- Trusting agent findings verbatim → always verify against the real code first (step 3); agents hallucinate, misread lines, and flag intended behavior.
- Reporting pre-existing issues as PR problems → only flag what `origin/<base>...HEAD` actually introduces or touches.
