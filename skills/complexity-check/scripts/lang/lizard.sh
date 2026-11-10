#!/usr/bin/env bash
# Cognitive complexity for any language via lizard — the fallback when a project has no tool of its own.
# Usage: lizard.sh <file>...   (from the repo root; contract in ../check.sh). Limit: default_limit, source "skill default".
#
# Spike (lizard 1.24.3): `lizard -Ecognitive --csv <abs-file>...` prints one row per function:
#   NLOC,CCN,tokens,params,length,"name@start-end@file","file","name","long name",start,end,COGNITIVE
# Cognitive is the LAST column; the long name contains commas, so rows are parsed from the right and
# the name/file come from the location field. Names are lizard's own and unqualified (no class prefix)
# for TS, Python, Go and Rust alike (`risky`, not `Sample#risky`).
# lizard runs from a temp dir with PYTHONSAFEPATH=1 and no PYTHONPATH so project files (json.py,
# lizard_ext/...) are never imported.
# On broken input lizard prints no row and no warning (exit 0), so a file with no rows is cross-checked with
# its language's own read-only syntax check (python ast, gofmt -e); a failure means "unchecked"
# (exit 2 when nothing was over). JS/TS and Rust have no cheap checker: their parse is not verified.
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

lizard=$(resolve lizard)
[ -n "$lizard" ] || { echo "lizard not installed" >&2; exit 3; }
root=$PWD

args=()
for f in "$@"; do f=${f#./}; args+=("$root/$f"); done

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
(cd "$tmp" && env -u PYTHONPATH PYTHONSAFEPATH=1 PYTHONDONTWRITEBYTECODE=1 "$lizard" -Ecognitive --csv "${args[@]}") >"$tmp/rows" 2>"$tmp/err"
st=$?
[ $st -eq 0 ] || { head -n 3 "$tmp/err" >&2; exit 2; }
over=0 seen=$'\n'
while IFS= read -r row; do
  cog=${row##*,}; rest=${row%,*}
  end=${rest##*,}; rest=${rest%,*}
  start=${rest##*,}
  loc=${row#*,*,*,*,*,\"}
  head=${loc%%@"$start-$end"@*}
  file=${loc#*@"$start-$end"@}; file=${file%%\"*}
  file=${file#"$root"/}
  seen="$seen$file"$'\n'
  lang=$(lang_of "$file")
  limit=$(default_limit "$lang")
  [ "$cog" -gt "$limit" ] || continue
  printf '%s:%s\t%s\t%s\tcognitive\t%s\t%s\tskill default\n' "$file" "$start" "$lang" "$head" "$cog" "$limit"
  over=1
done <"$tmp/rows"

unparsed=0
for f in "$@"; do
  f=${f#./}
  case "$seen" in *$'\n'"$f"$'\n'*) continue ;; esac
  p=$PWD/$f # absolute: never read as an option, and still valid from $tmp
  case $(lang_of "$f") in
    python) command -v python3 >/dev/null 2>&1 && ! python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$p" >/dev/null 2>&1 ;;
    go)     command -v gofmt >/dev/null 2>&1 && ! gofmt -e "$p" >/dev/null 2>&1 ;;
    *)      false ;;
  esac || continue
  echo "complexity: $f could not be parsed — unchecked" >&2
  unparsed=1
done

[ $over -eq 1 ] && exit 1
[ $unparsed -eq 1 ] && exit 2
exit 0
