#!/usr/bin/env bash
# Print mutation candidates for the production lines this branch changed.
#
# Usage: scripts/mutation-points.sh [base-branch]
#   base defaults to the first of develop, master, main present on origin, else origin's default branch.
#
# The shared work lives here: find the base, list the changed production files, extract each file's
# changed line ranges, and hand "lineno<TAB>line" pairs to the language script picked by extension.
# Language knowledge lives in lang/<lang>.sh — a new language is one file there plus one case below.
#
# stdout: candidates, tab-separated  file:line  severity  label  original  mutant  (see lang/_common.sh)
# stderr: a one-line summary
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$(git rev-parse --show-toplevel)"

base=${1:-}
if [ -z "$base" ]; then
  base=$(for b in develop master main; do
    git rev-parse --verify --quiet "origin/$b" >/dev/null && echo "$b" && break
  done)
  [ -z "$base" ] && base=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
fi

# Not production code: tests, fixtures, vendored or generated output, migrations, config and data files.
skip='(^|/)(spec|test|tests|__tests__|__mocks__|fixtures?|features|node_modules|vendor|dist|build|target|coverage|db/migrate)/|(_spec|_test|\.test|\.spec|\.stories|\.config|\.d)\.[a-z]+$|(^|/)(schema\.rb|conftest\.py|setup\.py)$|\.(json|ya?ml|toml|lock|md|txt|csv|snap|min\.js)$'

files=0 candidates=0
while IFS= read -r file; do
  case "${file##*.}" in
    rb)                    lang=ruby ;;
    js|jsx|mjs|cjs|ts|tsx) lang=js ;;
    rs)                    lang=rust ;;
    py)                    lang=python ;;
    *) continue ;;
  esac

  # Changed line ranges in the new file, from zero-context hunk headers "@@ -a[,b] +c[,d] @@".
  ranges=$(git diff -U0 "origin/$base...HEAD" -- "$file" \
    | sed -nE 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+)(,([0-9]+))? @@.*/\2 \4/p' \
    | awk '{ n = ($2 == "") ? 1 : $2; if (n > 0) print $1 "-" $1 + n - 1 }')
  [ -n "$ranges" ] || continue
  files=$((files + 1))

  out=$(awk -v r="$ranges" '
    BEGIN { n = split(r, a, " "); for (i = 1; i <= n; i++) { split(a[i], b, "-"); lo[i] = b[1]; hi[i] = b[2] } }
    { for (i = 1; i <= n; i++) if (NR >= lo[i] && NR <= hi[i]) { print NR "\t" $0; next } }
  ' "$file" | "$here/lang/$lang.sh" "$file")
  [ -n "$out" ] || continue
  printf '%s\n' "$out"
  n=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  candidates=$((candidates + n))
  # Uncle Bob's module-size rule: past 50 mutation sites a module is doing too much — flag it, don't split it.
  [ "$n" -gt 50 ] && echo "mutation-points: $file has $n candidates — worth splitting before hardening" >&2
done < <(git diff --name-only --diff-filter=AMR "origin/$base...HEAD" | grep -Ev "$skip" || true)

echo "mutation-points: $candidates candidate(s) in $files changed production file(s), base origin/$base" >&2
