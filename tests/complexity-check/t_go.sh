# Tests for skills/complexity-check/scripts/lang/go.sh
TAB=$(printf '\t')

go_tool() {
  [ -x "$TEST_CACHE/joadtor/complexity-check/bin/gocyclo" ] && return 0
  need_net
  XDG_CACHE_HOME="$TEST_CACHE" "$SCRIPTS/setup.sh" install gocyclo >/dev/null 2>&1 || fail "go_tool: gocyclo install failed"
}

t_go_over_default() {
  go_tool
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/over.go app/over.go
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/over.go
  assert_exit 1
  assert_contains "$OUT" "app/over.go:5${TAB}go${TAB}Total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
  assert_contains "$OUT" "${TAB}go${TAB}(*Order).Ship${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
  run_in "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "Total${TAB}cyclomatic${TAB}11${TAB}10${TAB}skill default"
}

t_go_at_limit_passes() {
  go_tool
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/at_limit.go app/at_limit.go
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/at_limit.go
  assert_exit 0
  assert_eq "$OUT" ""
}

t_go_golangci_v1_limit() {
  go_tool
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/over.go app/over.go
  copy_fixture "$repo" go/over13.go app/over13.go
  add_file "$repo" .golangci.yml - <<'YML'
linters:
  enable:
    - gocyclo
linters-settings:
  dupl:
    threshold: 100
  gocyclo:
    min-complexity: 12
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/over.go app/over13.go
  assert_exit 1
  assert_not_contains "$OUT" "over.go"
  assert_contains "$OUT" "app/over13.go:3${TAB}go${TAB}Huge${TAB}cyclomatic${TAB}13${TAB}12${TAB}.golangci.yml"
}

t_go_golangci_v2_limit() {
  go_tool
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/over.go app/over.go
  copy_fixture "$repo" go/over13.go app/over13.go
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocyclo
  settings:
    dupl:
      threshold: 100
    gocyclo:
      min-complexity: 12
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$TEST_CACHE"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/over.go app/over13.go
  assert_exit 1
  assert_not_contains "$OUT" "over.go"
  assert_contains "$OUT" "app/over13.go:3${TAB}go${TAB}Huge${TAB}cyclomatic${TAB}13${TAB}12${TAB}.golangci.yml"
}

t_go_tool_missing() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/over.go app/over.go
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/go.sh" app/over.go
  assert_exit 3
  assert_contains "$ERR" "gocyclo not found"
}
