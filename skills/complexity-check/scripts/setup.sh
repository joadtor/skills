#!/usr/bin/env bash
# Plan and install lizard, the only tool this skill installs. Never prompts: the skill asks the user for consent.
# A project's own tool (ESLint, Biome, complexipy, golangci-lint, cargo clippy) is never installed here.
#
# Usage: setup.sh plan [path...]   one TAB-separated line per thing to ask or report for the languages being checked:
#                                    lang  tool  version  method  scope
#                                  lizard (lang "-") when some language has no usable tool of its own and lizard isn't installed;
#                                  scope: cache | runtime-missing (uv is missing; method says what to install)
#                                  a note row (scope project-tool-missing) when a project configures a tool that isn't installed:
#                                  that language is measured by lizard until the project's own dependencies are installed
#                                  a note row "ruby ruby - install Ruby runtime-missing" when ruby is missing (never lizard)
#        setup.sh install lizard   install lizard into the cache, never into the project
# Exit: plan 0 · install 0 on success, else 1 with a stderr line · 2 no base branch (no path given)
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh" || exit 1
LANG_DIR=${COMPLEXITY_CHECK_LANG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lang}

# Exact pin. 1.25.0 is the current PyPI release (2026-11-05); the cognitive extension needs >= 1.24.3.
LIZARD_VERSION=1.25.0

have() { command -v "$1" >/dev/null 2>&1; }

# <lang> <file>... — exit status of the language's --detect: 0 own tool ready, 4 none configured, 5 configured but missing
# (stderr line is left in $detect_err). For Ruby, 5 means ruby itself is missing: Ruby never needs lizard.
detect() {
  local lang=$1; shift
  detect_err=""
  [ -x "$LANG_DIR/$lang.sh" ] || return 4
  detect_err=$("$LANG_DIR/$lang.sh" --detect "$@" 2>&1 >/dev/null)
}

plan() {
  local files a lang list needs_lizard=0 st tool method scope
  files=$(target_files "$@") || return 2
  files=$({ printf '%s\n' "$files"; for a in "$@"; do printf '%s\n' "$a" | grep -Ev "$SKIP_RE"; done; } | grep -v '^$')
  for lang in ruby js python go rust; do
    list=$(while IFS= read -r f; do [ "$(lang_of "$f")" = "$lang" ] && printf '%s\n' "$f"; done <<EOF2
$files
EOF2
    )
    [ -n "$list" ] || continue
    set --
    while IFS= read -r f; do set -- "$@" "$f"; done <<EOF2
$list
EOF2
    detect "$lang" "$@"; st=$?
    case $lang:$st in
      *:0) ;;
      ruby:5) printf 'ruby\truby\t-\tinstall Ruby\truntime-missing\n' ;;
      *:5) tool=${detect_err%% (configured*}
         printf '%s\t%s\t-\tinstall the project'"'"'s dependencies\tproject-tool-missing\n' "$lang" "$tool"
         needs_lizard=1 ;;
      *) needs_lizard=1 ;;
    esac
  done
  [ $needs_lizard = 1 ] && [ -z "$(resolve lizard)" ] || return 0
  method="uv tool install lizard==$LIZARD_VERSION into $CACHE" scope=cache
  if ! { have uv && uv --version >/dev/null 2>&1; }; then method="install uv first" scope=runtime-missing; fi
  printf -- '-\tlizard\t%s\t%s\t%s\n' "$LIZARD_VERSION" "$method" "$scope"
}

install_lizard() {
  have uv || { echo "setup: lizard not installed: uv is missing" >&2; return 1; }
  mkdir -p "$CACHE/bin" || return 1
  # From the cache, never the project: a repo's uv.toml or pyproject must not choose what gets installed.
  local err
  if ! err=$(cd "$CACHE" && UV_TOOL_DIR="$CACHE/uv" UV_TOOL_BIN_DIR="$CACHE/bin" uv tool install --no-config \
    --default-index https://pypi.org/simple "lizard==$LIZARD_VERSION" 2>&1 >/dev/null); then
    echo "setup: lizard install failed: $(printf '%s' "$err" | grep -v '^$' | tail -n 1)" >&2
    return 1
  fi
}

install() {
  local tool status=0
  for tool in "$@"; do
    case "$tool" in
      lizard) install_lizard || status=1 ;;
      *) echo "setup: unknown tool: $tool" >&2; status=1 ;;
    esac
  done
  return $status
}

case "${1:-}" in
  plan)    shift; plan "$@"; exit $? ;;
  install) shift; install "$@" ;;
  *) echo "usage: setup.sh plan [path...] | install lizard" >&2; exit 2 ;;
esac
