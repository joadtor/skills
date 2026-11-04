# Shared plumbing for check.sh and setup.sh — sourced, never run directly.
#
# On source: cd to the repo top level and set CACHE (not created here).
#   base_branch          echo the base: first of develop, master, main on origin, else origin's default branch (local ref, no network)
#   target_files [path...]
#                        repo-relative production files, sorted, unique, existing
#                        no path: changed vs merge-base with origin/<base> + untracked non-ignored;
#                                 exit 2 with a stderr message if origin/<base> or the merge-base can't be found
#                        paths:   every tracked + untracked non-ignored file under each
#                                 (relative paths are relative to where the script was started)
#   lang_of <file>       ruby | js | python | go | rust | (empty)
#   default_limit <lang> per-function complexity ceiling for the language
#   resolve <tool>       command to run: project-local, then PATH, then $CACHE/bin; empty if none
PREFIX=$(git rev-parse --show-prefix) || return 1
cd "$(git rev-parse --show-toplevel)" || return 1
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/joadtor/complexity-check"

base_branch() {
  local b
  b=$(for b in develop master main; do
    git rev-parse --verify --quiet "origin/$b" >/dev/null && echo "$b" && break
  done)
  [ -z "$b" ] && b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  echo "$b"
}

target_files() {
  # Not production code: tests, fixtures, vendored or generated output, migrations, config and data files.
  local skip='(^|/)(spec|test|tests|__tests__|__mocks__|fixtures?|features|node_modules|vendor|dist|build|target|coverage|db/migrate)/|(_spec|_test|\.test|\.spec|\.stories|\.config|\.d)\.[a-z]+$|(^|/)(schema\.rb|conftest\.py|setup\.py)$|(^|/)test_[^/]*\.py$|\.(json|ya?ml|toml|lock|md|txt|csv|snap|min\.js)$'
  local f a mb
  if [ $# -gt 0 ]; then
    for a in "$@"; do
      case $a in
        "$PWD"/*) a=${a#"$PWD"/} ;;
        /*) ;;
        .) a=${PREFIX%/}; a=${a:-.} ;;
        *) a=$PREFIX$a ;;
      esac
      set -- "$@" "$a"; shift
    done
  else
    mb=$(git merge-base "origin/$(base_branch)" HEAD 2>/dev/null) || mb=""
    [ -n "$mb" ] || { echo "complexity: can't find the base branch on origin — pass a path or fetch origin" >&2; return 2; }
  fi
  {
    if [ $# -gt 0 ]; then
      git ls-files -- "$@"; git ls-files --others --exclude-standard -- "$@"
    else
      git diff --name-only --diff-filter=AMR "$mb"; git ls-files --others --exclude-standard
    fi
  } | grep -Ev "$skip" | sort -u | while IFS= read -r f; do
    [ -f "$f" ] || continue
    case $f in -*) f=./$f ;; esac # a repo file must never be parsed as a tool's option
    printf '%s\n' "$f"
  done
}

lang_of() {
  case "${1##*.}" in
    rb)                     echo ruby ;;
    js|jsx|mjs|cjs|ts|tsx) echo js ;;
    py)                     echo python ;;
    go)                     echo go ;;
    rs)                     echo rust ;;
  esac
}

default_limit() {
  case "$1" in
    ruby) echo 8 ;;
    js|python|go) echo 10 ;;
    rust) echo 15 ;;
  esac
}

probe_tool() {
  local st
  case "$1" in
    gocyclo) "$1" -over 1000 /dev/null >/dev/null 2>&1; st=$?; [ $st -le 1 ] ;;
    *) "$1" --version >/dev/null 2>&1 ;;
  esac
}

resolve() {
  case "$1" in
    rubocop) grep -q ' rubocop (' Gemfile.lock 2>/dev/null && { echo "bundle exec rubocop"; return; } ;;
    eslint)  [ -x node_modules/.bin/eslint ] && { echo node_modules/.bin/eslint; return; } ;;
  esac
  # A version-manager shim (nodenv, rbenv, asdf) is on PATH even when the tool isn't installed — it must run.
  # gocyclo has no --version: parsing an empty file exits 1 for the real binary, a broken shim exits 126/127.
  if command -v "$1" >/dev/null 2>&1 && probe_tool "$1"; then echo "$1"
  elif [ -x "$CACHE/bin/$1" ]; then echo "$CACHE/bin/$1"
  fi
  return 0
}
