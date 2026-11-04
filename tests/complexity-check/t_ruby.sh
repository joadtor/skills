# Tests for skills/complexity-check/scripts/lang/ruby.sh
TAB=$(printf '\t')

t_ruby_over_default() {
  skip_unless_cmd rubocop
  local repo; repo=$(fixture)
  copy_fixture "$repo" ruby/over.rb app/over.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/over.rb
  assert_exit 1
  assert_contains "$OUT" "app/over.rb:2${TAB}ruby${TAB}Order#total${TAB}cyclomatic${TAB}9${TAB}8${TAB}skill default"
  assert_contains "$OUT" "Order#total${TAB}perceived${TAB}9${TAB}8${TAB}skill default"
  run_in "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "Order#total${TAB}cyclomatic${TAB}9${TAB}8${TAB}skill default"
}

t_ruby_at_limit_passes() {
  skip_unless_cmd rubocop
  local repo; repo=$(fixture)
  copy_fixture "$repo" ruby/at_limit.rb app/at_limit.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/at_limit.rb
  assert_exit 0
  assert_eq "$OUT" ""
}

t_ruby_explicit_wins() {
  skip_unless_cmd rubocop
  local repo; repo=$(fixture)
  add_file "$repo" .rubocop.yml - <<'EOF'
Metrics/CyclomaticComplexity:
  Max: 12
Metrics/PerceivedComplexity:
  Max: 12
EOF
  copy_fixture "$repo" ruby/eleven.rb app/eleven.rb
  copy_fixture "$repo" ruby/thirteen.rb app/thirteen.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/eleven.rb
  assert_exit 0
  assert_eq "$OUT" ""
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/thirteen.rb
  assert_exit 1
  assert_contains "$OUT" "Huge#run${TAB}cyclomatic${TAB}13${TAB}12${TAB}.rubocop.yml"
  assert_contains "$OUT" "Huge#run${TAB}perceived${TAB}13${TAB}12${TAB}.rubocop.yml"
}

t_ruby_disabled_cop() {
  skip_unless_cmd rubocop
  local repo; repo=$(fixture)
  printf 'Metrics:\n  Enabled: false\n' > "$repo/.rubocop.yml"
  copy_fixture "$repo" ruby/over.rb app/over.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/over.rb
  assert_exit 1
  assert_contains "$OUT" "Order#total${TAB}cyclomatic${TAB}9${TAB}8${TAB}skill default (project disables the cop)"
  assert_contains "$OUT" "Order#total${TAB}perceived${TAB}9${TAB}8${TAB}skill default (project disables the cop)"
}

t_ruby_bypass() {
  skip_unless_cmd rubocop
  local repo; repo=$(fixture)
  printf 'require:\n  - rubocop-nonexistent-xyz\n' > "$repo/.rubocop.yml"
  copy_fixture "$repo" ruby/over.rb app/over.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/over.rb
  assert_exit 1
  assert_contains "$OUT" "Order#total${TAB}cyclomatic${TAB}9${TAB}8"
  assert_contains "$ERR" "complexity: Ruby — project .rubocop.yml bypassed ("
}

t_ruby_limit_not_executed() {
  skip_unless_cmd rubocop
  local repo marker; repo=$(fixture); marker="$(mktmp)/pwned"
  printf 'Metrics/CyclomaticComplexity:\n  Max: "1; touch %s"\n' "$marker" > "$repo/.rubocop.yml"
  copy_fixture "$repo" ruby/over.rb app/over.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/over.rb
  [ ! -e "$marker" ] || fail "limit from .rubocop.yml was executed"
  assert_contains "$OUT" "Order#total${TAB}cyclomatic${TAB}9${TAB}8${TAB}skill default"
}

t_ruby_tool_missing() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" ruby/over.rb app/over.rb
  commit_all "$repo"
  local bin; bin="$(mktmp)/bin"; mkdir -p "$bin"
  local t
  for t in git ruby bash dirname mktemp rm cat head sed grep sort tr uname; do
    command -v "$t" >/dev/null 2>&1 && ln -s "$(command -v "$t")" "$bin/$t"
  done
  run_in "$repo" env PATH="$bin" XDG_CACHE_HOME="$(mktmp)" "$BASH" "$SCRIPTS/lang/ruby.sh" app/over.rb
  assert_exit 3
  assert_contains "$(printf '%s\n' "$ERR" | head -n 1)" "rubocop"
}

t_ruby_project_tool_preferred() {
  skip_unless_cmd rubocop
  local repo bin real; repo=$(fixture); bin="$(mktmp)/bin"; mkdir -p "$bin"
  real=$(command -v rubocop)
  printf "source 'https://rubygems.org'\ngem 'rubocop'\n" > "$repo/Gemfile"
  printf 'GEM\n  specs:\n    rubocop (1.50.2)\n' > "$repo/Gemfile.lock"
  printf '#!/bin/sh\necho "$@" > "%s/bundle.args"\nshift 2\nexec "%s" "$@"\n' "$bin" "$real" > "$bin/bundle"
  chmod +x "$bin/bundle"
  copy_fixture "$repo" ruby/over.rb app/over.rb
  commit_all "$repo"
  run_in "$repo" env PATH="$bin:$PATH" "$SCRIPTS/lang/ruby.sh" app/over.rb
  assert_exit 1
  assert_contains "$(cat "$bin/bundle.args" 2>/dev/null)" "exec rubocop"
  assert_contains "$OUT" "Order#total${TAB}cyclomatic${TAB}9${TAB}8"
}

t_ruby_inherited_max_wins() {
  skip_unless_cmd rubocop
  local repo; repo=$(fixture)
  add_file "$repo" .rubocop.yml "inherit_from: .rubocop_todo.yml"
  add_file "$repo" .rubocop_todo.yml - <<'EOT'
Metrics/CyclomaticComplexity:
  Max: 12
Metrics/PerceivedComplexity:
  Max: 12
EOT
  copy_fixture "$repo" ruby/eleven.rb app/eleven.rb
  copy_fixture "$repo" ruby/thirteen.rb app/thirteen.rb
  commit_all "$repo"
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/eleven.rb
  assert_exit 0
  assert_eq "$OUT" ""
  run_in "$repo" "$SCRIPTS/lang/ruby.sh" app/thirteen.rb
  assert_exit 1
  assert_contains "$OUT" "Huge#run${TAB}cyclomatic${TAB}13${TAB}12${TAB}.rubocop.yml"
}
