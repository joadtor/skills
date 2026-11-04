# Tests for scripts/setup.sh (plan and install)

# stub_path <dir> [fake-tool...]: PATH dir with only the basic commands setup.sh needs, plus the named real or fake tools
stub_path() {
  local d="$1" c p; shift
  mkdir -p "$d"
  for c in git grep sort sed awk cat dirname basename mkdir rm ln tr head tail cut uname env mktemp date; do
    p="$(command -v "$c")" && ln -sf "$p" "$d/$c"
  done
  for c in "$@"; do
    case "$c" in
      real:*) ln -sf "$(command -v "${c#real:}")" "$d/${c#real:}" ;;
      *) printf '#!/bin/sh\nexit 0\n' > "$d/$c"; chmod +x "$d/$c" ;;
    esac
  done
}

# _setup <repo> <stubdir> <cachedir> args...: run setup.sh with only the stub PATH
_setup() {
  local repo="$1" stub="$2" cache="$3"; shift 3
  run_in "$repo" env PATH="$stub" XDG_CACHE_HOME="$cache" "$(command -v bash)" "$SCRIPTS/setup.sh" "$@"
}

t_setup_only_present_languages() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s"
  add_file "$r" app/user.rb "class User; end"
  commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_exit 0
  assert_contains "$OUT" "rubocop"
  assert_not_contains "$OUT" "gocyclo"
  assert_not_contains "$OUT" "go"$'\t'
}

t_setup_nothing_missing() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s"
  add_file "$r" app/user.rb "class User; end"
  add_file "$r" Gemfile.lock "    rubocop (1.50.2)"
  commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_exit 0
  assert_eq "$OUT" ""
}

t_setup_runtime_missing() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)/cache"; stub_path "$s"
  add_file "$r" cmd/main.go "package main"
  commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 1
  assert_contains "$OUT" "runtime-missing"
  assert_contains "$OUT" "go"
  [ -z "$(ls -A "$c" 2>/dev/null)" ] || fail "cache not empty after plan"
}

t_setup_clippy_global() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" rustup
  printf '#!/bin/sh\n[ "$1" = clippy ] && exit 1\nexit 0\n' > "$s/cargo"; chmod +x "$s/cargo"
  add_file "$r" src/lib.rs "fn main() {}"
  commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_exit 0
  assert_contains "$OUT" "clippy"
  assert_contains "$OUT" "rustup component add clippy"
  assert_contains "$OUT" "global-toolchain"
}

t_setup_pins_exact() {
  local v n=0 line
  while IFS= read -r line; do
    n=$((n+1)); v="${line#*=}"; v="${v//\"/}"
    [ -n "$v" ] || fail "empty pin: $line"
    case "$v" in *latest*|*^*|*~*|*\**|*\>*) fail "inexact pin: $line";; esac
  done <<EOT
$(grep -E '^[A-Z_]+_VERSION=' "$SCRIPTS/setup.sh")
EOT
  [ "$n" -ge 5 ] || fail "expected at least 5 version pins, found $n"
}

t_setup_no_project_files_touched() {
  need_net
  local r; r="$(fixture)"
  add_file "$r" package.json '{"name":"x"}'
  add_file "$r" Gemfile "source 'https://rubygems.org'"
  add_file "$r" Gemfile.lock "GEM"
  add_file "$r" pyproject.toml "[project]"
  add_file "$r" go.mod "module x"
  add_file "$r" Cargo.toml "[package]"
  commit_all "$r"
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" bash "$SCRIPTS/setup.sh" install eslint radon gocyclo
  assert_exit 0
  assert_eq "$(cd "$r" && git status --porcelain)" ""
  local t; for t in eslint radon gocyclo; do
    [ -x "$TEST_CACHE/joadtor/complexity-check/bin/$t" ] || fail "missing $t in cache"
  done
}

t_setup_cached_tool_reused() {
  need_net
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" real:go
  [ -x "$TEST_CACHE/joadtor/complexity-check/bin/gocyclo" ] ||
    XDG_CACHE_HOME="$TEST_CACHE" bash "$SCRIPTS/setup.sh" install gocyclo >/dev/null 2>&1
  add_file "$r" cmd/main.go "package main"
  commit_all "$r"
  _setup "$r" "$s" "$TEST_CACHE" plan
  assert_exit 0
  assert_eq "$OUT" ""
}

t_setup_plan_no_base_branch_is_an_error() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s"
  (cd "$r" && git remote remove origin) >/dev/null 2>&1
  add_file "$r" app/a.rb "class A; end"; commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_exit 2
  assert_contains "$ERR" "can't find the base branch on origin"
}

t_setup_plan_languages_from_path_arguments() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" go
  _setup "$r" "$s" "$(mktmp)" plan src/new_service.go
  assert_exit 0
  assert_contains "$OUT" "gocyclo"
}

t_setup_plan_eslint_without_cached_parser() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)/cache"; stub_path "$s" eslint
  add_file "$r" web/a.ts "x"; commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_contains "$OUT" "eslint"
  mkdir -p "$c/joadtor/complexity-check/node/node_modules/typescript-eslint/dist"
  : > "$c/joadtor/complexity-check/node/node_modules/typescript-eslint/dist/index.js"
  _setup "$r" "$s" "$c" plan
  assert_eq "$OUT" ""
}

t_setup_plan_old_ruby_is_runtime_missing() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" gem ruby
  printf '#!/bin/sh\nexit 1\n' > "$s/ruby"
  add_file "$r" app/a.rb "x"; commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_contains "$OUT" "install Ruby >= 2.7 first"
  assert_contains "$OUT" "runtime-missing"
  printf '#!/bin/sh\nexit 0\n' > "$s/ruby"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_not_contains "$OUT" "runtime-missing"
  assert_contains "$OUT" "rubocop"
}

t_setup_plan_old_node_is_runtime_missing() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" npm node
  printf '#!/bin/sh\nexit 1\n' > "$s/node"
  add_file "$r" web/a.ts "x"; commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_contains "$OUT" "install Node >= 20.19 first"
  assert_contains "$OUT" "runtime-missing"
  printf '#!/bin/sh\nexit 0\n' > "$s/node"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_not_contains "$OUT" "runtime-missing"
}
