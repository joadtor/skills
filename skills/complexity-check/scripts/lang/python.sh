#!/usr/bin/env bash
# Python cognitive complexity: the project's own complexipy, when pyproject.toml configures it.
# Usage: python.sh [--detect] <file>...   (contract: see ../check.sh)
#   --detect  measure nothing: exit 0 = configured and runnable, 4 = not configured,
#             5 = configured but complexipy is not installed (one stderr line)
#
# complexipy 8.x: `--output-format gitlab --output <file>` writes the offenders (score > max) as JSON with
# the start line and "has cognitive complexity N" in the description; the plain json format has no line.
# It writes complexipy-results.json and .complexipy_cache into the cwd unless --output and --cache-dir
# point elsewhere, so both go to a temp dir. Exit 1 = offenders found.
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

detect=0
[ "${1:-}" = --detect ] && { detect=1; shift; }

limit=$(default_limit python)
src="skill default"

# Prints "configured" when pyproject.toml has a [tool.complexipy] table, then its integer limit if it sets one.
cfg=$(python3 -I -c '
import re
try:
    import tomllib
except ImportError:
    tomllib = None

def limit_of(v):
    return str(v) if isinstance(v, int) and not isinstance(v, bool) and v >= 0 else ""

try:
    if tomllib:
        with open("pyproject.toml", "rb") as fh:
            table = tomllib.load(fh).get("tool", {}).get("complexipy")
        if isinstance(table, dict):
            print("configured\t" + limit_of(table.get("max-complexity-allowed")))
    else:
        inside = found = False
        val = ""
        for line in open("pyproject.toml"):
            m = re.match(r"\s*\[([^\]]+)\]", line)
            if m:
                inside = m.group(1).strip() == "tool.complexipy"
                found = found or inside
                continue
            m = re.match(r"\s*max-complexity-allowed\s*=\s*(\d+)\s*(#.*)?$", line)
            if inside and m:
                val = m.group(1)
        if found:
            print("configured\t" + val)
except (OSError, ValueError):
    pass
')
[ -n "$cfg" ] || exit 4
if [ -n "${cfg#*$'\t'}" ]; then
  limit=${cfg#*$'\t'}
  src="pyproject.toml"
fi

tool=""
for c in .venv/bin/complexipy venv/bin/complexipy; do
  c=$(local_tool "$c")
  [ -n "$c" ] && "$c" --version >/dev/null 2>&1 && { tool=$c; break; }
done
if [ -z "$tool" ] && command -v complexipy >/dev/null 2>&1 && complexipy --version >/dev/null 2>&1; then
  tool=complexipy
fi
if [ $detect = 1 ]; then
  [ -n "$tool" ] && exit 0
  echo "complexipy (configured in pyproject.toml) is not installed — install the project's dependencies" >&2
  exit 5
fi
[ -n "$tool" ] || { echo "complexipy not installed (configured in pyproject.toml)" >&2; exit 3; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-py.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
"$tool" --quiet --isolated --output-format gitlab --output "$tmp/out.json" --cache-dir "$tmp/cache" \
  --max-complexity-allowed "$limit" "$@" >/dev/null
st=$?
[ $st -le 1 ] || exit 2

hits=$(python3 -I -c '
import json, re, sys
limit, src = sys.argv[1], sys.argv[2]
for r in json.load(open(sys.argv[3])):
    m = re.match(r"Function \x27(.*)\x27 has cognitive complexity (\d+)", r["description"])
    print("\t".join(["%s:%d" % (r["location"]["path"], r["location"]["lines"]["begin"]), "python",
                     m.group(1).replace("::", "."), "cognitive", m.group(2), limit, src]))
' "$limit" "$src" "$tmp/out.json") || exit 2

[ -z "$hits" ] && exit 0
printf '%s\n' "$hits"
exit 1
