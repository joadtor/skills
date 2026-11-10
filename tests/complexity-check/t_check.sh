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

t_check_no_base_branch_is_an_error() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  (cd "$r" && git remote remove origin) >/dev/null 2>&1
  add_file "$r" app/a.rb "x"; commit_all "$r"
  stub "$LD" ruby 'printf "app/a.rb:1\truby\tA#f\tcyclomatic\t11\t8\tskill default\n"; exit 1'
  check "$r"
  assert_exit 2
  assert_contains "$ERR" "complexity: can't find the base branch on origin — pass a path or fetch origin"
  assert_not_contains "$ERR" "complexity: clean"
}

t_check_relative_paths_from_subdirectory() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/c.rb "x"; add_file "$r" c.rb "x"; add_file "$r" lib/b.rb "x"; commit_all "$r"
  stub "$LD" ruby 'echo "args: $*" >&2; exit 0'
  COMPLEXITY_CHECK_LANG_DIR="$LD" run_in "$r/app" "$SCRIPTS/check.sh" c.rb
  assert_contains "$ERR" "args: app/c.rb"
  COMPLEXITY_CHECK_LANG_DIR="$LD" run_in "$r/app" "$SCRIPTS/check.sh" .
  assert_contains "$ERR" "args: app/c.rb"
  assert_not_contains "$ERR" "lib/b.rb"
  COMPLEXITY_CHECK_LANG_DIR="$LD" run_in "$r/app" "$SCRIPTS/check.sh" "$(cd "$r" && pwd -P)/lib/b.rb"
  assert_contains "$ERR" "args: lib/b.rb"
}

t_check_falls_back_to_lizard() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" cmd/a.go "x"; add_file "$r" cmd/b.go "x"; add_file "$r" app/c.rb "x"; commit_all "$r"
  stub "$LD" go 'exit 4'
  stub "$LD" ruby 'exit 0'
  stub "$LD" lizard 'echo "lizard: $*" >&2; exit 0'
  check "$r"
  assert_exit 0
  assert_contains "$ERR" "lizard: cmd/a.go cmd/b.go"
  assert_not_contains "$ERR" "c.rb"
  assert_not_contains "$ERR" "skipped"
}

t_check_own_tool_skips_lizard() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" cmd/a.go "x"; commit_all "$r"
  stub "$LD" go 'exit 0'
  stub "$LD" lizard "echo called > \"$LD/lizard-called\"; exit 0"
  check "$r"
  assert_exit 0
  [ ! -e "$LD/lizard-called" ] || fail "lizard.sh ran although go.sh found its own tool"
}

t_check_no_lang_script_uses_lizard() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/a.rb "x"; add_file "$r" app/b.rb "x"; commit_all "$r"
  stub "$LD" lizard 'echo "lizard: $*" >&2; exit 0'
  check "$r"
  assert_exit 0
  assert_contains "$ERR" "lizard: app/a.rb app/b.rb"
  assert_not_contains "$ERR" "skipped"
}

t_check_lizard_offenders_pass_through() {
  local r line; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" cmd/a.go "x"; commit_all "$r"
  line="cmd/a.go:3	go	main	cognitive	16	15	skill default"
  stub "$LD" go 'exit 4'
  stub "$LD" lizard "printf '%s\\n' '$line'; exit 1"
  check "$r"
  assert_exit 1
  assert_eq "$OUT" "$line"
  assert_contains "$ERR" "complexity: 1 function(s) over the limit"
}

t_check_lizard_missing_is_a_skip() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" cmd/a.go "x"; commit_all "$r"
  stub "$LD" go 'exit 4'
  stub "$LD" lizard 'echo "lizard not installed" >&2; exit 3'
  check "$r"
  assert_exit 0
  assert_contains "$ERR" "skipped Go (lizard not installed — run setup)"
  assert_contains "$ERR" "cmd/a.go"
}

t_check_lizard_absent_after_own_tool_exit_4() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" cmd/a.go "x"; commit_all "$r"
  stub "$LD" go 'exit 4'
  check "$r"
  assert_exit 0
  assert_contains "$ERR" "skipped Go (not supported)"
}

t_check_exit_2_over_named_unchecked_files_is_not_a_tool_failure() {
  local r; r="$(fixture)"; LD="$(mktmp)"
  add_file "$r" app/a.rb "x"; add_file "$r" app/b.rb "x"; commit_all "$r"
  stub "$LD" ruby 'echo "complexity: app/b.rb could not be parsed — unchecked" >&2; exit 2'
  check "$r"
  assert_exit 0
  assert_contains "$ERR" "complexity: app/b.rb could not be parsed — unchecked"
  assert_not_contains "$ERR" "skipped"
  assert_not_contains "$ERR" "tool failed"
  assert_contains "$ERR" "complexity: clean — 1 file(s) unchecked"
  stub "$LD" ruby 'echo "boom" >&2; exit 2'
  check "$r"
  assert_contains "$ERR" "skipped Ruby (tool failed, exit 2) — unchecked: app/a.rb app/b.rb"
}
