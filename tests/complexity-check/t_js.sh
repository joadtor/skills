# Tests for skills/complexity-check/scripts/lang/js.sh
#
# Fixture scores (cognitive): cog22.js = 22 (risky), cog18.js = 18 (steady) per eslint-plugin-sonarjs;
# Biome counts cog18.js as 19. Both are under a limit of 20.
TAB=$(printf '\t')

# js_template <name> <package>... — installs into $TEST_CACHE/<name> once (never the repo, never ~/.cache)
js_template() {
  local name="$1"; shift
  [ -d "$TEST_CACHE/$name/node_modules" ] && return 0
  need_net; skip_unless_cmd npm
  mkdir -p "$TEST_CACHE/$name"
  (cd "$TEST_CACHE/$name" && echo '{"name":"t","private":true}' > package.json &&
    npm install --no-save --ignore-scripts --registry=https://registry.npmjs.org/ "$@") >/dev/null 2>&1 ||
    fail "npm install $name failed"
}

js_eslint_template() { js_template js-eslint-sonarjs eslint@9.39.5 eslint-plugin-sonarjs@4.2.2; }
js_biome_template()  { js_template js-biome @biomejs/biome@2.6.4; }

# js_repo <template> — fixture repo whose node_modules is the template's, git-ignored
js_repo() {
  local repo; repo=$(fixture)
  ln -s "$TEST_CACHE/$1/node_modules" "$repo/node_modules"
  printf 'node_modules\n' > "$repo/.gitignore"
  echo "$repo"
}

js_add_cog() {
  copy_fixture "$1" js/cog22.js src/cog22.js
  copy_fixture "$1" js/cog18.js src/cog18.js
}

t_js_eslint_sonarjs_project_limit() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  add_file "$repo" eslint.config.mjs - <<'EOC'
import sonarjs from "eslint-plugin-sonarjs";
export default [{ files: ["**/*.js"], plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": ["error", 20] } }];
EOC
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 1
  assert_eq "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}eslint config"
  run_in "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}eslint config"
  assert_not_contains "$OUT" "skill default"
  assert_not_contains "$OUT" "cog18"
}

t_js_biome_project_limit() {
  skip_unless_cmd node
  js_biome_template
  local repo; repo=$(js_repo js-biome)
  add_file "$repo" biome.json '{"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":{"level":"error","options":{"maxAllowedComplexity":20}}}}}}'
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 1
  assert_eq "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}biome.json"
  run_in "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}biome.json"
  assert_not_contains "$OUT" "skill default"
}

t_js_unconfigured_eslint_exits_4() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  add_file "$repo" eslint.config.mjs 'export default [{ files: ["**/*.js"], rules: { "no-unused-vars": "error" } }];'
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 4
  assert_eq "$OUT" ""
}

t_js_no_tools_exits_4() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 4
  assert_eq "$OUT" ""
}

t_js_committed_tool_binary_is_not_run() {
  skip_unless_cmd node
  local repo marker; repo=$(fixture); marker="$repo/ran"
  add_file "$repo" node_modules/.bin/eslint "#!/bin/sh
touch '$marker'"
  add_file "$repo" node_modules/.bin/biome "#!/bin/sh
touch '$marker'"
  chmod +x "$repo/node_modules/.bin/eslint" "$repo/node_modules/.bin/biome"
  add_file "$repo" biome.json '{"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":"error"}}}}'
  copy_fixture "$repo" js/cog22.js src/cog22.js
  (cd "$repo" && git add -f -A && git commit -q -m planted) || fail "commit failed"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js
  assert_exit 4
  [ ! -e "$marker" ] || fail "a committed tool binary was run"
}
