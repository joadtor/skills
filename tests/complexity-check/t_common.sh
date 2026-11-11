# Tests for scripts/_common.sh (sourced library)

_common() { run_in "$1" bash -c ". \"$SCRIPTS/_common.sh\"; $2"; }

t_common_changed_only() {
  local r; r="$(fixture)"
  add_file "$r" app/models/user.rb "class User; end"
  commit_all "$r" "user"
  (cd "$r" && git push -q origin feature:main) >/dev/null 2>&1
  add_file "$r" app/models/order.rb "class Order; end"
  commit_all "$r" "order"
  _common "$r" target_files
  assert_contains "$OUT" "app/models/order.rb"
  assert_not_contains "$OUT" "app/models/user.rb"
}

t_common_path_mode() {
  local r; r="$(fixture)"
  add_file "$r" app/models/user.rb "class User; end"
  add_file "$r" app/models/order.rb "class Order; end"
  add_file "$r" app/other.rb "x"
  commit_all "$r" "models"
  (cd "$r" && git push -q origin feature:main) >/dev/null 2>&1
  add_file "$r" app/models/new.rb "class New; end"
  _common "$r" "target_files app/models"
  assert_eq "$OUT" "app/models/new.rb
app/models/order.rb
app/models/user.rb"
  _common "$r" "target_files app/other.rb"
  assert_eq "$OUT" "app/other.rb"
}

t_common_excluded_files() {
  local r; r="$(fixture)"
  add_file "$r" spec/models/order_spec.rb "x"
  add_file "$r" db/migrate/001_init.rb "x"
  add_file "$r" node_modules/x/index.js "x"
  add_file "$r" config/app.yml "x"
  add_file "$r" app/keep.rb "x"
  commit_all "$r" "all"
  _common "$r" target_files
  assert_eq "$OUT" "app/keep.rb"
}

t_common_base_branch() {
  local r; r="$(fixture)"
  _common "$r" base_branch
  assert_eq "$OUT" "main"
  (cd "$r" && git push -q origin main:develop) >/dev/null 2>&1
  _common "$r" base_branch
  assert_eq "$OUT" "develop"
}

t_common_lang_and_limits() {
  local r; r="$(fixture)"
  _common "$r" 'for f in a.rb a.js a.jsx a.mjs a.cjs a.ts a.tsx a.py a.go a.rs a.txt; do echo "$(lang_of $f)"; done'
  assert_eq "$OUT" "ruby
js
js
js
js
js
js
python
go
rust"
  _common "$r" 'for l in ruby js python go rust; do echo "$(default_limit $l)"; done'
  assert_eq "$OUT" "15
15
15
15
15"
}

t_common_resolve_path_then_cache() {
  local r cache bin; r="$(fixture)"; cache="$TEST_TMP/xdg"; bin="$TEST_TMP/bin"
  mkdir -p "$cache/joadtor/complexity-check/bin" "$bin"
  printf '#!/bin/sh
exit 0
' > "$cache/joadtor/complexity-check/bin/lizard"
  printf '#!/bin/sh\necho 1.25.0\n' > "$bin/lizard"
  chmod +x "$cache/joadtor/complexity-check/bin/lizard" "$bin/lizard"
  run_in "$r" env XDG_CACHE_HOME="$cache" PATH="$bin:/usr/bin:/bin" bash -c ". \"$SCRIPTS/_common.sh\"; resolve lizard"
  assert_eq "$OUT" "lizard" "a working tool on PATH comes before the cache"
  run_in "$r" env XDG_CACHE_HOME="$cache" PATH=/usr/bin:/bin bash -c ". \"$SCRIPTS/_common.sh\"; resolve lizard"
  assert_eq "$OUT" "$cache/joadtor/complexity-check/bin/lizard"
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/none" PATH=/usr/bin:/bin bash -c ". \"$SCRIPTS/_common.sh\"; resolve lizard"
  assert_eq "$OUT" ""
}

t_common_dash_paths_never_look_like_flags() {
  local r; r="$(fixture)"
  add_file "$r" "--rule=x.js" "x"
  add_file "$r" "app/-ok.rb" "x"
  commit_all "$r" "dash"
  _common "$r" target_files
  assert_contains "$OUT" "./--rule=x.js"
  assert_contains "$OUT" "app/-ok.rb"
  assert_not_contains "$OUT" "
--rule"
}

t_common_broken_path_shim_ignored() {
  local r shims; r="$(fixture)"; shims="$TEST_TMP/shims"
  mkdir -p "$shims"
  printf '#!/bin/sh\necho "nodenv: eslint: command not found" >&2\nexit 127\n' > "$shims/eslint"
  chmod +x "$shims/eslint"
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/none" PATH="$shims:/usr/bin:/bin" bash -c ". \"$SCRIPTS/_common.sh\"; resolve eslint"
  assert_eq "$OUT" "" "a version-manager shim that can't run is not a tool"
}

t_common_base_branch_local_ref_no_network() {
  local r; r="$(fixture)"
  (cd "$r" && git push -q origin main:trunk &&
    git --git-dir="$(git remote get-url origin)" symbolic-ref HEAD refs/heads/trunk &&
    git push -q origin --delete main &&
    git fetch -q --prune origin && git remote set-head origin trunk) >/dev/null 2>&1
  run_in "$r" env GIT_TRACE=1 bash -c ". \"$SCRIPTS/_common.sh\"; base_branch"
  assert_eq "$OUT" "trunk"
  assert_not_contains "$ERR" "upload-pack"
  assert_not_contains "$ERR" "remote-curl"
}

t_common_pytest_files_skipped() {
  local r; r="$(fixture)"
  add_file "$r" app/test_orders.py "x"
  add_file "$r" app/keep.py "x"
  commit_all "$r" "py"
  _common "$r" target_files
  assert_eq "$OUT" "app/keep.py"
}


t_common_committed_repo_tool_never_used() {
  local r marker; r="$(fixture)"; marker="$TEST_TMP/ran"
  add_file "$r" node_modules/.bin/eslint "#!/bin/sh
touch '$marker'"
  add_file "$r" .venv/bin/complexipy "#!/bin/sh
touch '$marker'"
  chmod +x "$r/node_modules/.bin/eslint" "$r/.venv/bin/complexipy"
  (cd "$r" && git add -f node_modules .venv && git commit -qm planted) >/dev/null
  _common "$r" 'local_tool node_modules/.bin/eslint; local_tool .venv/bin/complexipy; resolve eslint'
  assert_eq "$OUT" "" "a tool binary committed to the repo is never used"
  [ ! -e "$marker" ] || fail "a committed repo binary was executed"
}

t_common_installed_repo_tool_is_used() {
  local r; r="$(fixture)"
  add_file "$r" .gitignore ".venv/"
  add_file "$r" .venv/bin/complexipy "#!/bin/sh
exit 0"
  chmod +x "$r/.venv/bin/complexipy"
  commit_all "$r"
  _common "$r" 'local_tool .venv/bin/complexipy'
  assert_eq "$OUT" ".venv/bin/complexipy"
}

t_common_tool_under_committed_symlink_never_used() {
  local r marker; r="$(fixture)"; marker="$TEST_TMP/ran"
  add_file "$r" tools/.bin/eslint "#!/bin/sh
touch '$marker'"
  chmod +x "$r/tools/.bin/eslint"
  (cd "$r" && ln -s tools node_modules && git add -f tools node_modules && git commit -qm planted) >/dev/null
  _common "$r" 'local_tool node_modules/.bin/eslint; resolve eslint'
  assert_eq "$OUT" "" "a tool reached through a committed symlink is never used"
  [ ! -e "$marker" ] || fail "a committed repo binary was executed"
}

t_common_resolve_rejects_a_lizard_below_the_cognitive_minimum() {
  local r bin cache; r="$(fixture)"; bin="$TEST_TMP/bin"; cache="$TEST_TMP/xdg"
  mkdir -p "$cache/joadtor/complexity-check/bin" "$bin"
  printf '#!/bin/sh\necho 1.24.3\n' > "$cache/joadtor/complexity-check/bin/lizard"
  chmod +x "$cache/joadtor/complexity-check/bin/lizard"
  for v in 1.17.10 1.24.2 garbage; do
    printf '#!/bin/sh\necho %s\n' "$v" > "$bin/lizard"; chmod +x "$bin/lizard"
    run_in "$r" env XDG_CACHE_HOME="$cache" PATH="$bin:/usr/bin:/bin" bash -c ". \"$SCRIPTS/_common.sh\"; resolve lizard"
    assert_eq "$OUT" "$cache/joadtor/complexity-check/bin/lizard" "PATH lizard $v is ignored"
  done
  for v in 1.24.3 1.25.0 1.100.0 2.0.0; do
    printf '#!/bin/sh\necho %s\n' "$v" > "$bin/lizard"
    run_in "$r" env XDG_CACHE_HOME="$cache" PATH="$bin:/usr/bin:/bin" bash -c ". \"$SCRIPTS/_common.sh\"; resolve lizard"
    assert_eq "$OUT" "lizard" "PATH lizard $v is accepted"
  done
}

t_common_features_dir_skipped_only_at_the_top_level() {
  local r; r="$(fixture)"
  add_file "$r" features/step_definitions/steps.rb "x"
  add_file "$r" src/features/x.rb "x"
  add_file "$r" app/features/x.ts "x"
  commit_all "$r" "features"
  _common "$r" target_files
  assert_eq "$OUT" "app/features/x.ts
src/features/x.rb"
}

t_common_build_dist_target_vendor_fixtures_skipped_at_any_depth() {
  local r d; r="$(fixture)"
  for d in build dist target vendor fixtures; do
    add_file "$r" "$d/a.rb" "x"
    add_file "$r" "src/$d/a.rb" "x"
  done
  add_file "$r" app/keep.rb "x"
  commit_all "$r" "skipped"
  _common "$r" target_files
  assert_eq "$OUT" "app/keep.rb"
}

t_common_base_branch_order_is_develop_master_main() {
  local r; r="$(fixture)"
  (cd "$r" && git push -q origin main:master) >/dev/null 2>&1
  _common "$r" base_branch
  assert_eq "$OUT" "master" "master beats main"
  (cd "$r" && git push -q origin main:develop) >/dev/null 2>&1
  _common "$r" base_branch
  assert_eq "$OUT" "develop" "develop beats master"
}
