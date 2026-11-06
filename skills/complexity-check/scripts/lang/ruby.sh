#!/usr/bin/env bash
# Ruby cognitive complexity: the built-in scorer ruby_cognitive.rb (SonarSource rules over Ripper, stdlib only).
# Ruby has no project tool to defer to and never falls back to lizard.
# Usage: ruby.sh <file>...   (contract: see ../check.sh). Limit: default_limit, source "skill default".
scorer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ruby_cognitive.rb"
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

ruby=$(resolve ruby)
if [ "${1:-}" = --detect ]; then
  [ -n "$ruby" ] && exit 0
  echo "ruby is not installed — install Ruby" >&2
  exit 5
fi
[ -n "$ruby" ] || { echo "ruby not installed" >&2; exit 3; }
root=$PWD limit=$(default_limit ruby)

args=()
for f in "$@"; do f=${f#./}; args+=("$root/$f"); done

rows=$(env -u RUBYOPT -u RUBYLIB "$ruby" --disable-gems "$scorer" "$root" "${args[@]}"); st=$?

over=0
while IFS=$'\t' read -r loc name score; do
  [ -n "$loc" ] && [ "$score" -gt "$limit" ] || continue
  printf '%s\truby\t%s\tcognitive\t%s\t%s\tskill default\n' "$loc" "$name" "$score" "$limit"
  over=1
done <<EOF
$rows
EOF

[ $over -eq 1 ] && exit 1
[ $st -eq 2 ] && exit 2
exit 0
