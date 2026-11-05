#!/usr/bin/env bash
# Go complexity: gocognit cognitive complexity, through the project's golangci-lint when its
# .golangci.yml enables gocognit, else a gocognit on the PATH (limit 15), else exit 4.
# Usage: go.sh [--detect] <file>...   (contract: see ../check.sh)
#   --detect  measure nothing: exit 0 = configured and runnable, 4 = not configured,
#             5 = configured but golangci-lint is not installed (one stderr line)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

detect=0
[ "${1:-}" = --detect ] && { detect=1; shift; }

# Both tools report a function when score > limit (golangci: "(> N)", gocognit: -over N).
# golangci-lint ignores `go` downloads: GOPROXY=off so it can never fetch a module.
export GOPROXY=off GOFLAGS=

limit=$(default_limit go) src="skill default" enabled="" configured=""

# v1: linters > enable, linters-settings > gocognit > min-complexity
# v2: linters > enable, linters > settings > gocognit > min-complexity. Indentation-aware, no yq.
for cfg in .golangci.yml .golangci.yaml; do
  [ -f "$cfg" ] || continue
  facts=$(awk '
    /^[ ]*(#|$)/ { next }
    function parent(ind,   d, p) { p = ""; for (d = 0; d <= ind; d++) if (d in path) p = p "/" path[d]; return p }
    /^[ ]*- / {
      match($0, /^ */); item = $0; sub(/^[ ]*- +/, "", item); sub(/[ ]*#.*/, "", item); gsub(/["\047]/, "", item)
      if (item == "gocognit" && parent(RLENGTH) == "/linters/enable") print "enabled"
      next
    }
    { match($0, /^ */); ind = RLENGTH; key = $0; sub(/^ +/, "", key); sub(/:.*/, "", key) }
    { for (d in path) if (d + 0 >= ind) delete path[d]; path[ind] = key }
    { v = $0; sub(/^[^:]*:[ ]*/, "", v); sub(/[ ]*#.*/, "", v) }
    key == "enable" && parent(ind) == "/linters/enable" && v ~ /(^|[\[ ,"\047])gocognit([\] ,"\047]|$)/ { print "enabled" }
    key == "min-complexity" {
      p = parent(ind - 1)
      if (p == "/linters-settings/gocognit" || p == "/linters/settings/gocognit") print "min " v
    }' "$cfg")
  case $facts in *enabled*) enabled=$cfg ;; esac
  n=$(printf '%s\n' "$facts" | sed -n 's/^min //p' | head -n 1)
  case $n in ''|*[!0-9]*) ;; *) configured=$n ;; esac
  break
done

# helper: python3 -I reads the tool's JSON on stdin and prints the 7-column TSV
# args: kind root limit src file...
report() {
  python3 -I -c '
import json, os, re, sys
kind, root, limit, src = sys.argv[1:5]
files = sys.argv[5:]
phys = os.path.realpath(root)
want = {}
for f in files:
    for base in (root, phys):
        want[os.path.normpath(os.path.join(base, f))] = f
data = json.load(sys.stdin)
rows = []
if kind == "golangci":
    for i in (data or {}).get("Issues") or []:
        m = re.match(r"cognitive complexity (\d+) of func `(.*)` is high", i["Text"])
        if m:
            rows.append((i["Pos"]["Filename"], i["Pos"]["Line"], m.group(2), m.group(1)))
else:
    for i in data or []:
        rows.append((i["Pos"]["Filename"], i["Pos"]["Line"], i["FuncName"], i["Complexity"]))
for name, line, func, score in rows:
    for base in (phys, root):
        rel = want.get(os.path.normpath(os.path.join(base, name)))
        if rel:
            print("\t".join([rel + ":" + str(line), "go", func, "cognitive", str(score), limit, src]))
            break
' "$@"
}

emit() { # reads JSON on stdin; kind root limit src file...
  local out
  out=$(report "$@") || return 2
  [ -n "$out" ] && { printf '%s\n' "$out"; return 1; }
  return 0
}

if [ -n "$enabled" ]; then
  gl=$(resolve golangci-lint)
  if [ -n "$gl" ]; then
    [ $detect = 1 ] && exit 0
    command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 3; }
    root=$PWD tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-go.XXXXXX") || exit 2
    trap 'rm -rf "$tmp"' EXIT
    pkgs=() # one ./dir per line, deduplicated without word splitting (dirs may hold spaces or globs)
    while IFS= read -r d; do pkgs+=("$d"); done < <(for f in "$@"; do printf './%s\n' "$(dirname "$f")"; done | sort -u)
    ver=$($gl --version 2>&1 | sed -n 's/.*version v\{0,1\}\([0-9][0-9]*\)\..*/\1/p' | head -n 1)
    # Never the repo's own config: it can load plugins (code). Only its numeric min-complexity is carried over.
    [ -n "$configured" ] && limit=$configured src=$enabled
    if [ "$ver" = 1 ]; then
      printf 'run:\n  relative-path-mode: wd\nlinters:\n  disable-all: true\n  enable:\n    - gocognit\nlinters-settings:\n  gocognit:\n    min-complexity: %s\n' "$limit" > "$tmp/c.yml"
    else
      printf 'version: "2"\nlinters:\n  default: none\n  enable:\n    - gocognit\n  settings:\n    gocognit:\n      min-complexity: %s\n' "$limit" > "$tmp/c.yml"
    fi
    args=(-c "$tmp/c.yml")
    if [ "$ver" = 1 ]; then
      args+=(--out-format json)
    else
      args+=(--output.json.path stdout --output.text.path /dev/null --show-stats=false --path-mode abs)
    fi
    $gl run "${args[@]}" -- "${pkgs[@]}" >"$tmp/out" 2>"$tmp/err"; status=$?
    if [ $status -gt 1 ]; then head -n 3 "$tmp/err" >&2; exit 2; fi
    emit golangci "$root" "$limit" "$src" "$@" <"$tmp/out"; status=$?
    exit $status
  fi
fi

gc=""
if command -v gocognit >/dev/null 2>&1 && gocognit -h 2>&1 | grep -q 'cognitive complexities'; then gc=gocognit
elif [ -x "$CACHE/bin/gocognit" ]; then gc="$CACHE/bin/gocognit"
fi
if [ $detect = 1 ]; then
  [ -n "$gc" ] && exit 0
  [ -n "$enabled" ] && { echo "golangci-lint (configured in $enabled) is not installed — install the project's dependencies" >&2; exit 5; }
  exit 4
fi
[ -z "$gc" ] && exit 4
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 3; }

out=$($gc -json -over "$limit" "$@" 2>/dev/null); status=$?
[ $status -gt 1 ] && exit 2
printf '%s\n' "$out" | emit gocognit "$PWD" "$limit" "$src" "$@"
