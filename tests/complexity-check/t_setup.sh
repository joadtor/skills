# Tests for scripts/setup.sh (plan and install). lizard is the only tool it installs.
TAB=$(printf '\t')

# stub_path <dir> [fake-tool...]: PATH dir with only the basic commands setup.sh needs, plus the named tools
# (real:<tool> links the real one, anything else is a stub that exits 0)
stub_path() {
  local d="$1" c p; shift
  mkdir -p "$d"
  for c in bash git grep sort sed awk cat dirname basename mkdir rm ln tr head tail cut uname env mktemp date wc; do
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

lizard_pin() { sed -n 's/^LIZARD_VERSION=//p' "$SCRIPTS/setup.sh"; }

# snapshot <repo>: every path (ignored files included) with a content hash
snapshot() { (cd "$1" && find . -path ./.git -prune -o -type f -print | sort | while IFS= read -r f; do shasum "$f"; done; find . -path ./.git -prune -o -print | sort); }

t_setup_asks_once_when_a_language_has_no_tool() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)"; stub_path "$s" uv
  add_file "$r" web/a.ts "export const a = 1;"
  add_file "$r" cmd/main.go "package main"
  commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 1
  assert_eq "$OUT" "-${TAB}lizard${TAB}$(lizard_pin)${TAB}uv tool install lizard==$(lizard_pin) into $c/joadtor/complexity-check${TAB}cache"
}

t_setup_nothing_asked_when_every_language_has_a_tool() {
  local r s calls; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" uv real:python3; calls="$TEST_TMP/calls"
  add_file "$r" app/order.py "def f(): pass"
  add_file "$r" pyproject.toml "[tool.complexipy]"
  add_file "$r" .gitignore ".venv"
  add_file "$r" .venv/bin/complexipy "#!/bin/sh
echo \"\$@\" >> '$calls'"
  chmod +x "$r/.venv/bin/complexipy"
  commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_exit 0
  assert_eq "$OUT" ""
  assert_eq "$(cat "$calls")" "--version"
}

t_setup_never_installs_a_projects_own_tool() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)"; stub_path "$s" uv
  add_file "$r" eslint.config.mjs 'import sonarjs from "eslint-plugin-sonarjs";
export default [{ plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": "error" } }];'
  add_file "$r" web/a.ts "export const a = 1;"
  commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_contains "$OUT" "js${TAB}eslint${TAB}-${TAB}install the project's dependencies${TAB}project-tool-missing"
  assert_contains "$OUT" "-${TAB}lizard${TAB}$(lizard_pin)${TAB}"
  assert_not_contains "$OUT" "npm"
  _setup "$r" "$s" "$c" install eslint
  assert_exit 1
  assert_contains "$ERR" "setup: unknown tool: eslint"
  [ ! -e "$c/joadtor/complexity-check/bin/eslint" ] || fail "eslint was installed"
}

t_setup_unknown_tools_are_refused() {
  local r s t; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" uv
  for t in rubocop radon gocyclo clippy sonarjs; do
    _setup "$r" "$s" "$(mktmp)" install "$t"
    assert_exit 1
    assert_contains "$ERR" "setup: unknown tool: $t"
  done
}

t_setup_install_lizard_never_touches_the_project() {
  need_net
  local r c before; r="$(fixture)"; c="$(mktmp)"
  add_file "$r" app/user.rb "class User; end"
  add_file "$r" .gitignore "node_modules"
  add_file "$r" node_modules/keep.js "x"
  add_file "$r" package.json '{"name":"x"}'
  commit_all "$r"
  before="$(snapshot "$r")"
  run_in "$r" env XDG_CACHE_HOME="$c" bash "$SCRIPTS/setup.sh" install lizard
  assert_exit 0
  assert_eq "$(snapshot "$r")" "$before"
  [ -x "$c/joadtor/complexity-check/bin/lizard" ] || fail "lizard is not in the cache bin"
}

t_setup_install_runs_uv_from_the_cache_with_the_exact_pin() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)"; stub_path "$s"
  printf '#!/bin/sh\npwd -P >> "%s/uv"\necho "$UV_TOOL_DIR $UV_TOOL_BIN_DIR" >> "%s/uv"\necho "$@" >> "%s/uv"\n' "$TEST_TMP" "$TEST_TMP" "$TEST_TMP" > "$s/uv"
  chmod +x "$s/uv"
  _setup "$r" "$s" "$c" install lizard
  assert_exit 0
  local cache="$c/joadtor/complexity-check"
  assert_eq "$(cat "$TEST_TMP/uv")" "$(cd "$cache" && pwd -P)
$cache/uv $cache/bin
tool install --no-config --default-index https://pypi.org/simple lizard==$(lizard_pin)"
}

t_setup_lizard_version_is_an_exact_pin() {
  local n=0 line v
  while IFS= read -r line; do
    n=$((n+1)); v="${line#*=}"
    case "$v" in [0-9]*.[0-9]*.[0-9]*) ;; *) fail "not an exact version: $line";; esac
    case "$v" in *[!0-9.]*) fail "inexact pin: $line";; esac
  done <<EOT
$(grep -E '^[A-Z_]+_VERSION=' "$SCRIPTS/setup.sh")
EOT
  assert_eq "$n" 1
  assert_contains "$(grep -E '^LIZARD_VERSION=' "$SCRIPTS/setup.sh")" "LIZARD_VERSION="
}

t_setup_after_one_install_other_projects_need_no_setup() {
  need_net
  local a b s; a="$(fixture)"; b="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" uv
  add_file "$a" cmd/a.go "package main"; commit_all "$a"
  [ -x "$TEST_CACHE/joadtor/complexity-check/bin/lizard" ] ||
    run_in "$a" env XDG_CACHE_HOME="$TEST_CACHE" bash "$SCRIPTS/setup.sh" install lizard
  add_file "$b" cmd/main.go "package main"
  add_file "$b" src/b.rs "fn b() {}"; commit_all "$b"
  _setup "$b" "$s" "$TEST_CACHE" plan
  assert_exit 0
  assert_eq "$OUT" ""
}

t_setup_declining_installs_nothing() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)"; stub_path "$s" uv
  add_file "$r" cmd/main.go "package main"; commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_contains "$OUT" "lizard"
  [ ! -e "$c/joadtor/complexity-check/bin/lizard" ] || fail "lizard installed by plan"
  [ -z "$(ls -A "$c")" ] || fail "cache not empty after plan"
}

t_setup_missing_runtime_is_reported_not_installed() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)"; stub_path "$s"
  add_file "$r" cmd/main.go "package main"; commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_eq "$OUT" "-${TAB}lizard${TAB}$(lizard_pin)${TAB}install uv first${TAB}runtime-missing"
  [ -z "$(ls -A "$c")" ] || fail "cache not empty after plan"
}

t_setup_a_broken_uv_is_runtime_missing() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s"
  printf '#!/bin/sh\nexit 1\n' > "$s/uv"; chmod +x "$s/uv"
  add_file "$r" cmd/main.go "package main"; commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_contains "$OUT" "install uv first${TAB}runtime-missing"
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
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" uv
  _setup "$r" "$s" "$(mktmp)" plan src/new_service.go
  assert_exit 0
  assert_contains "$OUT" "lizard"
}

t_setup_plan_skips_test_file_arguments() {
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" uv
  add_file "$r" spec/x_spec.rb "describe 1"
  commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan spec/x_spec.rb
  assert_exit 0
  assert_eq "$OUT" ""
}

t_setup_missing_ruby_is_a_note_not_lizard() {
  local r s c; r="$(fixture)"; s="$(mktmp)/bin"; c="$(mktmp)"; stub_path "$s" uv
  add_file "$r" app/user.rb "class User; end"; commit_all "$r"
  _setup "$r" "$s" "$c" plan
  assert_exit 0
  assert_eq "$OUT" "ruby${TAB}ruby${TAB}-${TAB}install Ruby${TAB}runtime-missing"
}

t_setup_ruby_never_needs_lizard() {
  skip_unless_cmd ruby
  local r s; r="$(fixture)"; s="$(mktmp)/bin"; stub_path "$s" uv
  ln -sf "$(ruby -e 'print RbConfig.ruby')" "$s/ruby"
  add_file "$r" app/user.rb "class User; end"; commit_all "$r"
  _setup "$r" "$s" "$(mktmp)" plan
  assert_exit 0
  assert_eq "$OUT" ""
}
