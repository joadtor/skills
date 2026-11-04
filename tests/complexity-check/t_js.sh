# Tests for skills/complexity-check/scripts/lang/js.sh
TAB=$(printf '\t')

# PATH with node but no eslint (nodenv shims break), cache = the populated test cache.
js_env() {
  local bin; bin="$(mktmp)"
  ln -s "$(node -p process.execPath)" "$bin/node"
  JS_PATH="$bin:/usr/bin:/bin"
}

js_cache() {
  [ -x "$TEST_CACHE/joadtor/complexity-check/bin/eslint" ] && return 0
  need_net
  XDG_CACHE_HOME="$TEST_CACHE" "$SCRIPTS/setup.sh" install eslint >/dev/null 2>&1 || fail "setup eslint failed"
}

js_run() {
  local repo="$1"; shift
  run_in "$repo" env PATH="$JS_PATH" XDG_CACHE_HOME="${JS_XDG:-$TEST_CACHE}" "$@"
}

t_js_over_default_ts() {
  skip_unless_cmd node
  js_cache; js_env
  local repo; repo=$(fixture)
  copy_fixture "$repo" js/over.ts src/over.ts
  commit_all "$repo"
  js_run "$repo" "$SCRIPTS/lang/js.sh" src/over.ts
  assert_exit 1
  assert_contains "$OUT" "src/over.ts:1${TAB}js${TAB}total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
  js_run "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
}

t_js_at_limit_passes() {
  skip_unless_cmd node
  js_cache; js_env
  local repo; repo=$(fixture)
  copy_fixture "$repo" js/at_limit.ts src/at_limit.ts
  commit_all "$repo"
  js_run "$repo" "$SCRIPTS/lang/js.sh" src/at_limit.ts
  assert_exit 0
  assert_eq "$OUT" ""
}

t_js_plain_js() {
  skip_unless_cmd node
  js_cache; js_env
  local repo; repo=$(fixture)
  copy_fixture "$repo" js/over.js src/over.js
  commit_all "$repo"
  js_run "$repo" "$SCRIPTS/lang/js.sh" src/over.js
  assert_exit 1
  assert_contains "$OUT" "src/over.js:1${TAB}js${TAB}total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
}

# A project that has its own eslint (symlinked from the test cache) and a config setting complexity.
js_project() {
  local repo="$1" rule="$2"
  mkdir -p "$repo/node_modules/.bin"
  ln -s "$TEST_CACHE/joadtor/complexity-check/node/node_modules/.bin/eslint" "$repo/node_modules/.bin/eslint"
  printf 'export default [{ files: ["**/*.js"], rules: { complexity: %s } }];\n' "$rule" > "$repo/eslint.config.mjs"
  printf 'node_modules\n' > "$repo/.gitignore"
}

t_js_project_limit_wins() {
  skip_unless_cmd node
  js_cache; js_env
  local repo; repo=$(fixture)
  js_project "$repo" '["error", 12]'
  copy_fixture "$repo" js/over.js src/over.js
  sed 's/function total/function bigger/; s/^  return n;/  if (a[10] > 10) n += 10;\n  if (a[11] > 11) n += 11;\n  return n;/' "$FIXTURES/js/over.js" > "$repo/src/bigger.js"
  commit_all "$repo"
  js_run "$repo" "$SCRIPTS/lang/js.sh" src/over.js src/bigger.js
  assert_exit 1
  assert_not_contains "$OUT" "src/over.js"
  assert_contains "$OUT" "src/bigger.js:1${TAB}js${TAB}bigger${TAB}cyclomatic${TAB}13${TAB}12${TAB}eslint config"
}

t_js_rule_off_uses_default() {
  skip_unless_cmd node
  js_cache; js_env
  local repo; repo=$(fixture)
  js_project "$repo" '"off"'
  copy_fixture "$repo" js/over.js src/over.js
  commit_all "$repo"
  js_run "$repo" "$SCRIPTS/lang/js.sh" src/over.js
  assert_exit 1
  assert_contains "$OUT" "src/over.js:1${TAB}js${TAB}total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
}

t_js_tool_missing() {
  skip_unless_cmd node
  js_env
  local repo; repo=$(fixture)
  copy_fixture "$repo" js/over.js src/over.js
  commit_all "$repo"
  JS_XDG="$(mktmp)" js_run "$repo" "$SCRIPTS/lang/js.sh" src/over.js
  assert_exit 3
  assert_contains "$(printf '%s\n' "$ERR" | head -n 1)" "eslint"
}

t_js_path_eslint_without_cached_parser() {
  local r bin; r="$(fixture)"; bin="$(mktmp)"
  printf '#!/bin/sh\nexit 0\n' > "$bin/eslint"; chmod +x "$bin/eslint"
  add_file "$r" src/a.ts "x"; commit_all "$r"
  run_in "$r" env PATH="$bin:/usr/bin:/bin" XDG_CACHE_HOME="$(mktmp)" "$SCRIPTS/lang/js.sh" src/a.ts
  assert_exit 3
  assert_contains "$ERR" "typescript-eslint parser not installed"
}
