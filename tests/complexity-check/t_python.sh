# Tests for skills/complexity-check/scripts/lang/python.sh
#
# Fixture scores (complexipy 8.3.0 cognitive): fixtures/python/c18.py Order::total = 18, c22.py risky = 22.
TAB=$(printf '\t')

need_complexipy() {
  need_net
  local d="$TEST_CACHE/py-complexipy"
  mkdir -p "$d"
  [ -x "$d/.venv/bin/complexipy" ] || (cd "$d" && uv venv -q .venv &&
    uv pip install -q --no-config --default-index https://pypi.org/simple --python .venv/bin/python complexipy==8.3.0) >/dev/null 2>&1
  [ -x "$d/.venv/bin/complexipy" ] || fail "need_complexipy: install failed"
}

python_repo() { # <pyproject body> — a repo with both fixtures and the shared venv linked as .venv
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/c18.py app/c18.py
  copy_fixture "$repo" python/c22.py app/c22.py
  add_file "$repo" pyproject.toml "$1"
  add_file "$repo" .gitignore ".venv"
  ln -s "$TEST_CACHE/py-complexipy/.venv" "$repo/.venv"
  commit_all "$repo"
  echo "$repo"
}

t_python_complexipy_project_limit() {
  need_complexipy
  local repo; repo=$(python_repo "[tool.complexipy]
max-complexity-allowed = 20")
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/c18.py app/c22.py
  assert_exit 1
  assert_eq "$OUT" "app/c22.py:1${TAB}python${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}pyproject.toml"
  run_in "$repo" "$SCRIPTS/check.sh" app
  assert_exit 1
  assert_contains "$OUT" "app/c22.py:1${TAB}python${TAB}risky${TAB}cognitive${TAB}22${TAB}20${TAB}pyproject.toml"
  assert_not_contains "$OUT" "c18.py"
}

t_python_complexipy_default_limit() {
  need_complexipy
  local repo; repo=$(python_repo "[tool.complexipy]
paths = [\"app\"]")
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/c18.py
  assert_exit 1
  assert_eq "$OUT" "app/c18.py:2${TAB}python${TAB}Order.total${TAB}cognitive${TAB}18${TAB}15${TAB}skill default"
}

t_python_unconfigured_exits_4() {
  need_complexipy
  local repo; repo=$(python_repo "[tool.ruff]
line-length = 100")
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/c22.py
  assert_exit 4
  assert_eq "$OUT" ""
}

t_python_configured_but_missing() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/c22.py app/c22.py
  add_file "$repo" pyproject.toml "[tool.complexipy]
max-complexity-allowed = 20"
  commit_all "$repo"
  local bin; bin=$(mktmp)
  for c in git dirname python3 bash sed grep sort mktemp cat rm head; do ln -s "$(command -v $c)" "$bin/$c"; done
  PATH="$bin" run_in "$repo" "$SCRIPTS/lang/python.sh" app/c22.py
  assert_exit 3
  assert_eq "$OUT" ""
  assert_eq "$(printf '%s\n' "$ERR" | head -n 1)" "complexipy not installed (configured in pyproject.toml)"
}

t_python_leaves_no_files() {
  need_complexipy
  local repo before; repo=$(python_repo "[tool.complexipy]
max-complexity-allowed = 20")
  before=$(cd "$repo" && git status --porcelain --ignored)
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/c18.py app/c22.py
  assert_exit 1
  assert_eq "$(cd "$repo" && git status --porcelain --ignored)" "$before"
  assert_eq "$(cd "$repo" && ls -A | grep -c complexipy)" 0
}

t_python_committed_venv_binary_not_run() {
  local repo marker; repo=$(fixture); marker="$TEST_TMP/ran"
  copy_fixture "$repo" python/c22.py app/c22.py
  add_file "$repo" pyproject.toml "[tool.complexipy]"
  add_file "$repo" .venv/bin/complexipy "#!/bin/sh
echo x > '$marker'"
  chmod +x "$repo/.venv/bin/complexipy"
  commit_all "$repo"
  local bin; bin=$(mktmp)
  for c in git dirname python3 bash sed grep sort mktemp cat rm head; do ln -s "$(command -v $c)" "$bin/$c"; done
  PATH="$bin" run_in "$repo" "$SCRIPTS/lang/python.sh" app/c22.py
  [ ! -e "$marker" ] || fail "a committed .venv/bin/complexipy was run"
  assert_exit 3
}

t_python_detect_unconfigured_exits_4() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/c22.py app/c22.py
  add_file "$repo" pyproject.toml "[project]
name = \"x\""
  commit_all "$repo"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/python.sh" --detect app/c22.py
  assert_exit 4
  assert_eq "$OUT" ""
}

t_python_detect_configured_but_missing_exits_5() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" python/c22.py app/c22.py
  add_file "$repo" pyproject.toml "[tool.complexipy]
max-complexity-allowed = 20"
  commit_all "$repo"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/python.sh" --detect app/c22.py
  assert_exit 5
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexipy (configured in pyproject.toml) is not installed — install the project's dependencies"
}

t_python_detect_configured_and_runnable_exits_0() {
  local repo calls; repo=$(fixture); calls="$TEST_TMP/calls"
  copy_fixture "$repo" python/c22.py app/c22.py
  add_file "$repo" pyproject.toml "[tool.complexipy]"
  add_file "$repo" .gitignore ".venv"
  add_file "$repo" .venv/bin/complexipy "#!/bin/sh
echo \"\$@\" >> '$calls'"
  chmod +x "$repo/.venv/bin/complexipy"
  commit_all "$repo"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/python.sh" --detect app/c22.py
  assert_exit 0
  assert_eq "$(cat "$calls")" "--version"
}

t_python_unparsable_file_is_unchecked_not_clean() {
  need_complexipy
  local repo; repo=$(python_repo "[tool.complexipy]
max-complexity-allowed = 20")
  add_file "$repo" app/broken.py 'x = (1,'
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/broken.py app/c18.py
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: app/broken.py could not be parsed — unchecked"
  run_in "$repo" "$SCRIPTS/lang/python.sh" app/broken.py app/c22.py
  assert_exit 1
  assert_contains "$OUT" "app/c22.py:1"
  assert_eq "$ERR" "complexity: app/broken.py could not be parsed — unchecked"
}
