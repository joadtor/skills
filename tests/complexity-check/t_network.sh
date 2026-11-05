# Proof that checking never sends anything off the machine: outbound network is denied by the OS.

t_check_no_network_sandboxed() {
  command -v sandbox-exec >/dev/null 2>&1 || skip "sandbox-exec not available (macOS only)"
  local r ext dir profile='(version 1)(allow default)(deny network-outbound (remote ip))'
  r="$(lizard_repo)" || exit $?
  for pair in rb:ruby ts:ts py:py go:go rs:rs; do
    ext=${pair%%:*} dir=${pair##*:}
    copy_fixture "$r" "cognitive/$dir/over.$ext" "src/over.$ext"
  done
  commit_all "$r"

  sandbox-exec -p "$profile" /bin/sh -c 'curl -s -m 5 https://pypi.org >/dev/null' 2>/dev/null &&
    fail "the sandbox did not block the network, so the proof would prove nothing"

  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" "$SCRIPTS/check.sh"
  local open_out=$OUT
  run_in "$r" env XDG_CACHE_HOME="$TEST_CACHE" sandbox-exec -p "$profile" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_not_contains "$ERR" "skipped"
  for ext in rb ts py go rs; do assert_contains "$OUT" "src/over.$ext:"; done
  assert_eq "$OUT" "$open_out" "same result with the network blocked"
}
