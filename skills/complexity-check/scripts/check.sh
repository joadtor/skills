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
#   limit precedence: the project's own configured cognitive tool if any, else it exits 4.
#   stdout  one offender per line, TAB-separated, 7 fields:
#           file:line  lang  function  metric  score  limit  source   (metric is always "cognitive";
#           source: where the limit came from, e.g. "skill default", "pyproject.toml")
#   stderr  notices to pass through (e.g. "<file> could not be parsed — unchecked")
#   exit    0 nothing over · 1 offenders printed · 3 tool missing (first stderr line = reason)
#           · 4 the project has no configured cognitive tool of its own -> check.sh sends that
#             language's files to lang/lizard.sh, which follows this same contract (without 4)
#           · anything else = the tool failed
#   A language with no lang/<lang>.sh goes straight to lang/lizard.sh; if that is missing or not
#   executable the language is skipped ("not supported").
#
# stdout: the offender lines, unchanged.
# stderr: language notices; one "skipped <Lang> (<reason>) — unchecked: <files>" per skipped language; a summary.
# Exit 1 if any function is over its limit, else 0 — a skipped language alone never fails.
#      2 no base branch (no path given)
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh" || exit 1
LANG_DIR=${COMPLEXITY_CHECK_LANG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lang}

pretty() {
  case "$1" in
    ruby) echo Ruby ;; js) echo JS/TS ;; python) echo Python ;; go) echo Go ;; rust) echo Rust ;;
  esac
}

over=0 skipped=0
skip() { skipped=$((skipped + 1)); echo "complexity: skipped $(pretty "$1") ($2) — unchecked: $3" >&2; }

# run_script <script> <file>... — sets status, out, reason; forwards the script's notices
run_script() {
  local script=$1 errf; shift
  if [ ! -x "$script" ]; then status=3 out="" reason="not supported"; return; fi
  errf=$(mktemp "${TMPDIR:-/tmp}/cc-err.XXXXXX")
  out=$("$script" "$@" 2>"$errf"); status=$?
  reason=$(head -n 1 "$errf")
  [ $status -ne 3 ] && [ -s "$errf" ] && cat "$errf" >&2
  rm -f "$errf"
}

# finish <lang> <file>... — reports the last run_script result
finish() {
  local lang=$1; shift
  case $status in
    0|1) [ -n "$out" ] && { printf '%s\n' "$out"; over=$((over + $(printf '%s\n' "$out" | wc -l))); } ;;
    3)   case $reason in
           *"not found"*|*"not installed"*|*"not available"*) skip "$lang" "$reason — run setup" "$*" ;;
           *) skip "$lang" "${reason:-no tool}" "$*" ;;
         esac ;;
    *)   skip "$lang" "tool failed, exit $status" "$*" ;;
  esac
}

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
  script="$LANG_DIR/$lang.sh"
  [ -x "$script" ] || script="$LANG_DIR/lizard.sh"
  run_script "$script" "$@"
  if [ $status -eq 4 ]; then
    run_script "$LANG_DIR/lizard.sh" "$@"
  fi
  finish "$lang" "$@"
done

note=""
[ $skipped -gt 0 ] && note=" — $skipped language(s) skipped"
if [ $over -gt 0 ]; then
  echo "complexity: $over function(s) over the limit$note" >&2
  exit 1
fi
echo "complexity: clean$note" >&2
