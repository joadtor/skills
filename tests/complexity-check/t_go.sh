# Tests for skills/complexity-check/scripts/lang/go.sh
#
# Fixture scores (gocognit, a chain of N top-level ifs scores N), verified with:
#   gocognit -over 0 fixtures/go/cog/app/*.go      # Mid = 18, Total = 22
# Tools are installed into $TEST_CACHE/go-bin by `go install` (network), never into a repo.
TAB=$(printf '\t')

go_tools() {
  local bin="$TEST_CACHE/go-bin"
  [ -x "$bin/gocognit" ] && [ -x "$bin/golangci-lint" ] && return 0
  need_net
  skip_unless_cmd go
  GOBIN="$bin" go install github.com/uudashr/gocognit/cmd/gocognit@v1.3.0 >/dev/null 2>&1 || fail "go_tools: gocognit install failed"
  GOBIN="$bin" go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v2.15.0 >/dev/null 2>&1 || fail "go_tools: golangci-lint install failed"
}

go_repo() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/cog/go.mod go.mod
  copy_fixture "$repo" go/cog/app/mid.go app/mid.go
  copy_fixture "$repo" go/cog/app/high.go app/high.go
  echo "$repo"
}

# a PATH holding only the named tools from the test cache, plus go and the system
go_path_with() {
  local d t; d=$(mktmp)
  for t in "$@"; do ln -s "$TEST_CACHE/go-bin/$t" "$d/$t"; done
  echo "$d:$(dirname "$(command -v go)"):/usr/bin:/bin"
}

t_go_golangci_gocognit_project_limit() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocognit
  settings:
    gocognit:
      min-complexity: 20
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/mid.go app/high.go
  assert_exit 1
  assert_eq "$OUT" "app/high.go:3${TAB}go${TAB}Total${TAB}cognitive${TAB}22${TAB}20${TAB}.golangci.yml"
  run_in "$repo" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_contains "$OUT" "app/high.go:3${TAB}go${TAB}Total${TAB}cognitive${TAB}22${TAB}20${TAB}.golangci.yml"
  assert_not_contains "$OUT" "Mid"
}

t_go_golangci_default_limit_when_unset() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocognit
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/mid.go app/high.go
  assert_exit 1
  assert_contains "$OUT" "app/high.go:3${TAB}go${TAB}Total${TAB}cognitive${TAB}22${TAB}15${TAB}skill default"
  assert_contains "$OUT" "app/mid.go:3${TAB}go${TAB}Mid${TAB}cognitive${TAB}18${TAB}15${TAB}skill default"
}

t_go_gocognit_on_path() {
  go_tools
  local repo; repo=$(go_repo)
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with gocognit)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/mid.go app/high.go
  assert_exit 1
  assert_contains "$OUT" "app/high.go:3${TAB}go${TAB}Total${TAB}cognitive${TAB}22${TAB}15${TAB}skill default"
  assert_contains "$OUT" "app/mid.go:3${TAB}go${TAB}Mid${TAB}cognitive${TAB}18${TAB}15${TAB}skill default"
}

t_go_invalid_limit_falls_back_to_default() {
  go_tools
  local repo; repo=$(go_repo)
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with gocognit)"
  add_file "$repo" .golangci.yml - <<'YML'
linters:
  enable:
    - gocognit
linters-settings:
  gocognit:
    min-complexity: not-a-number
YML
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/mid.go
  assert_exit 1
  assert_contains "$OUT" "${TAB}18${TAB}15${TAB}skill default"
}

t_go_unconfigured_exits_4() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocyclo
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/mid.go app/high.go
  assert_exit 4
  assert_eq "$OUT" ""
}

t_go_no_tools_exits_4() {
  local repo; repo=$(go_repo)
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/go.sh" app/mid.go
  assert_exit 4
}

t_go_leaves_no_files() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocognit
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)"
  local before; before=$(cd "$repo" && git status --porcelain --ignored)
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/mid.go app/high.go
  assert_exit 1
  assert_eq "$(cd "$repo" && git status --porcelain --ignored)" "$before"
}

# go_stub_bin <tool>... — a PATH-first dir of stubs that log their calls to $TEST_TMP/calls
go_stub_bin() {
  local d t; d=$(mktmp)
  for t in "$@"; do printf '#!/bin/sh\necho "%s $@" >> "%s/calls"\nexit 0\n' "$t" "$TEST_TMP" > "$d/$t"; chmod +x "$d/$t"; done
  echo "$d"
}

go_enable_gocognit() {
  add_file "$1" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocognit
YML
}

t_go_detect_unconfigured_exits_4() {
  local repo; repo=$(go_repo)
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/go.sh" --detect app/mid.go
  assert_exit 4
  assert_eq "$OUT" ""
}

t_go_detect_configured_but_missing_exits_5() {
  local repo; repo=$(go_repo)
  go_enable_gocognit "$repo"
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)"
  run_in "$repo" env PATH="/usr/bin:/bin" "$SCRIPTS/lang/go.sh" --detect app/mid.go
  assert_exit 5
  assert_eq "$OUT" ""
  assert_eq "$ERR" "golangci-lint (configured in .golangci.yml) is not installed — install the project's dependencies"
}

t_go_detect_configured_and_runnable_exits_0() {
  local repo bin; repo=$(go_repo)
  go_enable_gocognit "$repo"
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)"
  bin=$(go_stub_bin golangci-lint)
  run_in "$repo" env PATH="$bin:/usr/bin:/bin" "$SCRIPTS/lang/go.sh" --detect app/mid.go
  assert_exit 0
  assert_eq "$(cat "$TEST_TMP/calls")" "golangci-lint --version"
}
