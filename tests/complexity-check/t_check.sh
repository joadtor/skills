# Tests for scripts/check.sh (dispatch, output, exit codes, skips)

# stub <dir> <lang> <body> — writes an executable lang script
stub() { mkdir -p "$1"; printf '#!/usr/bin/env bash\n%s\n' "$3" > "$1/$2.sh"; chmod +x "$1/$2.sh"; }
check() { local r="$1"; shift; COMPLEXITY_CHECK_LANG_DIR="$LD" run_in "$r" "$SCRIPTS/check.sh" "$@"; }

t_check_exit_codes() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/a.rb "x"; commit_all "$r"
  stub "$LD" ruby 'exit 0'
  check "$r"; assert_exit 0; assert_contains "$ERR" "complexity: clean"
  stub "$LD" ruby 'printf "app/a.rb:1\truby\tA#f\tcyclomatic\t11\t8\tskill default\n"; exit 1'
  check "$r"; assert_exit 1
  stub "$LD" ruby 'echo "rubocop not found" >&2; exit 3'
  check "$r"; assert_exit 0
}

t_check_missing_tool_skipped() {
  local r bin; r="$(fixture)"; LD="$(mktmp)"; bin="$(mktmp)"
  add_file "$r" cmd/main.go "x"; commit_all "$r"
  stub "$LD" go 'echo "gocyclo not found" >&2; exit 3'
  for c in curl npm gem go uv; do
    printf '#!/bin/sh\necho "$0 $*" >> "%s/calls"\n' "$bin" > "$bin/$c"; chmod +x "$bin/$c"
  done
  PATH="$bin:$PATH" check "$r"
  assert_exit 0
  assert_contains "$ERR" "skipped Go"
  assert_contains "$ERR" "run setup"
  assert_contains "$ERR" "cmd/main.go"
  [ ! -s "$bin/calls" ] || fail "check.sh invoked installer/network tools: $(cat "$bin/calls")"
}

t_check_offender_fields() {
  local r line; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/models/order.rb "x"; commit_all "$r"
  line="app/models/order.rb:42	ruby	Order#total	cyclomatic	11	8	skill default"
  stub "$LD" ruby "printf '%s\\n' '$line'; exit 1"
  check "$r"
  assert_eq "$OUT" "$line"
  assert_contains "$ERR" "complexity: 1 function(s) over the limit"
}

t_check_path_mode() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/a.rb "x"; add_file "$r" lib/b.rb "x"; commit_all "$r"
  (cd "$r" && git push -q origin feature:main) >/dev/null 2>&1
  stub "$LD" ruby 'echo "args: $*" >&2; exit 0'
  check "$r" app
  assert_contains "$ERR" "args: app/a.rb"
  assert_not_contains "$ERR" "lib/b.rb"
}

t_check_unsupported_language() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" cmd/main.go "x"; commit_all "$r"
  check "$r"
  assert_exit 0
  assert_contains "$ERR" "skipped Go (not supported)"
  assert_contains "$ERR" "1 language(s) skipped"
}

t_check_groups_by_language() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/a.rb "x"; add_file "$r" web/b.ts "x"; commit_all "$r"
  stub "$LD" ruby 'echo "ruby: $*" >&2'
  stub "$LD" js 'echo "js: $*" >&2'
  check "$r"
  assert_contains "$ERR" "ruby: app/a.rb"
  assert_not_contains "$ERR" "ruby: app/a.rb web"
  assert_contains "$ERR" "js: web/b.ts"
  assert_not_contains "$ERR" "js: app/a.rb"
}

t_check_several_paths() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/a.rb "x"; add_file "$r" lib/b.rb "x"; add_file "$r" other/c.rb "x"; commit_all "$r"
  stub "$LD" ruby 'echo "args: $*" >&2; exit 0'
  check "$r" app/a.rb lib
  assert_contains "$ERR" "args: app/a.rb lib/b.rb"
  assert_not_contains "$ERR" "other/c.rb"
}
