#!/usr/bin/env bash
# Complexity check — lists functions over the per-language limit. Installs nothing, uses no network.
#
# Usage: check.sh [path...]
#   No path: the changed code (vs the merge-base with origin/<base>, plus untracked files).
#   Paths:   everything under each (files or directories).
#   Files are grouped by language and each language present is handed to its script.
#
# Language-script contract — lang/<lang>.sh <file>..., run from the repo root
#   (dir overridable with COMPLEXITY_CHECK_LANG_DIR). A script may source ../_common.sh and owns its own
#   limit precedence: the project's config if any, else default_limit.
#   stdout  one offender per line, TAB-separated, 7 fields:
#           file:line  lang  function  metric  score  limit  source   (source: where the limit came from,
#           e.g. "skill default", ".rubocop.yml")
#   stderr  notices to pass through (e.g. "project .rubocop.yml bypassed")
#   exit    0 nothing over · 1 offenders printed · 3 tool missing (first stderr line = reason)
#           · anything else = the tool failed
#
# stdout: the offender lines, unchanged.
# stderr: language notices; one "skipped <Lang> (<reason>) — unchecked: <files>" per skipped language; a summary.
# Exit 1 if any function is over its limit, else 0 — a skipped language alone never fails.
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh" || exit 1
LANG_DIR=${COMPLEXITY_CHECK_LANG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lang}

pretty() {
  case "$1" in
    ruby) echo Ruby ;; js) echo JS/TS ;; python) echo Python ;; go) echo Go ;; rust) echo Rust ;;
  esac
}

over=0 skipped=0
skip() { skipped=$((skipped + 1)); echo "complexity: skipped $(pretty "$1") ($2) — unchecked: $3" >&2; }

files=$(target_files "$@") || exit 2
for lang in ruby js python go rust; do
  list=$(while IFS= read -r f; do
    [ -n "$f" ] && [ "$(lang_of "$f")" = "$lang" ] && printf '%s\n' "$f"
  done <<EOF2
$files
EOF2
  )
  [ -z "$list" ] && continue
  set --
  while IFS= read -r f; do set -- "$@" "$f"; done <<EOF2
$list
EOF2
  if [ ! -x "$LANG_DIR/$lang.sh" ]; then
    skip "$lang" "not supported" "$*"
    continue
  fi
  errf=$(mktemp "${TMPDIR:-/tmp}/cc-err.XXXXXX")
  out=$("$LANG_DIR/$lang.sh" "$@" 2>"$errf"); status=$?
  reason=$(head -n 1 "$errf")
  [ $status -ne 3 ] && [ -s "$errf" ] && cat "$errf" >&2
  rm -f "$errf"
  case $status in
    0|1) [ -n "$out" ] && { printf '%s\n' "$out"; over=$((over + $(printf '%s\n' "$out" | wc -l))); } ;;
    3)   case $reason in
           *"not found"*|*"not installed"*|*"not available"*) skip "$lang" "$reason — run setup" "$*" ;;
           *) skip "$lang" "${reason:-no tool}" "$*" ;;
         esac ;;
    *)   skip "$lang" "tool failed, exit $status" "$*" ;;
  esac
done

note=""
[ $skipped -gt 0 ] && note=" — $skipped language(s) skipped"
if [ $over -gt 0 ]; then
  echo "complexity: $over function(s) over the limit$note" >&2
  exit 1
fi
echo "complexity: clean$note" >&2
