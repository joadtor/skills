t_reference_matches_limits() {
  local ref="$SCRIPTS/../reference.md" row lang limit expected
  for pair in Ruby:ruby JS/TS:js Python:python Go:go Rust:rust; do
    row=${pair%%:*} lang=${pair##*:}
    limit=$(awk -F'|' -v r="$row" '$2 ~ "^ *"r" *$" { gsub(/ /, "", $5); print $5; exit }' "$ref")
    expected=$(cd "$SCRIPTS" && bash -c '. ./_common.sh; default_limit "$1"' _ "$lang")
    assert_eq "$limit" "$expected" "$row default in reference.md"
  done
}
