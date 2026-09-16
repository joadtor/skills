#!/usr/bin/env bash
# Complexity gate — the refactor step's numeric exit. Lists changed production functions over MAX.
#
# Usage: MAX=8 scripts/complexity.sh [base-branch]
#   Checks the working tree — committed or not — against the merge-base with origin/<base>;
#   base defaults to develop, master, main (first present on origin), else origin's default branch.
#   MAX (default 8) is the per-function ceiling: Uncle Bob's CRAP limit at full coverage.
#
# Uses the project's own tools; installs nothing, edits no config:
#   Ruby    rubocop --only Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity  (.rubocop.yml's Max wins; rubocop's default is 7)
#   JS/TS   eslint --rule "complexity: [error, MAX]" on top of the project's config    (node_modules/.bin/eslint, else npx --no-install)
#   Python  radon cc, keeping functions and methods with complexity > MAX
#   Rust    cargo clippy -W clippy::cognitive_complexity, MAX via a temporary clippy.toml unless the project has its own, filtered to the changed files
#
# Fail-safe: a language whose tool is missing, or fails to run, is SKIPPED — reported on stderr with the
# unchecked files named — and never blocks. STRICT=1 turns a skip into exit 2.
#
# stdout: one line per offending function — file:line  message.  stderr: summary.
# Exit 0 clean for what was measured · 1 something is over the limit · 2 a language was skipped and STRICT=1.
set -o pipefail
cd "$(git rev-parse --show-toplevel)"
MAX=${MAX:-8}
STRICT=${STRICT:-0}

base=${1:-}
if [ -z "$base" ]; then
  base=$(for b in develop master main; do
    git rev-parse --verify --quiet "origin/$b" >/dev/null && echo "$b" && break
  done)
  [ -z "$base" ] && base=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
fi

# Not production code: tests, fixtures, vendored or generated output, migrations, config and data files.
skip='(^|/)(spec|test|tests|__tests__|__mocks__|fixtures?|features|node_modules|vendor|dist|build|target|coverage|db/migrate)/|(_spec|_test|\.test|\.spec|\.stories|\.config|\.d)\.[a-z]+$|(^|/)(schema\.rb|conftest\.py|setup\.py)$|\.(json|ya?ml|toml|lock|md|txt|csv|snap|min\.js)$'

merge_base=$(git merge-base "origin/$base" HEAD)
rb=() js=() py=() rs=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  case "${f##*.}" in
    rb)                    rb+=("$f") ;;
    js|jsx|mjs|cjs|ts|tsx) js+=("$f") ;;
    py)                    py+=("$f") ;;
    rs)                    rs+=("$f") ;;
  esac
done < <({ git diff --name-only --diff-filter=AMR "$merge_base"; git ls-files --others --exclude-standard; } | grep -Ev "$skip" | sort -u)

over=0 skipped=0
hit()     { over=$((over + 1)); printf '%s\n' "$1"; }
hits()    { while IFS= read -r l; do [ -n "$l" ] && hit "$l"; done; }
skipped() { skipped=$((skipped + 1)); echo "complexity: skipped $1 ($2) — unchecked: $3" >&2; }

if [ ${#rb[@]} -gt 0 ]; then
  run=rubocop
  grep -q ' rubocop (' Gemfile.lock 2>/dev/null && run="bundle exec rubocop"
  if ! $run --version >/dev/null 2>&1; then
    skipped Ruby "rubocop not available" "${rb[*]}"
  else
    out=$($run --only Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity --format emacs "${rb[@]}" 2>&1); status=$?
    if [ $status -ge 2 ]; then          # rubocop: 0 clean, 1 offenses, 2+ error
      skipped Ruby "rubocop failed, exit $status" "${rb[*]}"
    else
      hits < <(printf '%s\n' "$out" | grep 'Metrics/' | sed -E "s#^$PWD/##; s/:[0-9]+: [A-Z]: Metrics\/[A-Za-z]+: /  /")
    fi
  fi
fi

if [ ${#js[@]} -gt 0 ]; then
  run=""
  if [ -x node_modules/.bin/eslint ]; then run=node_modules/.bin/eslint
  elif npx --no-install eslint --version >/dev/null 2>&1; then run="npx --no-install eslint"; fi
  if [ -z "$run" ]; then
    skipped JS/TS "eslint not available" "${js[*]}"
  else
    out=$($run --rule "complexity: [error, $MAX]" --format unix "${js[@]}" 2>&1); status=$?
    if [ $status -ge 2 ]; then          # eslint: 0 clean, 1 lint errors, 2+ fatal (config, parser…)
      skipped JS/TS "eslint failed, exit $status" "${js[*]}"
    else
      hits < <(printf '%s\n' "$out" | grep '\[Error/complexity\]' | sed -E 's/:[0-9]+: /  /; s/ \[Error\/complexity\]$//')
    fi
  fi
fi

if [ ${#py[@]} -gt 0 ]; then
  run=""
  if command -v radon >/dev/null 2>&1; then run=radon
  elif python3 -c 'import radon' 2>/dev/null; then run="python3 -m radon"; fi
  if [ -z "$run" ]; then
    skipped Python "radon not available, pip install radon" "${py[*]}"
  else
    out=$($run cc -j "${py[@]}" 2>/dev/null); status=$?
    if [ $status -ne 0 ]; then
      skipped Python "radon failed, exit $status" "${py[*]}"
    else
      hits < <(printf '%s\n' "$out" | python3 -c '
import json, sys
max_ = int(sys.argv[1])
def walk(f, blocks):
    for b in blocks:
        if b.get("complexity", 0) > max_:
            print(f"{f}:{b[\"lineno\"]}  {b[\"type\"]} {b[\"name\"]} has a complexity of {b[\"complexity\"]}. Maximum allowed is {max_}.")
        walk(f, b.get("methods", []))
for f, blocks in json.load(sys.stdin).items():
    walk(f, blocks if isinstance(blocks, list) else [])
' "$MAX")
    fi
  fi
fi

if [ ${#rs[@]} -gt 0 ]; then
  if [ ! -f Cargo.toml ] || ! cargo clippy --version >/dev/null 2>&1; then
    skipped Rust "Cargo.toml or cargo clippy not available" "${rs[*]}"
  else
    conf=""
    if [ ! -f clippy.toml ] && [ ! -f .clippy.toml ]; then
      conf=$(mktemp -d) && printf 'cognitive-complexity-threshold = %s\n' "$MAX" > "$conf/clippy.toml"
    fi
    out=$(CLIPPY_CONF_DIR="${conf:-$PWD}" cargo clippy --quiet --message-format=short -- -W clippy::cognitive_complexity 2>&1); status=$?
    [ -n "$conf" ] && rm -rf "$conf"
    if [ $status -ne 0 ]; then          # warnings exit 0; a compile error exits non-zero
      skipped Rust "cargo clippy failed, exit $status" "${rs[*]}"
    else
      hits < <(printf '%s\n' "$out" | grep 'cognitive complexity' | grep -F -f <(printf '%s\n' "${rs[@]}") | sed -E 's/:[0-9]+: warning: /  /')
    fi
  fi
fi

[ $over -gt 0 ] && echo "complexity: $over function(s) over $MAX — refactor until clean" >&2
if [ $skipped -gt 0 ]; then
  echo "complexity: $skipped language(s) skipped — the files above were not measured (STRICT=1 makes this fail)" >&2
  [ "$STRICT" = 1 ] && exit 2
fi
[ $over -gt 0 ] && exit 1
[ $skipped -gt 0 ] && echo "complexity: clean for what was measured (max $MAX, base origin/$base)" >&2 \
                   || echo "complexity: clean (max $MAX, base origin/$base)" >&2
exit 0
