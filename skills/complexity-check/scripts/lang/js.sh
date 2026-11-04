#!/usr/bin/env bash
# JS/TS complexity: eslint's classic `complexity` rule.
# Usage: js.sh <file>...   (contract: see ../check.sh)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

limit=$(default_limit js) src="skill default"
run=$(resolve eslint)
[ -z "$run" ] && { echo "eslint not found" >&2; exit 3; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-js.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

if [ "$run" = node_modules/.bin/eslint ]; then
  # Project eslint: its own config; the limit it sets for `complexity` wins.
  configured=$($run --print-config "$1" 2> /dev/null | node -e '
    const rule = JSON.parse(require("fs").readFileSync(0, "utf8")).rules.complexity;
    const [sev, opt] = Array.isArray(rule) ? rule : [rule];
    const on = sev !== 0 && sev !== "off";
    const n = typeof opt === "number" ? opt : opt && opt.max;
    if (on && typeof n === "number") console.log(n);
  ')
  [ -n "$configured" ] && { limit=$configured; src="eslint config"; }
  $run --rule "complexity: [error, $limit]" --format json "$@" > "$tmp/out.json" 2> "$tmp/err"
else
  # No project eslint: lint with a config of our own that borrows the parser from the tool cache.
  [ -f "$CACHE/node/node_modules/typescript-eslint/dist/index.js" ] || { echo "typescript-eslint parser not installed" >&2; exit 3; }
  cat > "$tmp/eslint.config.mjs" <<EOF2
import tseslint from "file://$CACHE/node/node_modules/typescript-eslint/dist/index.js";
export default [{
  files: ["**/*.{js,jsx,mjs,cjs,ts,tsx}"],
  languageOptions: { parser: tseslint.parser },
  rules: { complexity: ["error", $limit] },
}];
EOF2
  $run -c "$tmp/eslint.config.mjs" --format json "$@" > "$tmp/out.json" 2> "$tmp/err"
fi
status=$?
[ $status -ge 2 ] && { cat "$tmp/err" >&2; exit 2; }

LIMIT=$limit SRC=$src node -e '
  const r = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  for (const f of r) for (const m of f.messages) {
    if (m.ruleId !== "complexity") continue;
    const name = (m.message.match(/ \x27([^\x27]+)\x27 has a complexity/) || [])[1] || "<anonymous>";
    const score = m.message.match(/complexity of (\d+)/)[1];
    const file = require("path").relative(process.cwd(), f.filePath);
    console.log([file + ":" + m.line, "js", name, "cyclomatic", score, process.env.LIMIT, process.env.SRC].join("\t"));
  }
' "$tmp/out.json" > "$tmp/offenders"
cat "$tmp/offenders"
[ -s "$tmp/offenders" ] && exit 1
exit 0
