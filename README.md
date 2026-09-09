# skills

Personal collection of [Agent Skills](https://agentskills.io) by Jose Luis Adelantado Torres.

Each skill is authored to the Agent Skills open standard (`SKILL.md`), so it is portable
across Claude Code, Codex, Cursor, Gemini CLI, and other compliant tools. This repo also
doubles as a Claude Code plugin + marketplace.

## Structure

```
.claude-plugin/
  plugin.json         # Claude Code plugin manifest
  marketplace.json    # Marketplace manifest (lists this plugin)
skills/
  <skill-name>/
    SKILL.md          # one folder + SKILL.md per skill
```

## Install

Replace `<owner>` with the GitHub path this repo is pushed to.

**With `npx skills`** (cross-tool):

```bash
npx skills add <owner>/skills            # all skills
npx skills add <owner>/skills --list     # list, then pick with --skill
```

**Native Claude Code plugin:**

```
/plugin marketplace add <owner>/skills
/plugin install skills@skills
```

## Adding a skill

1. Create `skills/<skill-name>/SKILL.md`.
2. Frontmatter requires `name` (must match the folder; lowercase, digits, hyphens) and
   `description` (what it does **and** when to use it).

```markdown
---
name: my-skill
description: Use when <specific triggering conditions and symptoms>.
---

# My Skill

...
```

See the [specification](https://agentskills.io/specification) for the full format.
