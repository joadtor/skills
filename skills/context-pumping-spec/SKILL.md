---
name: context-pumping-spec
description: Use when a rough idea or plan should be taken all the way to an executable Gherkin spec in one go.
---

# Context Pumping to Spec

## Overview

The full path from idea to executable spec: run the improve-in-a-loop interview, then write the agreed design out as a Gherkin `.feature`.

## Steps

1. **Run `context-pumping-loop`** — interrogate and innovate until the design is settled and the user approves it.
2. **Then run `spec-draft`** — write the approved design to `docs/specs/YYYY-MM-DD-<topic>.feature`.

Don't draft the spec until the loop's approval gate has passed — spec the design the user said yes to, nothing earlier.
