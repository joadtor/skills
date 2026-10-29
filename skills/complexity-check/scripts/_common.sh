# Shared plumbing for check.sh and setup.sh — sourced, never run directly.
#
# On source: cd to the repo top level and set CACHE (not created here).
#   base_branch          echo the base: first of develop, master, main on origin, else origin's default branch
#   target_files [path...]
#                        repo-relative production files, sorted, unique, existing
#                        no path: changed vs merge-base with origin/<base> + untracked non-ignored
#                        paths:   every tracked + untracked non-ignored file under each
#   lang_of <file>       ruby | js | python | go | rust | (empty)
#   default_limit <lang> per-function complexity ceiling for the language
#   resolve <tool>       command to run: project-local, then PATH, then $CACHE/bin; empty if none
cd "$(git rev-parse --show-toplevel)" || return 1
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/joadtor/complexity-check"

base_branch() {
  local b
  b=$(for b in develop master main; do
    git rev-parse --verify --quiet "origin/$b" >/dev/null && echo "$b" && break
  done)
  [ -z "$b" ] && b=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
  echo "$b"
}

target_files() {
  # Not production code: tests, fixtures, vendored or generated output, migrations, config and data files.
  local skip='(^|/)(spec|test|tests|__tests__|__mocks__|fixtures?|features|node_modules|vendor|dist|build|target|coverage|db/migrate)/|(_spec|_test|\.test|\.spec|\.stories|\.config|\.d)\.[a-z]+$|(^|/)(schema\.rb|conftest\.py|setup\.py)$|\.(json|ya?ml|toml|lock|md|txt|csv|snap|min\.js)$'
  local f
  if [ $# -gt 0 ]; then
    { git ls-files -- "$@"; git ls-files --others --exclude-standard -- "$@"; }
  else
    local mb
    mb=$(git merge-base "origin/$(base_branch)" HEAD)
    { git diff --name-only --diff-filter=AMR "$mb"; git ls-files --others --exclude-standard; }
  fi | grep -Ev "$skip" | sort -u | while IFS= read -r f; do
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

resolve() {
  case "$1" in
    rubocop) grep -q ' rubocop (' Gemfile.lock 2>/dev/null && { echo "bundle exec rubocop"; return; } ;;
    eslint)  [ -x node_modules/.bin/eslint ] && { echo node_modules/.bin/eslint; return; } ;;
  esac
  # A version-manager shim (nodenv, rbenv, asdf) is on PATH even when the tool isn't installed — it must run.
  if command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; then echo "$1"
  elif [ -x "$CACHE/bin/$1" ]; then echo "$CACHE/bin/$1"
  fi
  return 0
}
