#!/usr/bin/env bash
# Acceptance harness for skills/mutation-test/scripts. Usage: run.sh [grep-filter]
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
FINDER="$ROOT/skills/mutation-test/scripts/mutation-points.sh"

fail() { echo "$*"; exit 1; }
assert_contains() { case "$1" in *"$2"*) ;; *) fail "${3:-assert_contains}: expected [$2] in [$1]";; esac; }
assert_not_contains() { case "$1" in *"$2"*) fail "${3:-assert_not_contains}: unexpected [$2] in [$1]";; esac; }
assert_exit() { [ "$CODE" = "$1" ] || fail "assert_exit: expected $1, got $CODE (err: $ERR)"; }

mktmp() { mktemp -d "$TEST_TMP/d.XXXXXX"; }

fixture() {
  local repo bare
  repo="$(mktmp)"; bare="$(mktmp)"
  (
    set -e
    git init -q --bare "$bare"
    git init -q -b main "$repo"
    cd "$repo"
    git config user.name "Test"; git config user.email "test@example.com"; git config commit.gpgsign false
    echo "# fixture" > README.md
    git add -A; git commit -q -m "initial"
    git remote add origin "$bare"; git push -q origin main
    git checkout -q -b feature
  ) >/dev/null 2>&1 || fail "fixture: setup failed"
  echo "$repo"
}

add_file() {
  local repo="$1" rel="$2" content="${3-}"
  mkdir -p "$repo/$(dirname "$rel")"
  if [ "$content" = "-" ]; then cat > "$repo/$rel"; else printf '%s\n' "$content" > "$repo/$rel"; fi
}

commit_all() { (cd "$1" && git add -A && git commit -q -m "${2:-change}") >/dev/null 2>&1 || fail "commit_all failed"; }

run_in() {
  local repo="$1"; shift
  OUT="$(mktmp)/out"; ERR="$(dirname "$OUT")/err"
  (cd "$repo" && "$@") >"$OUT" 2>"$ERR"
  CODE=$?
  OUT="$(cat "$OUT")"; ERR="$(cat "$ERR")"
}

passed=0; failed=0
filter="${1:-}"
for f in "$HERE"/t_*.sh; do [ -e "$f" ] && . "$f"; done

for name in $(declare -F | awk '{print $3}' | grep '^t_' | sort); do
  if [ -n "$filter" ] && ! echo "$name" | grep -q -- "$filter"; then continue; fi
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/mt-test.XXXXXX")"; export TEST_TMP
  res="$( ( "$name" ) 2>&1 )"; rc=$?
  rm -rf "$TEST_TMP"
  if [ $rc -eq 0 ]; then echo "PASS $name"; passed=$((passed+1))
  else echo "FAIL $name: $(printf '%s\n' "$res" | tail -n 1)"; failed=$((failed+1)); fi
done

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
