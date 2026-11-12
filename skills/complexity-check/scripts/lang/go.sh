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
TAB=$(printf '\t')

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
broken_dirs = set()
if kind == "golangci":
    for i in (data or {}).get("Issues") or []:
        m = re.match(r"cognitive complexity (\d+) of func `(.*)` is high", i["Text"])
        if m:
            rows.append((i["Pos"]["Filename"], i["Pos"]["Line"], m.group(2), m.group(1)))
        elif i.get("FromLinter") == "typecheck":
            rows.append((i["Pos"]["Filename"], 0, None, None))
            broken_dirs.add(os.path.realpath(os.path.dirname(i["Pos"]["Filename"])))
else:
    for i in data or []:
        rows.append((i["Pos"]["Filename"], i["Pos"]["Line"], i["FuncName"], i["Complexity"]))
for name, line, func, score in rows:
    for base in (phys, root):
        rel = want.get(os.path.normpath(os.path.join(base, name)))
        if rel:
            if func is None:
                print("unchecked\t" + rel)
            else:
                print("\t".join([rel + ":" + str(line), "go", func, "cognitive", str(score), limit, src]))
            break
for path, rel in want.items():
    if os.path.realpath(os.path.dirname(path)) in broken_dirs:
        print("unchecked\t" + rel)
' "$@"
}

emit() { # reads JSON on stdin; kind root limit src file...
  local in out hits bad f
  in=$(cat)
  [ -n "$in" ] || return 6
  out=$(printf '%s\n' "$in" | report "$@") || return 6
  hits=$(printf '%s\n' "$out" | grep -v '^unchecked'"$TAB")
  bad=$(printf '%s\n' "$out" | sed -n "s/^unchecked$TAB//p" | sort -u)
  while IFS= read -r f; do
    [ -n "$f" ] && echo "complexity: $f could not be parsed — unchecked" >&2
  done <<EOF2
$bad
EOF2
  [ -n "$hits" ] && { printf '%s\n' "$hits"; return 1; }
  [ -n "$bad" ] && return 2
  return 0
}

if [ -n "$enabled" ]; then
  gl=$(resolve golangci-lint)
  if [ -n "$gl" ]; then
    [ $detect = 1 ] && exit 0
    command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 3; }
    root=$PWD tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-go.XXXXXX") || exit 6
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
    # A typecheck issue stops golangci-lint measuring any package: rerun without the broken ones.
    broken=()
    while :; do
      [ ${#pkgs[@]} -gt 0 ] || { : >"$tmp/out"; break; }
      $gl run "${args[@]}" -- "${pkgs[@]}" >"$tmp/out" 2>"$tmp/err"; status=$?
      if [ $status -gt 1 ]; then cat "$tmp/err" >&2; exit 6; fi
      keep=() dropped=0
      verdicts=$(python3 -I -c '
import json, os, sys
root, pkgs = sys.argv[1], sys.argv[2:]
bad = set()
for i in (json.load(sys.stdin) or {}).get("Issues") or []:
    if i.get("FromLinter") == "typecheck":
        bad.add(os.path.realpath(os.path.dirname(i["Pos"]["Filename"])))
for p in pkgs:
    print(("drop" if os.path.realpath(os.path.join(root, p)) in bad else "keep") + "\t" + p)
if bad and not any(os.path.realpath(os.path.join(root, p)) in bad for p in pkgs):
    sys.exit(1)
' "$root" "${pkgs[@]}" <"$tmp/out") || { echo "golangci-lint reported a syntax error outside the requested packages" >&2; exit 6; }
      while IFS="$TAB" read -r verdict d; do
        case $verdict in keep) keep+=("$d") ;; drop) broken+=("$d"); dropped=1 ;; esac
      done <<EOF_V
$verdicts
EOF_V
      [ $dropped = 0 ] && break
      pkgs=(${keep[@]+"${keep[@]}"})
    done
    unchecked=0
    for f in "$@"; do
      for b in ${broken[@]+"${broken[@]}"}; do
        [ "./$(dirname "$f")" = "$b" ] && { echo "complexity: $f could not be parsed — unchecked" >&2; unchecked=1; }
      done
    done
    [ -s "$tmp/out" ] || printf '{}' >"$tmp/out"
    emit golangci "$root" "$limit" "$src" "$@" <"$tmp/out"; status=$?
    [ $status -eq 6 ] && cat "$tmp/err" >&2
    [ $status -eq 0 ] && [ $unchecked = 1 ] && status=2
    exit $status
  fi
fi

gc=""
if command -v gocognit >/dev/null 2>&1 && gocognit -h 2>&1 | grep -q 'cognitive complexities'; then gc=gocognit; fi
if [ $detect = 1 ]; then
  [ -n "$gc" ] && exit 0
  [ -n "$enabled" ] && { echo "golangci-lint (configured in $enabled) is not installed — install the project's dependencies" >&2; exit 5; }
  exit 4
fi
[ -z "$gc" ] && exit 4
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 3; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-go.XXXXXX") || exit 6
trap 'rm -rf "$tmp"' EXIT
# gocognit stops at the first file that fails to parse and names only that one: rerun on the rest until a run parses.
rest=("$@") badlist=$TAB out="" status=0
while [ ${#rest[@]} -gt 0 ]; do
  out=$($gc -json -over "$limit" "${rest[@]}" 2>"$tmp/err"); status=$?
  named=$(sed -n 's/^gocognit: \(.*\):[0-9][0-9]*:[0-9][0-9]*: .*/\1/p' "$tmp/err" | sort -u)
  [ -n "$named" ] || break
  namedtab="$TAB$(printf '%s' "$named" | tr '\n' "$TAB")$TAB"
  next=()
  for f in "${rest[@]}"; do
    case "$namedtab" in
      *"$TAB$f$TAB"*) badlist="$badlist$f$TAB" ;;
      *) next+=("$f") ;;
    esac
  done
  [ ${#next[@]} -eq ${#rest[@]} ] && break
  rest=(${next[@]+"${next[@]}"})
  out="" status=0
done
[ $status -gt 1 ] && { cat "$tmp/err" >&2; exit 6; }
for f in "$@"; do
  case "$badlist" in *"$TAB$f$TAB"*) echo "complexity: $f could not be parsed — unchecked" >&2 ;; esac
done
rc=0
if [ ${#rest[@]} -gt 0 ]; then
  printf '%s\n' "$out" | emit gocognit "$PWD" "$limit" "$src" "${rest[@]}"; rc=$?
fi
[ $rc -eq 1 ] && exit 1
[ $rc -eq 6 ] && { cat "$tmp/err" >&2; exit 6; }
{ [ $rc -eq 2 ] || [ "$badlist" != "$TAB" ]; } && exit 2
exit 0
