# Tests for skills/complexity-check/scripts/lang/python.sh
TAB=$(printf '\t')

need_radon() {
  [ -x "$TEST_CACHE/joadtor/complexity-check/bin/radon" ] && return 0
  need_net
  XDG_CACHE_HOME="$TEST_CACHE" "$SCRIPTS/setup.sh" install radon >/dev/null 2>&1 || fail "need_radon: install failed"
}

t_python_over_default() {
  need_radon
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/over.py app/over.py
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/over.py
  assert_exit 1
  assert_contains "$OUT" "app/over.py:1${TAB}python${TAB}total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
  assert_contains "$OUT" "app/over.py:25${TAB}python${TAB}Order.total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 2 "no class or duplicate lines"
  run_in "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "Order.total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
}

t_python_at_limit_passes() {
  need_radon
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/at_limit.py app/at_limit.py
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/at_limit.py
  assert_exit 0
  assert_eq "$OUT" ""
}

t_python_ruff_limit_wins() {
  need_radon
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/over.py app/over.py
  copy_fixture "$repo" python/thirteen.py app/thirteen.py
  add_file "$repo" pyproject.toml "[tool.ruff.lint.mccabe]
max-complexity = 12"
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/over.py
  assert_exit 0
  assert_eq "$OUT" ""
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/thirteen.py
  assert_exit 1
  assert_contains "$OUT" "app/thirteen.py:1${TAB}python${TAB}total${TAB}cyclomatic${TAB}13${TAB}12${TAB}pyproject.toml"
}

t_python_flake8_limit() {
  need_radon
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/over.py app/over.py
  copy_fixture "$repo" python/thirteen.py app/thirteen.py
  add_file "$repo" .flake8 "[flake8]
max-complexity = 12"
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/over.py
  assert_exit 0
  assert_eq "$OUT" ""
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/thirteen.py
  assert_exit 1
  assert_contains "$OUT" "app/thirteen.py:1${TAB}python${TAB}total${TAB}cyclomatic${TAB}13${TAB}12${TAB}.flake8"
}

t_python_tool_missing() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/over.py app/over.py
  commit_all "$repo"
  local bin; bin=$(mktmp)
  for c in git dirname python3 bash sed grep sort mktemp cat; do ln -s "$(command -v $c)" "$bin/$c"; done
  PATH="$bin" XDG_CACHE_HOME="$(mktmp)" run_in "$repo" "$SCRIPTS/lang/python.sh" app/over.py
  assert_exit 3
  assert_contains "$ERR" "radon not found"
}
