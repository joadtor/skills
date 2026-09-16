---
name: spec-draft
description: Use when a settled design or agreed behavior should be captured as an executable Gherkin spec (a .feature file).
---

# Spec Draft

## Overview

Turn a settled design into one clean, runnable Gherkin `.feature` file: the agreed behavior as scenarios, the design and its rejected alternatives in the feature's narrative. The result is a spec you can hand straight to Cucumber — or to TDD.

**Core principle:** One idiomatic `.feature` file — nothing non-Gherkin bolted on.

## When to Use

- A design is settled and you want an executable acceptance spec
- Called at the end of `context-pumping-spec`, or standalone from any agreed design

Only draft a spec for a design that is actually settled — don't spec open questions.

## Output

Write to `docs/specs/YYYY-MM-DD-<topic>.feature` (create `docs/specs/` if it doesn't exist).

```gherkin
Feature: <what we're building>
  # The settled approach in a few lines, plus the key decisions the design
  # landed on and the alternatives it rejected (and why). This narrative is
  # Gherkin's own free-text slot — the rationale lives here, not in a
  # separate markdown section.

  Scenario: <a concrete behavior>
    Given <context>
    When <action>
    Then <outcome>
```

## Using the language

Use the whole of Gherkin where it earns its place — but YAGNI, not every construct for show. Full syntax in `gherkin-reference.md`.

- **Feature narrative** — the design + rejected options. Always present.
- **Scenario** / **Scenario Outline** + **Examples** — one behavior each; use an Outline when the same behavior repeats over data.
- **Background** — shared `Given` steps, only when scenarios genuinely repeat setup.
- **Rule** — group scenarios under a business rule when there is more than one rule.
- **Data Tables** / **Doc Strings** — structured or multiline step arguments.
- **Tags** (`@`) — mark scenarios (e.g. `@wip`, area tags) when it helps.

## Rules

- Plain, concrete steps — name the real behavior, not the implementation.
- Each scenario independent and readable on its own.
- Don't invent behavior the design didn't settle — spec what was agreed, nothing more.

## Common Mistakes

- Bolting on `## Design` / `## Decisions` markdown sections → put them in the `Feature:` narrative; keep it a valid `.feature`.
- Every Gherkin construct for show → YAGNI; use what the spec needs.
- Speccing implementation detail instead of behavior → Given/When/Then describe behavior.
