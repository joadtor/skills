# Agent Skills

A personal collection of [Agent Skills](https://agentskills.io) by Jose Luis Adelantado Torres —
small, portable `SKILL.md` capabilities that work in Claude Code and any Agent-Skills-compliant
tool (Codex, Cursor, Gemini CLI). The repo also doubles as a Claude Code plugin + marketplace.

Most of these chain into one spec-driven, test-first workflow — based on Uncle Bob's
(Robert C. Martin): shape the idea, pin it to an executable spec, plan it, build it test-first,
then review and prove the tests bite.

## Skills

**Shape & specify**
- **context-pumping** — surface the hidden assumptions, gaps, and open decisions in a plan or idea
- **context-pumping-loop** — push a design to something stronger, not just clearer
- **context-pumping-spec** — take a rough idea straight to an executable Gherkin spec
- **spec-draft** — capture a settled behavior as a Gherkin `.feature` file

**Plan & build**
- **plan-draft** — turn a design + spec into a concrete, test-first execution plan
- **plan-execute** — run the plan: parallelize independent tasks, gate each on tests/lint/complexity, commit per task
- **plan-execute-tdd** — the same executor under the TDD iron law: a failing test before any production code

**Review & verify**
- **code-review-expert** — confidence-gated review of a diff or branch for real bugs, security, and quality issues
- **pr-review** — multi-agent PR review; split blocking vs nitpick and publish inline via `gh`
- **mutation-test** — plant one bug at a time to prove the tests actually bite
- **pr-changelog** — brief, user-facing changelog bullets for a PR description

**Research**
- **deep-research** — synthesize multiple web sources into a single cited report

## Install

```bash
# Any Agent-Skills tool
npx skills add joadtor/skills

# Claude Code plugin
/plugin marketplace add joadtor/skills
/plugin install skills@skills
```

## Layout

```
.claude-plugin/
  plugin.json        # Claude Code plugin manifest
  marketplace.json   # marketplace manifest
skills/
  <skill-name>/SKILL.md
```

To add a skill, create `skills/<name>/SKILL.md` with frontmatter `name` (matching the folder) and
`description` (what it does **and** when to use it). See the [specification](https://agentskills.io/specification).
