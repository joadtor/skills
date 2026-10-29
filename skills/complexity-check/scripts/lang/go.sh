#!/usr/bin/env bash
# Go complexity: gocyclo cyclomatic complexity.
# Usage: go.sh <file>...   (contract: see ../check.sh)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

limit=$(default_limit go) src="skill default"

# golangci-lint gocyclo min-complexity N, read as limit N (report score > N).
# v1: linters-settings > gocyclo; v2: linters > settings > gocyclo. Indentation-aware, no yq.
for cfg in .golangci.yml .golangci.yaml; do
  [ -f "$cfg" ] || continue
  n=$(awk '
    /^[ ]*(#|$)/ { next }
    { match($0, /^ */); ind = RLENGTH; key = $0; sub(/^ +/, "", key); sub(/:.*/, "", key) }
    { for (d in path) if (d + 0 >= ind) delete path[d]; path[ind] = key }
    key == "min-complexity" {
      v = $0; sub(/^[^:]*:[ ]*/, "", v); sub(/[ ]*#.*/, "", v)
      p = ""; for (d = 0; d < ind; d++) if (d in path) p = p "/" path[d]
      if (p == "/linters-settings/gocyclo" || p == "/linters/settings/gocyclo") { print v; exit }
    }' "$cfg")
  case $n in ''|*[!0-9]*) continue ;; esac
  limit=$n src=$cfg; break
done

run=$(resolve gocyclo)
[ -z "$run" ] && { echo "gocyclo not found" >&2; exit 3; }

out=$($run -over "$limit" "$@"); status=$?
[ $status -gt 1 ] && exit 2
printf '%s\n' "$out" | awk -v limit="$limit" -v src="$src" -F' ' '
  NF >= 4 {
    split($NF, loc, ":")
    printf "%s:%s\tgo\t%s\tcyclomatic\t%s\t%s\t%s\n", loc[1], loc[2], $3, $1, limit, src
  }'
[ -n "$out" ] && exit 1
exit 0
