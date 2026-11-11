# complexity-check reference

## The metric

**Cognitive complexity** (SonarSource's algorithm): +1 for each break in the flow (`if`, loop, `catch`, a sequence of `&&`/`||`, recursion), **plus one more per level of nesting**; a whole `switch` counts once. It measures how hard a function is to *read*, so deep nesting costs most and a flat dispatch costs little.

A function fails when its score is **over** the limit; at the limit it passes.

## Limits and tools

The project's own cognitive tool wins when it is **configured** — installed and enabled for cognitive complexity, not merely installed. Its limit wins too, and the report names where it came from (`source` column). Otherwise lizard measures, at the skill default.

| Language | Project's own tool, when configured | Limit read from | Default | Otherwise |
|---|---|---|---|---|
| Ruby | — (none exists) | — | 15 | the skill's Ruby scorer (needs `ruby`; never lizard) |
| JS/TS | ESLint with `sonarjs/cognitive-complexity` on, or Biome with `complexity/noExcessiveCognitiveComplexity` on | the rule's option / `maxAllowedComplexity` in `biome.json` | 15 | lizard |
| Python | complexipy, with `[tool.complexipy]` in `pyproject.toml` | `max-complexity-allowed` | 15 | lizard |
| Go | gocognit through golangci-lint (`.golangci.yml` enables it), or a `gocognit` on the PATH | `gocognit.min-complexity` | 15 | lizard |
| Rust | clippy's `cognitive_complexity`, when `clippy.toml` sets a threshold or `Cargo.toml`'s `[lints.clippy]` enables it | `cognitive-complexity-threshold` | 15 | lizard |

**Why 15:** SonarSource's default, and also sonarjs's, Biome's and complexipy's. **Why lizard:** one tool for every language; on the same functions it scored exactly what gocognit, complexipy and sonarjs score (10/10/10 flat, 15/15/15 and 11/11 nested). **Why not lizard for Ruby:** its Ruby parser ignores nesting (a nested method scored 4–5 where the same shape scores 11 elsewhere). Ruby gets the skill's own scorer instead: SonarSource's rules over Ruby's built-in parser (Ripper) — it parses, never runs, and needs nothing beyond Ruby. Two Ruby notes: a block (`each do`) raises nesting but isn't a loop, so a body under `items.each do` scores one less than under `for`; and `x rescue y` counts like a `rescue`. A `define_method(:name)` / `define_singleton_method(:name)` block is scored as its own method; other class- or top-level blocks (Sinatra routes, `scope -> {}`, `validate do`) are not measured. Clippy is used only when the project configures it — its "cognitive" score drifts from SonarSource's (16 where the others score 20), and its own docs say the lint doesn't measure what its name says.

The Ruby 3 pattern-match guard (`in X if cond`) is scored as a modifier `if` at the clause's nesting — a design choice; no reference tool covers it. A project's own tool may count differently from the whitepaper (sonarjs, for one, charges neither `||` runs nor recursion): its numbers are the project's.

A project tool that is configured but not installed (no `node_modules`, no venv) is never installed by the skill: `setup.sh plan` notes it, and lizard measures that language until the project's dependencies are installed.

## Trust and staying local

- **The Ruby scorer** only parses: it runs from a temp dir with gems and `RUBYOPT` disabled, reads each file's text, and never loads or runs it — a shebang's switches never apply.
- **lizard** only reads source text. It runs from a temp dir with a scrubbed Python environment, writes nothing into the project (ignored files included), loads nothing from it, and makes no network call. A test proves each of these.
- **A project's own tool** runs with the project's own config, as it would in the project's CI — ESLint loads `eslint.config.js`, cargo compiles `build.rs` and proc-macros. That's the same trust as running the project's tests, which the refactor loop does anyway. golangci-lint is the exception: it always runs from a generated config holding only gocognit and the project's numeric limit, because a `.golangci.yml` can load plugins.
- **A repo-local tool binary** (`node_modules/.bin`, `.venv/bin`) is used only under a gitignored directory, with no committed part in its path — a committed binary or symlink was planted.
- **Nothing leaves the machine while checking.** `check.sh` installs nothing and is tested with outbound network blocked by the OS. The only network use is `setup.sh install lizard`, after the user agrees: it downloads the pinned package; no code or result is sent.

## Unparsable files

A Ruby file the scorer can't parse is reported **unchecked**, never clean. lizard reports nothing for a file it can't parse; for Python and Go the check cross-checks such a file with the language's own read-only syntax check and reports it unchecked too. A project's own tool (ESLint, Biome, complexipy, golangci-lint, gocognit) that can't parse a file is reported unchecked as well, and so is a JS/TS file the project's ESLint config doesn't cover. For lizard on JS/TS and Rust no cheap checker exists, so a broken file there reads as having no functions — fix syntax errors first.

## Refactor playbook

Cognitive complexity is driven by nesting, so flatten first. Work through these in order; stop as soon as the function fits.

1. **Guard clauses** — turn nested conditionals into early returns for the special cases. This removes nesting levels, which is where most of the score comes from.
2. **Extract the nested block** — pull the innermost loop or branch into a well-named function; its nesting no longer counts against the caller.
3. **Decompose conditional** — move a complex condition into a named predicate.
4. **Consolidate conditional** — merge branches that produce the same result.
5. **Lookup table or polymorphism** — a long `if/elsif` dispatching on a value becomes a hash/map, or one class per variant.

**Don't shuffle.** If the extracted helper carries the same nested branches, the total didn't go down — it just moved. AI refactors measurably do this: they shrink method length while the branching stays.

**Behavior must not change.** The full suite runs after every round. LLM refactors silently changed behavior in about 7% of cases in one study (22 of 313) — the tests are the only proof they didn't here.

**A single flat `case`/`switch`** that maps inputs to outputs scores low in cognitive terms already; if one is still over, it's a candidate for the *exempt* recommendation after round 3 — still the user's call.

## Reasoned exemptions (only when the user chose it)

The reason is mandatory. Use the form for whichever tool measured the function (the `source` column tells you):

| Tool | Exemption |
|---|---|
| lizard | `// #lizard forgives -- <reason>` (or `# #lizard forgives -- <reason>`) as the first line inside the function |
| Ruby scorer | none yet — record the user's decision in the report; the function stays listed |
| ESLint + sonarjs | `// eslint-disable-next-line sonarjs/cognitive-complexity -- <reason>` |
| Biome | `// biome-ignore lint/complexity/noExcessiveCognitiveComplexity: <reason>` |
| golangci-lint (gocognit) | `//nolint:gocognit // <reason>` |
| clippy | `#[allow(clippy::cognitive_complexity)] // <reason>` |
| complexipy | see complexipy's docs for its ignore comment; state the reason beside it |
