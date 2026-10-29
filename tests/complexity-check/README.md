# complexity-check acceptance tests

Plain bash (macOS bash 3.2 compatible) tests for `skills/complexity-check/scripts/*.sh`
run against throwaway git repos.

    tests/complexity-check/run.sh [filter]   # filter = grep pattern on test names

Output: `PASS name` / `FAIL name: reason` / `SKIP name: reason`, then
`N passed, M failed, K skipped`. Exit 1 if any test failed.

## Adding tests
Create `t_<task>.sh` in this directory. Define functions named `t_*`; `run.sh` sources
every `t_*.sh` and runs each function in its own subshell. Helpers: `fixture`,
`add_file`, `commit_all`, `copy_fixture`, `run_in` (sets `$OUT` `$ERR` `$CODE`),
`assert_contains`, `assert_not_contains`, `assert_eq`, `assert_exit`, `fail`, `skip`,
`skip_unless_cmd`, `need_net`. Static inputs go in `fixtures/`.

## Environment
- `COMPLEXITY_CHECK_NET_TESTS=1` enables tests that call `need_net` (network installs).
- `COMPLEXITY_CHECK_TEST_CACHE` cache dir (default `${TMPDIR:-/tmp}/complexity-check-test-cache`);
  pass `XDG_CACHE_HOME=$TEST_CACHE` to the scripts so `~/.cache` is never touched.
