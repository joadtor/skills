---
name: pr-changelog
description: Use when the user asks for a change list, changelog, or summary intended for a PR description - produces brief, non-technical bullets focused on user-facing changes rather than files, methods, or implementation details
---

# Writing Simple PR Changelogs

## Overview

When generating a change list for a PR description, write for the reviewer reading the PR body — not for yourself. Describe what changed from a product or user perspective, not how it was implemented.

## When to Use

- User says "change list", "changelog", "PR description", "PR summary"
- User says "for the PR", "brief", "simple", "less technical"
- User wants something they can paste into a PR body

Do NOT use for: internal code reviews, commit messages, or technical deep-dives where implementation detail matters.

## Rules

1. **No file paths.** Never mention `src/foo/bar.js` or similar.
2. **No code identifiers.** Avoid method, class, constant, or variable names (no backticks around symbols).
3. **Product language, not mechanism.** Say what the feature does, not how it was built.
4. **3–6 bullets max.** One sentence each.
5. **Group tests into one line** ("Added tests covering the new behavior").
6. **Lead each bullet with a verb** describing user-visible behavior (Added / Enabled / Routed / Reused). `Reused`/`Routed` are fine when they name a user-visible thing — a screen, a flow — not a code construct: "Reused the QR scan screen," never "Reused the base component."

## Quick Reference

| Too technical | Simple |
|---|---|
| Extended `Meeting.checkInParam` to accept `qrToken` | Added QR token support to meeting check-in |
| Added `qrMeetingCheckinMode` to resource record | Added a new device setting for QR check-in |
| Generalized `NameQrScan` with `flowType` prop | Reused the QR scan screen for both flows |
| Updated Redux saga to dispatch new action | Check-in now flows through the QR scan screen when enabled |

## Format

If the PR body already follows a format (an existing template or an established section structure), match that format. Otherwise, default to a `## Changes` section:

```markdown
## Changes
- <feature or capability, user-facing>
- <setting or toggle, in plain language>
- <behavior or reuse, described by effect>
- <tests, if added — one line>
```

## Red Flags — Rewrite if you see these

- Backticks around symbols (`` `foo` ``, `` `Bar.baz()` ``)
- File extensions (`.js`, `.tsx`, `.rb`)
- Words like "extended", "refactored", "generalized", "extracted", "dispatched", "extended the record"
- Internal module or layer names the reviewer might not recognize
- More than 6 bullets
- Any bullet longer than one sentence

## Common Mistakes

- Listing every file that changed → list features, not files
- Mentioning Redux / sagas / reducers / records → describe the effect instead
- Including implementation reasoning → the PR diff already shows that
- Repeating the ticket title verbatim → add information the title doesn't convey
