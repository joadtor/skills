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

t_go_golangci_never_reads_the_repo_config() {
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
  exclusions:
    rules:
      - path: app/high.go
        linters:
          - gocognit
YML
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/high.go
  assert_exit 1
  assert_contains "$OUT" "Total${TAB}cognitive${TAB}22${TAB}20${TAB}.golangci.yml"
}

t_go_package_dir_with_space() {
  local repo bin; repo=$(go_repo); bin=$(mktmp)
  mkdir -p "$repo/app dir"
  cp "$repo/app/high.go" "$repo/app dir/high.go"
  go_enable_gocognit "$repo"
  commit_all "$repo"
  # a stub golangci-lint that writes each argument on its own line, so a split argument shows
  printf '#!/bin/sh
[ "$1" = --version ] && { echo "golangci-lint has version 2.15.0"; exit 0; }
for a in "$@"; do printf "%%s\n" "$a"; done > "%s/args"
echo "{}"
' "$TEST_TMP" > "$bin/golangci-lint"
  chmod +x "$bin/golangci-lint"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$bin:/usr/bin:/bin:$(dirname "$(command -v python3)")"
  run_in "$repo" "$SCRIPTS/lang/go.sh" "app dir/high.go"
  assert_contains "$(cat "$TEST_TMP/args")" "--
./app dir"
  assert_not_contains "$(cat "$TEST_TMP/args")" "
dir
"
}

t_go_a_gocognit_in_the_skill_cache_is_not_used() {
  go_tools
  local repo c; repo=$(go_repo); c=$(mktmp)
  commit_all "$repo"
  mkdir -p "$c/joadtor/complexity-check/bin"
  ln -s "$TEST_CACHE/go-bin/gocognit" "$c/joadtor/complexity-check/bin/gocognit"
  run_in "$repo" env XDG_CACHE_HOME="$c" PATH="/usr/bin:/bin" "$SCRIPTS/lang/go.sh" app/high.go
  assert_exit 4
}

t_go_gocognit_unparsable_file_is_unchecked_not_clean() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" app/broken.go 'package app
func Broken( {'
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with gocognit)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/broken.go
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: app/broken.go could not be parsed — unchecked"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/broken.go app/mid.go
  assert_exit 1
  assert_contains "$OUT" "app/mid.go:3${TAB}go${TAB}Mid"
  assert_eq "$ERR" "complexity: app/broken.go could not be parsed — unchecked"
}

t_go_golangci_unparsable_file_is_unchecked_not_clean() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocognit
YML
  add_file "$repo" app/broken.go 'package app
func Broken( {'
  commit_all "$repo"
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)" "$SCRIPTS/lang/go.sh" app/broken.go
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: app/broken.go could not be parsed — unchecked"
}

t_go_gocognit_names_every_unparsable_file_and_still_measures_the_rest() {
  go_tools
  local repo; repo=$(go_repo)
  add_file "$repo" app/a_broken.go 'package app
func A( {'
  add_file "$repo" app/b_broken.go 'package app
func B( {'
  commit_all "$repo"
  export XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with gocognit)"
  run_in "$repo" "$SCRIPTS/lang/go.sh" app/a_broken.go app/b_broken.go app/high.go
  assert_exit 1
  assert_contains "$OUT" "app/high.go:3${TAB}go${TAB}Total${TAB}cognitive${TAB}22"
  assert_contains "$ERR" "complexity: app/a_broken.go could not be parsed — unchecked"
  assert_contains "$ERR" "complexity: app/b_broken.go could not be parsed — unchecked"
}

go_golangci_repo_with_broken_sibling() {
  local repo; repo=$(go_repo)
  go_enable_gocognit "$repo"
  add_file "$repo" app/a_broken.go 'package app
func A( {'
  commit_all "$repo"
  echo "$repo"
}

t_go_golangci_a_syntax_error_marks_every_requested_file_of_the_package_unchecked() {
  go_tools
  local repo; repo=$(go_golangci_repo_with_broken_sibling)
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)" "$SCRIPTS/lang/go.sh" app/a_broken.go app/high.go
  assert_exit 2
  assert_eq "$OUT" ""
  assert_contains "$ERR" "complexity: app/a_broken.go could not be parsed — unchecked"
  assert_contains "$ERR" "complexity: app/high.go could not be parsed — unchecked"
}

t_go_golangci_a_broken_sibling_not_requested_still_marks_the_requested_file_unchecked() {
  go_tools
  local repo; repo=$(go_golangci_repo_with_broken_sibling)
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)" "$SCRIPTS/lang/go.sh" app/high.go
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "complexity: app/high.go could not be parsed — unchecked"
}

t_go_golangci_a_plain_type_error_still_lets_gocognit_run() {
  go_tools
  local repo; repo=$(go_repo)
  go_enable_gocognit "$repo"
  add_file "$repo" app/t.go 'package app
func T() int { return undefinedVar }'
  commit_all "$repo"
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)" "$SCRIPTS/lang/go.sh" app/t.go app/high.go
  assert_exit 1
  assert_contains "$OUT" "app/high.go:3${TAB}go${TAB}Total${TAB}cognitive${TAB}22"
  assert_eq "$ERR" ""
}

go_six_ifs() { printf 'package %s\nfunc F(x int) int {\n\tt := 0\n\tif x > 1 { t++ }\n\tif x > 2 { t++ }\n\tif x > 3 { t++ }\n\tif x > 4 { t++ }\n\tif x > 5 { t++ }\n\tif x > 6 { t++ }\n\treturn t\n}\n' "$1"; }

go_min_one_repo() {
  local repo; repo=$(fixture)
  copy_fixture "$repo" go/cog/go.mod go.mod
  add_file "$repo" .golangci.yml - <<'YML'
version: "2"
linters:
  enable:
    - gocognit
  settings:
    gocognit:
      min-complexity: 1
YML
  add_file "$repo" a/a.go "$(go_six_ifs a)"
  add_file "$repo" c/c.go "$(go_six_ifs c)"
  add_file "$repo" root.go "$(go_six_ifs root)"
  echo "$repo"
}

t_go_golangci_a_broken_package_does_not_hide_offenders_in_the_other_packages() {
  go_tools
  local repo; repo=$(go_min_one_repo)
  add_file "$repo" a/b/b.go 'package b
func B( {'
  commit_all "$repo"
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)" "$SCRIPTS/lang/go.sh" a/a.go a/b/b.go c/c.go root.go
  assert_exit 1
  assert_contains "$OUT" "a/a.go:2${TAB}go${TAB}F${TAB}cognitive${TAB}6"
  assert_contains "$OUT" "c/c.go:2${TAB}go${TAB}F${TAB}cognitive${TAB}6"
  assert_contains "$OUT" "root.go:2${TAB}go${TAB}F${TAB}cognitive${TAB}6"
  assert_eq "$ERR" "complexity: a/b/b.go could not be parsed — unchecked"
}

t_go_golangci_a_broken_package_imported_but_not_requested_leaves_the_requested_ones_measured() {
  go_tools
  local repo; repo=$(go_min_one_repo)
  add_file "$repo" a/b/b.go 'package b
func B( {'
  add_file "$repo" c/c.go "package c
import _ \"example.com/app/a/b\"
$(go_six_ifs c | sed 1d)"
  commit_all "$repo"
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with golangci-lint)" "$SCRIPTS/lang/go.sh" a/a.go c/c.go
  assert_exit 1
  assert_contains "$OUT" "a/a.go:2${TAB}go${TAB}F${TAB}cognitive${TAB}6"
  assert_contains "$OUT" "c/c.go:3${TAB}go${TAB}F${TAB}cognitive${TAB}6"
  assert_eq "$ERR" ""
}

t_go_gocognit_failure_without_a_parse_error_reports_the_tools_message() {
  go_tools
  local repo; repo=$(go_repo)
  commit_all "$repo"
  chmod 000 "$repo/app/mid.go"
  run_in "$repo" env XDG_CACHE_HOME="$(mktmp)" PATH="$(go_path_with gocognit)" "$SCRIPTS/lang/go.sh" app/mid.go app/high.go
  chmod 644 "$repo/app/mid.go"
  assert_exit 6
  assert_contains "$ERR" "permission denied"
  assert_not_contains "$ERR" "Traceback"
}
