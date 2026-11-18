#!/usr/bin/env bash
# Acceptance harness for skills/complexity-check. Usage: run.sh [grep-filter]
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="$ROOT/skills/complexity-check/scripts"
FIXTURES="$HERE/fixtures"
TEST_CACHE="${COMPLEXITY_CHECK_TEST_CACHE:-${TMPDIR:-/tmp}/complexity-check-test-cache}"
export SCRIPTS FIXTURES TEST_CACHE

fail() { echo "$*"; exit 1; }
skip() { echo "$*"; exit 77; }
skip_unless_cmd() { command -v "$1" >/dev/null 2>&1 || skip "missing command: $1"; }
need_net() { [ "${COMPLEXITY_CHECK_NET_TESTS:-}" = "1" ] || skip "set COMPLEXITY_CHECK_NET_TESTS=1 to run network tests"; }

assert_contains() {
  case "$1" in *"$2"*) ;; *) fail "${3:-assert_contains}: expected to contain [$2] in [$1]";; esac
}
assert_not_contains() {
  case "$1" in *"$2"*) fail "${3:-assert_not_contains}: expected NOT to contain [$2] in [$1]";; esac
}
assert_eq() {
  [ "$1" = "$2" ] || fail "${3:-assert_eq}: expected [$2], got [$1]"
}
assert_exit() {
  [ "$CODE" = "$1" ] || fail "assert_exit: expected exit $1, got $CODE"
}

mktmp() { mktemp -d "$TEST_TMP/d.XXXXXX"; }

fixture() {
  local repo bare
  repo="$(mktmp)"; bare="$(mktmp)"
  (
    set -e
    git init -q --bare "$bare"
    git init -q -b main "$repo"
    cd "$repo"
    git config user.name "Test"
    git config user.email "test@example.com"
    git config commit.gpgsign false
    echo "# fixture" > README.md
    git add -A
    git commit -q -m "initial"
    git remote add origin "$bare"
    git push -q origin main
    git checkout -q -b feature
  ) >/dev/null 2>&1 || fail "fixture: setup failed"
  echo "$repo"
}

add_file() {
  local repo="$1" rel="$2" content="${3-}"
  mkdir -p "$repo/$(dirname "$rel")"
  if [ "$content" = "-" ]; then cat > "$repo/$rel"; else printf '%s\n' "$content" > "$repo/$rel"; fi
}

commit_all() {
  (cd "$1" && git add -A && git commit -q -m "${2:-change}") >/dev/null 2>&1 || fail "commit_all failed"
}

copy_fixture() {
  local repo="$1" src="$2" dest="${3:-$2}"
  mkdir -p "$repo/$(dirname "$dest")"
  cp "$FIXTURES/$src" "$repo/$dest" || fail "copy_fixture: $src"
}

run_in() {
  local repo="$1"; shift
  OUT="$(mktmp)/out"; ERR="$(dirname "$OUT")/err"
  (cd "$repo" && "$@") >"$OUT" 2>"$ERR"
  CODE=$?
  OUT="$(cat "$OUT")"; ERR="$(cat "$ERR")"
}

passed=0; failed=0; skipped=0
filter="${1:-}"

for f in "$HERE"/t_*.sh; do
  [ -e "$f" ] && . "$f"
done

for name in $(declare -F | awk '{print $3}' | grep '^t_' | sort); do
  if [ -n "$filter" ] && ! echo "$name" | grep -q -- "$filter"; then continue; fi
  TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/cc-test.XXXXXX")"; export TEST_TMP
  res="$( ( "$name" ) 2>&1 )"; rc=$?
  rm -rf "$TEST_TMP"
  reason="$(printf '%s\n' "$res" | tail -n 1)"
  case $rc in
    0)  echo "PASS $name"; passed=$((passed+1));;
    77) echo "SKIP $name: $reason"; skipped=$((skipped+1));;
    *)  echo "FAIL $name: $reason"; failed=$((failed+1));;
  esac
done

echo "$passed passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
