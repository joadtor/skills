ruby_body() {
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    echo "# filler $i"
    echo "def f$i(a, b)"
    echo "  a + b"
    echo "end"
  done
}

t_multi_hunk_file_yields_candidates_from_both_hunks() {
  local repo; repo=$(fixture)
  ruby_body | add_file "$repo" lib/calc.rb -
  commit_all "$repo" base
  (cd "$repo" && git push -q origin feature:main)
  ruby_body | sed -e '3s/a + b/a - b - 1/' -e '35s/a + b/a * b + 7/' | add_file "$repo" lib/calc.rb -
  commit_all "$repo" edit
  run_in "$repo" "$FINDER" main
  assert_exit 0
  assert_contains "$OUT" "lib/calc.rb:3"
  assert_contains "$OUT" "lib/calc.rb:35"
}

t_rust_tests_rs_module_is_not_production() {
  local repo; repo=$(fixture)
  add_file "$repo" src/util/tests.rs 'fn t(a: i32, b: i32) { if a == b { return; } }'
  add_file "$repo" src/util/mod.rs 'fn m(a: i32, b: i32) { if a == b { return; } }'
  add_file "$repo" src/util/test_support.rs 'fn s(a: i32, b: i32) { if a == b { return; } }'
  commit_all "$repo"
  run_in "$repo" "$FINDER" main
  assert_exit 0
  assert_contains "$OUT" "src/util/mod.rs"
  assert_not_contains "$OUT" "tests.rs"
  assert_not_contains "$OUT" "test_support.rs"
}

t_base_can_be_a_commit_sha() {
  local repo sha; repo=$(fixture)
  add_file "$repo" lib/old.rb 'x = a == b ? 1 : 2'
  commit_all "$repo" old
  sha=$(cd "$repo" && git rev-parse HEAD)
  add_file "$repo" lib/new.rb 'y = a == b ? 1 : 2'
  commit_all "$repo" new
  run_in "$repo" "$FINDER" "$sha"
  assert_exit 0
  assert_contains "$OUT" "lib/new.rb"
  assert_not_contains "$OUT" "lib/old.rb"
}

t_unknown_base_fails_with_a_clear_message() {
  local repo; repo=$(fixture)
  add_file "$repo" lib/a.rb 'x = a == b ? 1 : 2'
  commit_all "$repo"
  run_in "$repo" "$FINDER" no-such-ref
  [ "$CODE" != 0 ] || fail "expected non-zero exit"
  assert_contains "$ERR" "no-such-ref"
  assert_contains "$ERR" "not a branch on origin or a commit"
}

t_no_argument_defaults_to_origin_main() {
  local repo; repo=$(fixture)
  add_file "$repo" lib/a.rb 'x = a == b ? 1 : 2'
  commit_all "$repo"
  run_in "$repo" "$FINDER"
  assert_exit 0
  assert_contains "$OUT" "lib/a.rb:1"
  assert_contains "$ERR" "base origin/main"
}
