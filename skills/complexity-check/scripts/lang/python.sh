#!/usr/bin/env bash
# Python complexity: radon cc cyclomatic complexity.
# Usage: python.sh <file>...   (contract: see ../check.sh)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

limit=$(default_limit python)
src="skill default"

# First project config that sets max-complexity wins: ruff (pyproject, ruff.toml), then flake8.
found=$(python3 -I -c '
import configparser, os, re, sys
try:
    import tomllib
except ImportError:
    tomllib = None

def toml(path, tables):
    if tomllib:
        with open(path, "rb") as fh:
            data = tomllib.load(fh)
        for t in tables:
            node = data
            for k in t:
                node = node.get(k, {}) if isinstance(node, dict) else {}
            if isinstance(node, dict) and "max-complexity" in node:
                return node["max-complexity"]
        return None
    section = None
    for line in open(path):
        m = re.match(r"\s*\[([^\]]+)\]", line)
        if m:
            section = m.group(1).strip()
            continue
        m = re.match(r"\s*max-complexity\s*=\s*(\d+)", line)
        if m and section in [".".join(t) for t in tables]:
            return int(m.group(1))

def ini(path):
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(path)
    if cp.has_option("flake8", "max-complexity"):
        return cp.get("flake8", "max-complexity")

checks = [
    ("pyproject.toml", lambda p: toml(p, [("tool", "ruff", "lint", "mccabe"), ("tool", "ruff", "mccabe")])),
    ("ruff.toml", lambda p: toml(p, [("lint", "mccabe"), ("mccabe",)])),
    (".ruff.toml", lambda p: toml(p, [("lint", "mccabe"), ("mccabe",)])),
    ("setup.cfg", ini), (".flake8", ini), ("tox.ini", ini),
]
for name, fn in checks:
    if os.path.isfile(name):
        try:
            v = fn(name)
        except Exception:
            v = None
        if v is not None:
            print("%s\t%s" % (int(v), name))
            break
')
if [ -n "$found" ]; then
  limit=${found%%$'\t'*}
  src=${found#*$'\t'}
fi

run=$(resolve radon)
[ -z "$run" ] && { echo "radon not found" >&2; exit 3; }

out=$($run cc -j "$@") || exit 2

hits=$(printf '%s\n' "$out" | python3 -I -c '
import json, sys
limit, src = int(sys.argv[1]), sys.argv[2]
seen = set()
def walk(f, blocks):
    for b in blocks:
        if b["type"] != "class" and b["complexity"] > limit:
            name = b["classname"] + "." + b["name"] if b.get("classname") else b["name"]
            if (f, b["lineno"], name) not in seen:
                seen.add((f, b["lineno"], name))
                print("\t".join(["%s:%d" % (f, b["lineno"]), "python", name, "cyclomatic", str(b["complexity"]), str(limit), src]))
        walk(f, b.get("methods", []))
        walk(f, b.get("closures", []))
for f, blocks in json.load(sys.stdin).items():
    walk(f, blocks if isinstance(blocks, list) else [])
' "$limit" "$src") || exit 2

[ -z "$hits" ] && exit 0
printf '%s\n' "$hits"
exit 1
