# Tests for scripts/lang/rust.sh (clippy cognitive complexity)

# One shared cargo target dir for the whole run keeps builds out of the fixture repos.
rs_repo() {
  local r; r="$(fixture)"
  copy_fixture "$r" rust/Cargo.toml Cargo.toml
  copy_fixture "$r" "rust/$1.rs" src/lib.rs
  commit_all "$r"
  echo "$r"
}
rs_run() { local r="$1"; shift; CARGO_TARGET_DIR="$TEST_CACHE/rust-target" run_in "$r" "$SCRIPTS/lang/rust.sh" "$@"; }

t_rust_over_default() {
  skip_unless_cmd cargo
  local r; r="$(rs_repo over)"
  rs_run "$r" src/lib.rs
  assert_exit 1
  assert_eq "$OUT" "src/lib.rs:1	rust	over	cognitive	16	15	skill default"
}

t_rust_over_end_to_end() {
  skip_unless_cmd cargo
  local r; r="$(rs_repo over)"
  CARGO_TARGET_DIR="$TEST_CACHE/rust-target" run_in "$r" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_eq "$OUT" "src/lib.rs:1	rust	over	cognitive	16	15	skill default"
}

t_rust_at_limit_passes() {
  skip_unless_cmd cargo
  local r; r="$(rs_repo at_limit)"
  rs_run "$r" src/lib.rs
  assert_exit 0
  assert_eq "$OUT" ""
}

t_rust_project_threshold_wins() {
  skip_unless_cmd cargo
  local r; r="$(rs_repo over)"
  add_file "$r" clippy.toml "cognitive-complexity-threshold = 20"; commit_all "$r"
  rs_run "$r" src/lib.rs
  assert_exit 0
  assert_eq "$OUT" ""
  copy_fixture "$r" rust/over_twenty.rs src/lib.rs
  rs_run "$r" src/lib.rs
  assert_exit 1
  assert_eq "$OUT" "src/lib.rs:1	rust	over_twenty	cognitive	21	20	clippy.toml"
}

t_rust_stale_cache() {
  skip_unless_cmd cargo
  local r; r="$(rs_repo over)"
  rs_run "$r" src/lib.rs
  assert_exit 1
  add_file "$r" clippy.toml "cognitive-complexity-threshold = 20"
  rs_run "$r" src/lib.rs
  assert_exit 0
  assert_eq "$OUT" ""
  add_file "$r" clippy.toml "cognitive-complexity-threshold = 10"
  rs_run "$r" src/lib.rs
  assert_exit 1
  assert_contains "$OUT" "	16	10	clippy.toml"
  rm "$r/clippy.toml"
  rs_run "$r" src/lib.rs
  assert_exit 1
  assert_contains "$OUT" "	16	15	skill default"
}

t_rust_only_given_files() {
  skip_unless_cmd cargo
  local r; r="$(rs_repo over)"
  printf '\npub mod other;\n' >> "$r/src/lib.rs"
  copy_fixture "$r" rust/over_twenty.rs src/other.rs
  rs_run "$r" src/lib.rs
  assert_exit 1
  assert_eq "$OUT" "src/lib.rs:1	rust	over	cognitive	16	15	skill default"
  rs_run "$r" src/other.rs
  assert_exit 1
  assert_eq "$OUT" "src/other.rs:1	rust	over_twenty	cognitive	21	15	skill default"
}

t_rust_tool_missing() {
  local r; r="$(fixture)"
  copy_fixture "$r" rust/over.rs src/lib.rs
  rs_run "$r" src/lib.rs
  assert_exit 3
  assert_contains "$ERR" "no Cargo.toml"
}

t_rust_clippy_missing() {
  local r bin; r="$(rs_repo over)"; bin="$(mktmp)"
  printf '#!/bin/sh\nexit 1\n' > "$bin/cargo"; chmod +x "$bin/cargo"
  PATH="$bin:$PATH" rs_run "$r" src/lib.rs
  assert_exit 3
  assert_contains "$ERR" "cargo clippy not available"
}
