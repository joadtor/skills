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
#   local_tool <path>    a repo-local tool binary if executable and not committed to git; empty otherwise
#   resolve <tool>       command to run: project-local, then PATH, then $CACHE/bin; empty if none
#                        (a PATH lizard older than 1.24.3, or with an unreadable version, is skipped)
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

# Not production code: tests, fixtures, vendored or generated output, migrations, config and data files.
SKIP_RE='^features/|(^|/)(spec|test|tests|__tests__|__mocks__|fixtures?|node_modules|vendor|dist|build|target|coverage|db/migrate)/|(_spec|_test|\.test|\.spec|\.stories|\.config|\.d)\.[a-z]+$|(^|/)(schema\.rb|conftest\.py|setup\.py)$|(^|/)test_[^/]*\.py$|\.(json|ya?ml|toml|lock|md|txt|csv|snap|min\.js)$'

target_files() {
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
  } | grep -Ev "$SKIP_RE" | sort -u | while IFS= read -r f; do
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
    ruby|js|python|go|rust) echo 15 ;;
  esac
}


# A tool the project installed inside the repo (node_modules/.bin, .venv/bin): echo it only if it is
# executable, its top directory is gitignored, no part of its path is committed (a committed binary or a
# committed symlink was planted), and its real path is outside the repo or untracked. Any git error = unsafe.
local_tool() {
  local p=$1 pre real rel
  [ -x "$p" ] || return 0
  git check-ignore -q -- "${p%%/*}" 2>/dev/null || return 0
  for pre in "$p" "$(dirname "$p")" "${p%%/*}"; do
    git ls-files --error-unmatch -- "$pre" >/dev/null 2>&1 && return 0
  done
  real=$(cd "$(dirname "$p")" 2>/dev/null && pwd -P) || return 0
  case $real/ in
    "$(pwd -P)"/*)
      rel=${real#"$(pwd -P)"/}
      [ -n "$(git ls-files -- "$rel" 2>/dev/null)" ] && return 0 ;;
  esac
  echo "$p"
}

# lizard's cognitive extension exists from 1.24.3; an older or unreadable version is not usable.
lizard_new_enough() {
  local v major minor patch
  v=$("$1" --version 2>/dev/null | head -n 1)
  case $v in [0-9]*.[0-9]*.[0-9]*) ;; *) return 1 ;; esac
  IFS=. read -r major minor patch <<EOF
$v
EOF
  case $major$minor$patch in *[!0-9]*) return 1 ;; esac
  [ "$major" -gt 1 ] || [ "$minor" -gt 24 ] || { [ "$minor" -eq 24 ] && [ "$patch" -ge 3 ]; }
}

resolve() {
  case "$1" in
    eslint)  [ -n "$(local_tool node_modules/.bin/eslint)" ] && { echo node_modules/.bin/eslint; return; } ;;
    lizard)  if command -v lizard >/dev/null 2>&1 && lizard_new_enough lizard; then echo lizard
             elif [ -x "$CACHE/bin/lizard" ]; then echo "$CACHE/bin/lizard"
             fi
             return 0 ;;
  esac
  # A version-manager shim (nodenv, rbenv, asdf) is on PATH even when the tool isn't installed — it must run.
  if command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; then echo "$1"
  elif [ -x "$CACHE/bin/$1" ]; then echo "$CACHE/bin/$1"
  fi
  return 0
}
