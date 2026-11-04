#!/usr/bin/env bash
# Plan and install the complexity tools. Never prompts: the skill asks the user for consent.
#
# Usage: setup.sh plan [path...]      one TAB-separated line per MISSING tool for the languages being checked:
#                                    lang  tool  version  method  scope
#                                    scope: cache | global-toolchain (clippy, via rustup) | runtime-missing (method names what to install)
#        setup.sh install <tool>...  install exactly those tools into the cache, never into the project
# Exit: plan 0 · install 0 if all succeeded, else 1 with a stderr line per failure.
. "$(dirname "${BASH_SOURCE[0]}")/_common.sh" || exit 1

# Exact pins.
# rubocop 1.92.1 needs Ruby >= 2.7.0.
# typescript stays below 6.1 because typescript-eslint's peer range is typescript >=4.8.4 <6.1.0.
RUBOCOP_VERSION=1.92.1
ESLINT_VERSION=10.13.0
TS_ESLINT_VERSION=8.72.1
TYPESCRIPT_VERSION=6.0.3
RADON_VERSION=6.0.1
GOCYCLO_VERSION=v0.6.0

have() { command -v "$1" >/dev/null 2>&1; }

tool_for() {
  case "$1" in ruby) echo rubocop;; js) echo eslint;; python) echo radon;; go) echo gocyclo;; rust) echo clippy;; esac
}

present() {
  case "$1" in
    # From / so a project rust-toolchain.toml can't make rustup install a toolchain before consent.
    clippy) have cargo && (cd / && cargo clippy --version) >/dev/null 2>&1 ;;
    # Without a project eslint, js.sh imports the parser from the cache, so the tool alone isn't enough.
    eslint) [ -n "$(resolve eslint)" ] && { [ -x node_modules/.bin/eslint ] || [ -f "$CACHE/node/node_modules/typescript-eslint/dist/index.js" ]; } ;;
    *) [ -n "$(resolve "$1")" ] ;;
  esac
}

# The runtimes a tool needs to install, space-separated.
runtimes_for() {
  case "$1" in rubocop) echo gem;; eslint) echo npm;; radon) echo uv;; gocyclo) echo go;; clippy) echo "cargo rustup";; esac
}

version_of() {
  case "$1" in
    rubocop) echo "$RUBOCOP_VERSION";; eslint) echo "$ESLINT_VERSION";; radon) echo "$RADON_VERSION";;
    gocyclo) echo "$GOCYCLO_VERSION";; clippy) echo toolchain;;
  esac
}

method_for() {
  case "$1" in
    rubocop) echo "gem install rubocop -v $RUBOCOP_VERSION --install-dir \$CACHE/gems";;
    eslint)  echo "npm install --prefix \$CACHE/node eslint@$ESLINT_VERSION typescript-eslint@$TS_ESLINT_VERSION typescript@$TYPESCRIPT_VERSION";;
    radon)   echo "uv tool install radon==$RADON_VERSION";;
    gocyclo) echo "go install github.com/fzipp/gocyclo/cmd/gocyclo@$GOCYCLO_VERSION";;
    clippy)  echo "rustup component add clippy";;
  esac
}

# Probed from the cache dir (or /), so a project's .ruby-version/.node-version can't answer for the runtime a cache install would use.
runtime_too_old() {
  case "$1" in
    rubocop) have ruby && ! (cd "$CACHE" 2>/dev/null || cd /; ruby -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7") ? 0 : 1)') 2>/dev/null && echo "Ruby >= 2.7" ;;
    eslint)  have node && ! (cd "$CACHE" 2>/dev/null || cd /; node -e 'const v = process.versions.node.split(".").map(Number); process.exit(v[0] >= 24 || (v[0] === 22 && v[1] >= 13) || (v[0] === 20 && v[1] >= 19) ? 0 : 1)') 2>/dev/null && echo "Node >= 20.19" ;;
  esac
}

plan() {
  local lang tool rt missing scope method name files a old
  files=$(target_files "$@") || return 2
  { printf '%s\n' "$files"; for a in "$@"; do printf '%s\n' "$a"; done; } | while IFS= read -r f; do lang_of "$f"; done | sort -u | while IFS= read -r lang; do
    [ -n "$lang" ] || continue
    tool=$(tool_for "$lang")
    present "$tool" && continue
    missing=""
    for rt in $(runtimes_for "$tool"); do have "$rt" || missing="$missing${missing:+ }$rt"; done
    scope=cache; [ "$tool" = clippy ] && scope=global-toolchain
    method=$(method_for "$tool")
    [ -n "$missing" ] && { scope=runtime-missing; method="install $missing first"; }
    old=$(runtime_too_old "$tool")
    [ -z "$missing" ] && [ -n "$old" ] && { scope=runtime-missing; method="install $old first"; }
    printf '%s\t%s\t%s\t%s\t%s\n' "$lang" "$tool" "$(version_of "$tool")" "$method" "$scope"
  done
}

install_rubocop() {
  gem install rubocop -v "$RUBOCOP_VERSION" --remote --install-dir "$CACHE/gems" --no-document >/dev/null || return 1
  cat > "$CACHE/bin/rubocop" <<WRAP
#!/bin/sh
GEM_HOME="$CACHE/gems" GEM_PATH="$CACHE/gems" exec "$CACHE/gems/bin/rubocop" "\$@"
WRAP
  chmod +x "$CACHE/bin/rubocop"
}

install_eslint() {
  npm install --prefix "$CACHE/node" --registry=https://registry.npmjs.org/ --no-save --no-package-lock --ignore-scripts \
    "eslint@$ESLINT_VERSION" "typescript-eslint@$TS_ESLINT_VERSION" "typescript@$TYPESCRIPT_VERSION" >/dev/null || return 1
  ln -sf "$CACHE/node/node_modules/.bin/eslint" "$CACHE/bin/eslint"
}

install_radon()   { UV_TOOL_DIR="$CACHE/uv" UV_TOOL_BIN_DIR="$CACHE/bin" uv tool install --no-config --default-index https://pypi.org/simple "radon==$RADON_VERSION" >/dev/null; }
install_gocyclo() { GOBIN="$CACHE/bin" go install "github.com/fzipp/gocyclo/cmd/gocyclo@$GOCYCLO_VERSION"; }
install_clippy()  { rustup component add clippy >/dev/null; }

install() {
  local tool rt status=0 err
  mkdir -p "$CACHE/bin" || return 1
  for tool in "$@"; do
    case "$tool" in rubocop|eslint|radon|gocyclo|clippy) ;; *) echo "setup: unknown tool: $tool" >&2; status=1; continue;; esac
    for rt in $(runtimes_for "$tool"); do
      have "$rt" || { echo "setup: $tool not installed: $rt is missing" >&2; status=1; continue 2; }
    done
    # Installers run from the cache, never the project: a repo's .gem files, .npmrc, uv.toml or
    # rust-toolchain.toml must not choose what gets installed.
    if ! err=$(cd "$CACHE" && "install_$tool" 2>&1 >/dev/null); then
      echo "setup: $tool install failed: $(printf '%s' "$err" | grep -v '^$' | tail -n 1)" >&2
      status=1
    fi
  done
  return $status
}

case "${1:-}" in
  plan)    shift; plan "$@"; exit $? ;;
  install) shift; install "$@" ;;
  *) echo "usage: setup.sh plan [path...] | install <tool>..." >&2; exit 2 ;;
esac
