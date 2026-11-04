# complexity-check reference

## Limits

A function fails when its score is **over** the limit; at the limit it passes.

| Language | Tool | Metric | Default | Why this number |
|---|---|---|---|---|
| Ruby | rubocop | cyclomatic + perceived | 8 | RuboCop's cyclomatic count adds 1 per iterator block (`map`, `each`), which inflates Ruby against other languages; 8 is one above its cyclomatic default (7) and equal to its perceived default |
| JS/TS | eslint `complexity` (classic) | cyclomatic | 10 | McCabe/NIST's 10, the value most tools settle on; ESLint's own default of 20 is an outlier |
| Python | radon | cyclomatic | 10 | ruff/mccabe default |
| Go | gocyclo | cyclomatic | 10 | golangci-lint's `cyclop` default, the low end of its "10–20" recommendation |
| Rust | clippy `cognitive_complexity` | cognitive | 15 | SonarSource's cognitive default; Clippy's own 25 is a restriction-lint default |

**Precedence:** a limit the project sets explicitly wins, and the report names it (`source` column):

| Language | Read from |
|---|---|
| Ruby | `.rubocop.yml` `Max` per cop — a disabled cop (`Metrics: Enabled: false`, as in rails-omakase, Shopify, standardrb) carries no number, so the skill default applies |
| JS/TS | the project's ESLint config, `rules.complexity` (off → skill default) |
| Python | `[tool.ruff.lint.mccabe] max-complexity` (pyproject / ruff.toml), else `[flake8] max-complexity` (setup.cfg, .flake8, tox.ini) |
| Go | `.golangci.yml` `gocyclo.min-complexity` (v1 or v2 layout) |
| Rust | `clippy.toml` `cognitive-complexity-threshold` |

Otherwise the skill default applies (`source = skill default`).

## Trust

The check honors the project's own lint configuration — its limits, plugins, and exclusions — so it runs the code those configs contain: ERB in `.rubocop.yml` (also when inherited into the cached rubocop's temporary config), `eslint.config.js`, cargo build scripts and proc-macros. That is the same trust as running the project's test suite, which the refactor loop does anyway. Only check repos you'd run the tests of. What the check itself never does: evaluate a config value as shell, import a module from the repo into its own helpers, or download anything.

## Tools and where they come from

`check.sh` runs the project's own tool first (`bundle exec rubocop`, `node_modules/.bin/eslint`), then one on the `PATH`, then the cache `~/.cache/joadtor/complexity-check/bin/`. When a project's `.rubocop.yml` can't load (a plugin gem isn't installed for the rubocop being used), the check bypasses it with a temporary config holding only the limits, and says so. A remote `inherit_from: http(s)://…` is bypassed the same way up front — the check never downloads.

A project without its own ESLint is still covered for TypeScript: the check writes a throwaway flat config in a temp dir that imports `typescript-eslint`'s parser from the cache by absolute `file://` path, and runs the cached eslint with `-c` on it from the project root — the project gets no config file and no dependency.

`setup.sh install` — exact pins, installed from the cache directory so nothing in the project influences them:

| Tool | Method | Needs |
|---|---|---|
| rubocop | `gem install --remote --install-dir` + wrapper | Ruby ≥ 2.7 |
| eslint (+ typescript-eslint, typescript) | `npm install --prefix`, `--ignore-scripts`, explicit registry | npm |
| radon | `uv tool install --no-config` | uv |
| gocyclo | `go install …@v0.6.0` | go |
| clippy | `rustup component add clippy` — **changes the user's Rust toolchain**, not the cache | rustup |

## Refactor playbook

Work through these in order; stop as soon as the function fits.

1. **Guard clauses** — replace nested conditionals with early returns for the special cases.
2. **Decompose conditional** — move a complex condition, or each branch's body, into a well-named function.
3. **Consolidate conditional** — merge branches that produce the same result into one condition.
4. **Extract function** — pull a coherent piece out — one that has its own name and does one thing.
5. **Lookup table or polymorphism** — a long `case`/`if-elsif` dispatching on a value becomes a hash/map, or one class per variant.

**Don't shuffle.** If the extracted helper carries the same branches the original had, the total didn't go down — the complexity just moved. AI refactors measurably do this: they shrink method length while cyclomatic complexity stays or rises.

**Behavior must not change.** The full suite runs after every round. LLM refactors silently changed behavior in about 7% of cases in one study (22 of 313) — the tests are the only proof they didn't here.

**A single flat `case`/`switch`** that maps inputs to outputs is the one shape NIST says may reasonably be exempted. It's a candidate for the *exempt* recommendation after round 3 — still the user's call.

## Reasoned exemptions (only when the user chose it)

```ruby
def dispatch(event) # rubocop:disable Metrics/CyclomaticComplexity -- flat dispatch over 12 event types
```

```js
// eslint-disable-next-line complexity -- flat dispatch over 12 event types
function dispatch(event) {
```

Python (`# noqa: C901 -- <reason>`), Go (`//nolint:gocyclo // <reason>`), Rust (`#[allow(clippy::cognitive_complexity)] // <reason>`) follow the same rule: the reason is mandatory.
