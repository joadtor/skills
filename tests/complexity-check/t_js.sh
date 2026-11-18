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
js_eslint8_template() { js_template js-eslint8-sonarjs eslint@8.57.1 eslint-plugin-sonarjs@1.0.4; }
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

# js_stub_tool <repo> <tool> <print-config-json> — a git-ignored node_modules/.bin/<tool> stub that logs its calls
js_stub_tool() {
  add_file "$1" .gitignore "node_modules"
  add_file "$1" "node_modules/.bin/$2" "#!/bin/sh
echo \"\$@\" >> '$1/../calls'
echo '$3'"
  chmod +x "$1/node_modules/.bin/$2"
}

# js_stub_eslint_api <repo> <rules-json> — a fake node_modules/eslint whose ESLint class resolves every file to those rules
js_stub_eslint_api() {
  add_file "$1" node_modules/eslint/index.js "exports.ESLint = class { async calculateConfigForFile() { return { rules: $2 }; } };"
}

t_js_detect_unconfigured_exits_4() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  add_file "$repo" eslint.config.mjs 'export default [{ rules: { "no-unused-vars": "error" } }];'
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" --detect src/cog22.js
  assert_exit 4
  assert_eq "$OUT" ""
}

t_js_detect_eslint_configured_but_missing_exits_5() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  add_file "$repo" eslint.config.mjs 'import sonarjs from "eslint-plugin-sonarjs";
export default [{ plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": "error" } }];'
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" --detect src/cog22.js
  assert_exit 5
  assert_eq "$OUT" ""
  assert_eq "$ERR" "eslint (configured in eslint config) is not installed — install the project's dependencies"
}

t_js_detect_eslint_configured_and_runnable_exits_0() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  js_add_cog "$repo"
  js_stub_tool "$repo" eslint ''
  js_stub_eslint_api "$repo" '{"sonarjs/cognitive-complexity":["error",20]}'
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" --detect src/cog22.js
  assert_exit 0
  [ ! -e "$repo/../calls" ] || fail "eslint was run: $(cat "$repo/../calls")"
}

t_js_detect_biome_configured_but_missing_exits_5() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  add_file "$repo" biome.json '{"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":"error"}}}}'
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" --detect src/cog22.js
  assert_exit 5
  assert_eq "$ERR" "biome (configured in biome.json) is not installed — install the project's dependencies"
}

t_js_detect_biome_configured_and_runnable_exits_0() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  add_file "$repo" biome.json '{"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":"error"}}}}'
  js_add_cog "$repo"
  js_stub_tool "$repo" biome ''
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" --detect src/cog22.js
  assert_exit 0
  [ ! -e "$repo/../calls" ] || fail "biome was run: $(cat "$repo/../calls")"
}

js_cover_js_only_config() { # <repo> <limit>
  add_file "$1" eslint.config.mjs - <<EOC
import sonarjs from "eslint-plugin-sonarjs";
export default [{ files: ["**/*.js"], plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": ["error", $2] } }];
EOC
}

t_js_files_the_eslint_config_does_not_cover_are_unchecked_not_a_crash() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  js_cover_js_only_config "$repo" 20
  copy_fixture "$repo" js/cog16.ts src/a.ts
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/a.ts src/cog22.js src/cog18.js
  assert_exit 1
  assert_eq "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}eslint config"
  assert_eq "$ERR" "complexity: src/a.ts not covered by the project's ESLint config — unchecked"
}

t_js_uncovered_files_alone_go_to_lizard() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  js_cover_js_only_config "$repo" 20
  copy_fixture "$repo" js/cog16.ts src/a.ts
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/a.ts
  assert_exit 4
  assert_eq "$OUT$ERR" ""
}

t_js_nothing_over_with_uncovered_files_is_exit_2() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  js_cover_js_only_config "$repo" 20
  copy_fixture "$repo" js/cog16.ts src/a.ts
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/a.ts src/cog18.js
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: src/a.ts not covered by the project's ESLint config — unchecked"
}

t_js_files_with_different_eslint_limits_are_each_measured_at_their_own() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  add_file "$repo" eslint.config.mjs - <<'EOC'
import sonarjs from "eslint-plugin-sonarjs";
export default [
  { files: ["src/**/*.js"], plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": ["error", 25] } },
  { files: ["lib/**/*.js"], plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": ["error", 10] } },
];
EOC
  copy_fixture "$repo" js/cog22.js src/cog22.js
  copy_fixture "$repo" js/cog18.js lib/cog18.js
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js lib/cog18.js
  assert_exit 1
  assert_eq "$OUT" "lib/cog18.js:1${TAB}js${TAB}steady${TAB}cognitive${TAB}18${TAB}10${TAB}eslint config"
}

t_js_eslint_unparsable_file_is_unchecked_not_clean() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  js_cover_js_only_config "$repo" 20
  add_file "$repo" src/broken.js 'function f( {'
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/broken.js
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: src/broken.js could not be parsed — unchecked"
}

t_js_biome_unparsable_file_is_unchecked_not_clean() {
  skip_unless_cmd node
  js_biome_template
  local repo; repo=$(js_repo js-biome)
  add_file "$repo" biome.json '{"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":{"level":"error","options":{"maxAllowedComplexity":20}}}}}}'
  add_file "$repo" src/broken.js 'function f( {'
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/broken.js
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: src/broken.js could not be parsed — unchecked"
}

t_js_an_eslint_crash_after_an_uncovered_notice_is_a_tool_failure_not_unchecked() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  add_file "$repo" eslint.config.mjs - <<'EOC'
import sonarjs from "eslint-plugin-sonarjs";
const boom = { rules: { boom: { create() { throw new Error("boom rule"); } } } };
export default [{ files: ["**/*.js"], plugins: { sonarjs, boom }, rules: { "sonarjs/cognitive-complexity": ["error", 20], "boom/boom": "error" } }];
EOC
  copy_fixture "$repo" js/cog16.ts src/a.ts
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/a.ts src/cog18.js
  assert_exit 6
  assert_contains "$ERR" "src/a.ts not covered by the project's ESLint config — unchecked"
  assert_contains "$ERR" "boom rule"
  run_in "$repo" "$SCRIPTS/check.sh" src/a.ts src/cog18.js
  assert_contains "$ERR" "skipped JS/TS (tool failed: "
  assert_not_contains "$ERR" "complexity: clean — 1 file(s) unchecked"
}

t_js_resolves_every_files_eslint_config_in_one_process_not_one_eslint_per_file() {
  skip_unless_cmd node
  js_eslint_template
  local repo t calls; repo=$(fixture); calls="$TEST_TMP/eslint-calls"
  mkdir -p "$repo/node_modules/.bin"
  for t in "$TEST_CACHE/js-eslint-sonarjs/node_modules"/*; do ln -s "$t" "$repo/node_modules/$(basename "$t")"; done
  printf '#!/bin/sh\necho "$@" >> "%s"\nexec "%s/js-eslint-sonarjs/node_modules/.bin/eslint" "$@"\n' "$calls" "$TEST_CACHE" > "$repo/node_modules/.bin/eslint"
  chmod +x "$repo/node_modules/.bin/eslint"
  printf 'node_modules\n' > "$repo/.gitignore"
  js_cover_js_only_config "$repo" 20
  copy_fixture "$repo" js/cog16.ts src/a.ts
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/a.ts src/cog22.js src/cog18.js
  assert_exit 1
  assert_eq "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}eslint config"
  assert_eq "$ERR" "complexity: src/a.ts not covered by the project's ESLint config — unchecked"
  assert_not_contains "$(cat "$calls")" "--print-config"
  assert_eq "$(wc -l < "$calls" | tr -d ' ')" "1"
}

t_js_eslint8_flat_config_is_honored() {
  skip_unless_cmd node
  js_eslint8_template
  local repo; repo=$(js_repo js-eslint8-sonarjs)
  add_file "$repo" eslint.config.js - <<'EOC'
const sonarjs = require("eslint-plugin-sonarjs");
module.exports = [{ files: ["**/*.js"], plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": ["error", 20] } }];
EOC
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 1
  assert_eq "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}eslint config"
}

t_js_an_eslint_config_that_throws_is_a_tool_failure_not_unconfigured() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  add_file "$repo" eslint.config.mjs 'throw new Error("boom");'
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 6
  assert_contains "$ERR" "boom"
}

t_js_an_eslint_config_that_logs_does_not_break_the_report() {
  skip_unless_cmd node
  js_eslint_template
  local repo; repo=$(js_repo js-eslint-sonarjs)
  add_file "$repo" eslint.config.mjs - <<'EOC'
import sonarjs from "eslint-plugin-sonarjs";
console.log("config loaded");
export default [{ files: ["**/*.js"], plugins: { sonarjs }, rules: { "sonarjs/cognitive-complexity": ["error", 20] } }];
EOC
  js_add_cog "$repo"
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js src/cog18.js
  assert_exit 1
  assert_eq "$OUT" "src/cog22.js:1${TAB}js${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}eslint config"
}

t_js_an_unreadable_eslint_report_is_a_tool_failure_not_clean() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  js_add_cog "$repo"
  js_stub_tool "$repo" eslint 'not json'
  js_stub_eslint_api "$repo" '{"sonarjs/cognitive-complexity":["error",20]}'
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js
  assert_exit 6
  assert_eq "$(printf '%s\n' "$ERR" | head -n 1)" "complexity: could not read ESLint's report" "the reason is ours, not a stack trace"
  assert_not_contains "$ERR" "    at "
}

t_js_an_unreadable_biome_report_is_a_tool_failure_not_clean() {
  skip_unless_cmd node
  local repo; repo=$(fixture)
  add_file "$repo" biome.json '{"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":"error"}}}}'
  js_add_cog "$repo"
  js_stub_tool "$repo" biome 'not json'
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js
  assert_exit 6
  assert_eq "$(printf '%s\n' "$ERR" | head -n 1)" "complexity: could not read Biome's report" "the reason is ours, not a stack trace"
  assert_not_contains "$ERR" "    at "
}

t_js_files_outside_the_biome_config_are_unchecked_not_clean() {
  skip_unless_cmd node
  js_biome_template
  local repo; repo=$(js_repo js-biome)
  add_file "$repo" biome.json '{"files":{"includes":["lib/**"]},"linter":{"rules":{"complexity":{"noExcessiveCognitiveComplexity":{"level":"error","options":{"maxAllowedComplexity":20}}}}}}'
  copy_fixture "$repo" js/cog22.js src/cog22.js
  copy_fixture "$repo" js/cog18.js lib/cog18.js
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/js.sh" src/cog22.js lib/cog18.js
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: src/cog22.js not covered by the project's Biome config — unchecked"
}
