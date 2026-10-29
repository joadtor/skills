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
  assert_eq "$OUT" "8
10
10
10
15"
}

t_common_project_tool_preferred() {
  local r cache; r="$(fixture)"; cache="$TEST_TMP/xdg"
  mkdir -p "$cache/joadtor/complexity-check/bin"
  printf '#!/bin/sh\n' > "$cache/joadtor/complexity-check/bin/rubocop"
  chmod +x "$cache/joadtor/complexity-check/bin/rubocop"
  add_file "$r" Gemfile.lock "    rubocop (1.50.2)"
  run_in "$r" env XDG_CACHE_HOME="$cache" PATH=/usr/bin:/bin bash -c ". \"$SCRIPTS/_common.sh\"; resolve rubocop"
  assert_eq "$OUT" "bundle exec rubocop"
  rm "$r/Gemfile.lock"
  run_in "$r" env XDG_CACHE_HOME="$cache" PATH=/usr/bin:/bin bash -c ". \"$SCRIPTS/_common.sh\"; resolve rubocop"
  assert_eq "$OUT" "$cache/joadtor/complexity-check/bin/rubocop"
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/none" PATH=/usr/bin:/bin bash -c ". \"$SCRIPTS/_common.sh\"; resolve rubocop"
  assert_eq "$OUT" ""
}
