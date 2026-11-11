# Tests for scripts/lang/lizard.sh
#
# Fixture scores (cognitive, last CSV column) verified with:
#   lizard -Ecognitive --csv fixtures/cognitive/<dir>/<name>.<ext>
# at_limit.* = 15, over.* = 16, one method "risky" in each of ruby/ts/py/go/rs.

LIZARD_SH="$SCRIPTS/lang/lizard.sh"

lizard_cache() {
  local cache="$TEST_CACHE/joadtor/complexity-check"
  mkdir -p "$cache"
  [ -x "$cache/bin/lizard" ] || (cd "$cache" && UV_TOOL_DIR="$cache/uv" UV_TOOL_BIN_DIR="$cache/bin" \
    uv tool install --no-config --default-index https://pypi.org/simple lizard==1.24.3) >/dev/null 2>&1
  [ -x "$cache/bin/lizard" ] || fail "could not install lizard into the test cache"
}

lizard_repo() {
  need_net; lizard_cache
  local r; r="$(fixture)"
  echo "$r"
}

lizard_limit() { (cd "$1" && . "$SCRIPTS/_common.sh" && default_limit "$2"); }

lizard_over() { # <lang> <dir> <ext> <line> [function]
  local r; r="$(lizard_repo)" || exit $?
  copy_fixture "$r" "cognitive/$2/over.$3" "src/over.$3"
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" "src/over.$3"
  assert_exit 1
  assert_eq "$OUT" "$(printf 'src/over.%s:%s\t%s\t%s\tcognitive\t16\t%s\tskill default' "$3" "$4" "$1" "${5:-risky}" "$(lizard_limit "$r" "$1")")"
}

t_lizard_over_ruby() { lizard_over ruby ruby rb 2; }
t_lizard_over_js() { lizard_over js ts ts 2; }
t_lizard_over_python() { lizard_over python py py 2; }
t_lizard_over_go() { lizard_over go go go 5 Risky; }
t_lizard_over_rust() { lizard_over rust rs rs 4; }

t_lizard_at_limit_passes() {
  local r; r="$(lizard_repo)" || exit $?
  copy_fixture "$r" cognitive/ruby/at_limit.rb src/a.rb
  copy_fixture "$r" cognitive/ts/at_limit.ts src/a.ts
  copy_fixture "$r" cognitive/py/at_limit.py src/a.py
  copy_fixture "$r" cognitive/go/at_limit.go src/a.go
  copy_fixture "$r" cognitive/rs/at_limit.rs src/a.rs
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" src/a.rb src/a.ts src/a.py src/a.go src/a.rs
  assert_eq "$OUT" ""
  assert_exit 0
}

t_lizard_missing() {
  local r; r="$(fixture)"
  copy_fixture "$r" cognitive/ruby/over.rb src/over.rb
  run_in "$r" env PATH=/usr/bin:/bin XDG_CACHE_HOME="$TEST_TMP/empty-cache" "$LIZARD_SH" src/over.rb
  assert_exit 3
  assert_eq "$ERR" "lizard not installed"
}

lizard_stub_bin() { # records every call of network-y tools, never runs them; git passes through
  local bin="$TEST_TMP/stubs" t real
  mkdir -p "$bin" "$TEST_TMP/markers"
  for t in curl wget pip pip3 uv npm gem go; do
    printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\nexit 1\n' "$t" "$TEST_TMP" > "$bin/$t"
    chmod +x "$bin/$t"
  done
  real="$(command -v git)"
  printf '#!/bin/sh\necho "git $*" >> "%s/calls"\nexec "%s" "$@"\n' "$TEST_TMP" "$real" > "$bin/git"
  chmod +x "$bin/git"
  echo "$bin"
}

lizard_traps() { # plant python files that write a marker when imported
  local r="$1" m="$TEST_TMP/markers" n
  for n in lizard_ext/__init__ lizard_ext/lizardcognitive lizardcognitive json sitecustomize usercustomize; do
    add_file "$r" "$n.py" "open('$m/$(echo "$n" | tr / _)', 'w').close()"
  done
  add_file "$r" trap.pth "import os; open('$m/pth', 'w').close()"
}

lizard_snapshot() {
  (cd "$1" && find . -path ./.git -prune -o -print | sort | while IFS= read -r p; do
    if [ -f "$p" ]; then cksum "$p"; else echo "$p"; fi
  done)
}

t_lizard_never_interferes() {
  local r bin before after
  r="$(lizard_repo)" || exit $?
  copy_fixture "$r" cognitive/ruby/over.rb src/over.rb
  copy_fixture "$r" cognitive/ts/over.ts src/over.ts
  copy_fixture "$r" cognitive/py/over.py src/over.py
  copy_fixture "$r" cognitive/go/over.go src/over.go
  copy_fixture "$r" cognitive/rs/over.rs src/over.rs
  lizard_traps "$r"
  add_file "$r" .gitignore "*.log"
  add_file "$r" x.log "ignored"
  bin="$(lizard_stub_bin)"
  before="$(lizard_snapshot "$r")"
  run_in "$r" env PATH="$bin:$PATH" XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" \
    src/over.rb src/over.ts src/over.py src/over.go src/over.rs
  assert_exit 1
  assert_eq "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 5 "all five offenders reported"
  after="$(lizard_snapshot "$r")"
  assert_eq "$after" "$before" "project files changed"
  assert_eq "$(ls "$TEST_TMP/markers")" "" "a planted file was imported"
  assert_eq "$(grep -E '^(curl|wget|pip|pip3|uv|npm|gem|go) |^git (fetch|clone|ls-remote|pull|push)' "$TEST_TMP/calls" 2>/dev/null)" "" "network-y call"
}

# lizard exits 0 with no output and no warning on broken input, so the script cross-checks files with no
# functions using the language's own read-only syntax check.
t_lizard_unparsable_reported() {
  local r; r="$(lizard_repo)" || exit $?
  add_file "$r" src/broken.py - <<'PY'
x = (1,
PY
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" src/broken.py
  assert_exit 2
  assert_contains "$ERR" "complexity: src/broken.py could not be parsed — unchecked"
  assert_eq "$OUT" ""
}

t_lizard_syntax_check_runs_no_repo_code() {
  local r marker; r="$(lizard_repo)" || exit $?; marker="$TEST_TMP/ast-imported"
  add_file "$r" ast.py "open('$marker', 'w').close()"
  add_file "$r" src/trap.py - <<'PY'
x = (1,
PY
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" src/trap.py
  [ ! -e "$marker" ] || fail "the syntax check imported a repo file"
  assert_contains "$ERR" "src/trap.py could not be parsed"
}

t_lizard_valid_file_without_functions_is_not_unchecked() {
  local r; r="$(lizard_repo)" || exit $?
  add_file "$r" src/consts.py "LIMIT = 15"
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" src/consts.py
  assert_exit 0
  assert_not_contains "$ERR" "could not be parsed"
}

# fake_lizard <dir> <version> <exit-status>: a PATH lizard that prints nothing and fails (a broken install)
fake_lizard() {
  mkdir -p "$1"
  printf '#!/bin/sh\n[ "$1" = --version ] && { echo %s; exit 0; }\necho "Traceback: boom" >&2\necho "second line" >&2\nexit %s\n' "$2" "$3" > "$1/lizard"
  chmod +x "$1/lizard"
}

t_lizard_tool_failure_is_exit_2_not_clean() {
  local r; r="$(fixture)"
  copy_fixture "$r" cognitive/ruby/over.rb src/over.rb
  fake_lizard "$TEST_TMP/fake" 1.25.0 1
  run_in "$r" env PATH="$TEST_TMP/fake:/usr/bin:/bin" XDG_CACHE_HOME="$TEST_TMP/none" "$LIZARD_SH" src/over.rb
  assert_exit 2
  assert_eq "$OUT" ""
  assert_contains "$ERR" "Traceback: boom"
  assert_not_contains "$ERR" "could not be parsed"
}

# fake_lizard_rows <dir>: a PATH lizard 1.25.0 that prints one canned --csv row per file it is given:
# cognitive 16 for over.*, 15 for at_limit.*, function "risky" at lines 2-9
fake_lizard_rows() {
  mkdir -p "$1"
  cat > "$1/lizard" <<'SH'
#!/bin/sh
[ "$1" = --version ] && { echo 1.25.0; exit 0; }
for f in "$@"; do
  case $f in
    */over.*) c=16 ;;
    */at_limit.*) c=15 ;;
    *) continue ;;
  esac
  echo "9,3,40,1,8,\"risky@2-9@$f\",\"$f\",\"risky\",\"risky( x )\",2,9,$c"
done
SH
  chmod +x "$1/lizard"
}

# keep_node <dir>: a dir holding only the real node binary (the nodenv shim needs nodenv on PATH)
keep_node() {
  mkdir -p "$1"
  ln -sf "$(node -p process.execPath)" "$1/node"
}

lizard_fake_repo() {
  local r; r="$(fixture)"
  copy_fixture "$r" cognitive/ts/over.ts src/over.ts
  copy_fixture "$r" cognitive/ts/at_limit.ts src/at_limit.ts
  copy_fixture "$r" cognitive/py/over.py src/over.py
  copy_fixture "$r" cognitive/py/at_limit.py src/at_limit.py
  copy_fixture "$r" cognitive/go/over.go src/over.go
  copy_fixture "$r" cognitive/go/at_limit.go src/at_limit.go
  copy_fixture "$r" cognitive/rs/over.rs src/over.rs
  copy_fixture "$r" cognitive/rs/at_limit.rs src/at_limit.rs
  echo "$r"
}

lizard_fake_expected() {
  local l
  for l in "ts js" "py python" "go go" "rs rust"; do
    printf 'src/over.%s:2\t%s\trisky\tcognitive\t16\t15\tskill default\n' "${l% *}" "${l#* }"
  done
}

t_lizard_fake_end_to_end_reports_every_language_without_network() {
  local r; r="$(lizard_fake_repo)"
  fake_lizard_rows "$TEST_TMP/fake"
  run_in "$r" env PATH="$TEST_TMP/fake:/usr/bin:/bin" XDG_CACHE_HOME="$TEST_TMP/none" RUSTUP_AUTO_INSTALL=0 "$SCRIPTS/check.sh"
  assert_exit 1
  assert_eq "$OUT" "$(lizard_fake_expected)"
  assert_contains "$ERR" "complexity: 4 function(s) over the limit"
  assert_not_contains "$ERR" "skipped"
}

t_lizard_fake_end_to_end_unconfigured_eslint_falls_to_lizard() {
  skip_unless_cmd node
  local r; r="$(lizard_fake_repo)"
  fake_lizard_rows "$TEST_TMP/fake"; keep_node "$TEST_TMP/node"
  add_file "$r" .gitignore "node_modules/"
  add_file "$r" node_modules/.bin/eslint '#!/bin/sh
[ "$1" = --print-config ] && { echo "{\"rules\":{\"no-unused-vars\":2}}"; exit 0; }
echo "eslint must not lint" >&2; exit 2'
  chmod +x "$r/node_modules/.bin/eslint"
  run_in "$r" env PATH="$TEST_TMP/fake:$TEST_TMP/node:/usr/bin:/bin" XDG_CACHE_HOME="$TEST_TMP/none" RUSTUP_AUTO_INSTALL=0 "$SCRIPTS/check.sh"
  assert_exit 1
  assert_eq "$OUT" "$(lizard_fake_expected)"
  assert_not_contains "$ERR" "must not lint"
  assert_not_contains "$ERR" "unchecked"
}

t_lizard_forgives_comment_exempts_the_function() {
  local r; r="$(lizard_repo)" || exit $?
  copy_fixture "$r" cognitive/py/over.py src/over.py
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" src/over.py
  assert_exit 1
  sed -i.bak '2i\
    # #lizard forgives -- flat dispatch, reviewed
' "$r/src/over.py"
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$LIZARD_SH" src/over.py
  assert_exit 0
  assert_eq "$OUT" ""
}
