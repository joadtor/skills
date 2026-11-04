#!/usr/bin/env bash
# Rust: clippy::cognitive_complexity. Usage: rust.sh <file>... (from the repo root; see check.sh for the contract)
# Only a crate whose Cargo.toml is at the repo root is checked; crates in subfolders are not supported.
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

# Never download: no crates (CARGO_NET_OFFLINE) and no toolchain (RUSTUP_AUTO_INSTALL=0, e.g. a repo rust-toolchain.toml).
export CARGO_NET_OFFLINE=true RUSTUP_AUTO_INSTALL=0

[ -f Cargo.toml ] || { echo "no Cargo.toml at the repo root" >&2; exit 3; }
if ! cargo clippy --version >/dev/null 2>&1; then
  for tf in rust-toolchain.toml rust-toolchain; do
    [ -f "$tf" ] || continue
    chan=$(sed -n 's/^[[:space:]]*channel[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$tf" | head -n 1)
    [ -z "$chan" ] && chan=$(head -n 1 "$tf" | tr -d '[:space:]')
    echo "the project's pinned toolchain ($tf) has no clippy — rustup component add clippy --toolchain $chan" >&2
    exit 3
  done
  echo "cargo clippy not available" >&2; exit 3
fi

# No cache busting needed: clippy tracks CLIPPY_CONF_DIR and the clippy.toml contents, so cargo re-checks the crate
# when the threshold changes (verified in t_rust_stale_cache). Touching sources or cleaning target/ is not required.
limit=$(default_limit rust); source="skill default"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for f in clippy.toml .clippy.toml; do
  [ -f "$f" ] || continue
  n=$(sed -n 's/^[[:space:]]*cognitive-complexity-threshold[[:space:]]*=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$f" | head -n 1)
  [ -n "$n" ] && { limit=$n; source=clippy.toml; }
  break
done
conf=$PWD
if [ "$source" != clippy.toml ]; then
  conf=$tmp
  printf 'cognitive-complexity-threshold = %s\n' "$limit" > "$tmp/clippy.toml"
fi

out=$(CLIPPY_CONF_DIR="$conf" cargo clippy --quiet --message-format=json -- -W clippy::cognitive_complexity); status=$?
[ $status -ne 0 ] && { echo "cargo clippy failed (offline: dependencies must already be in the local cargo registry)" >&2; exit 2; }

hits=$(printf '%s\n' "$out" | python3 -I -c '
import json, re, sys
limit, source = sys.argv[1], sys.argv[2]
files = set(sys.argv[3:])
for line in sys.stdin:
    try:
        m = json.loads(line)
    except ValueError:
        continue
    d = m.get("message")
    if not d or (d.get("code") or {}).get("code") != "clippy::cognitive_complexity":
        continue
    s = next((s for s in d["spans"] if s["is_primary"]), None)
    c = re.search(r"complexity of \((\d+)/", d["message"])
    if not s or not c or s["file_name"] not in files:
        continue
    name = re.search(r"fn\s+(\w+)", s["text"][0]["text"])
    print("\t".join(["%s:%d" % (s["file_name"], s["line_start"]), "rust", name.group(1) if name else "?",
                     "cognitive", c.group(1), limit, source]))
' "$limit" "$source" "$@")
[ -n "$hits" ] && { printf '%s\n' "$hits"; exit 1; }
exit 0
