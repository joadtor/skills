#!/usr/bin/env bash
# JS/TS cognitive complexity from the project's own tool, ESLint first: eslint-plugin-sonarjs
# (sonarjs/cognitive-complexity), else Biome (complexity/noExcessiveCognitiveComplexity).
# Exit 4 when the project has neither configured.
# Usage: js.sh [--detect] <file>...   (contract: see ../check.sh)
#   --detect  measure nothing: exit 0 = configured and runnable, 4 = not configured,
#             5 = configured but its tool is not installed (one stderr line names it)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

detect=0
[ "${1:-}" = --detect ] && { detect=1; shift; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-js.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

# Prints the rule's numeric limit, or "default", when sonarjs/cognitive-complexity is on for the file; nothing when off.
eslint_limit() {
  node_modules/.bin/eslint --print-config "$1" 2> /dev/null | node -e '
    let rule;
    try { rule = (JSON.parse(require("fs").readFileSync(0, "utf8")).rules || {})["sonarjs/cognitive-complexity"]; } catch (e) { process.exit(0); }
    const [sev, opt] = Array.isArray(rule) ? rule : [rule];
    if (sev === undefined || sev === 0 || sev === "off") process.exit(0);
    console.log(Number.isInteger(opt) && opt > 0 ? opt : "default");
  '
}

if [ -n "$(local_tool node_modules/.bin/eslint)" ]; then
  : > "$tmp/covered"
  uncovered=()
  for f in "$@"; do
    c=$(eslint_limit "$f")
    if [ -z "$c" ]; then uncovered+=("$f"); continue; fi
    [ $detect = 1 ] && exit 0
    printf '%s\t%s\n' "$c" "$f" >> "$tmp/covered"
  done
  if [ -s "$tmp/covered" ]; then
    : > "$tmp/offenders"
    unchecked=0
    for f in ${uncovered[@]+"${uncovered[@]}"}; do
      echo "complexity: $f not covered by the project's ESLint config — unchecked" >&2
      unchecked=1
    done
    while IFS= read -r configured; do
      limit=$(default_limit js) src="skill default"
      [ "$configured" != default ] && { limit=$configured; src="eslint config"; }
      group=()
      while IFS=$'\t' read -r c f; do
        [ "$c" = "$configured" ] && group+=("$f")
      done < "$tmp/covered"
      node_modules/.bin/eslint --format json "${group[@]}" > "$tmp/out.json" 2> "$tmp/err"
      [ $? -ge 2 ] && { cat "$tmp/err" >&2; exit 2; }
      LIMIT=$limit SRC=$src node -e '
        const fs = require("fs"), path = require("path");
        let bad = false;
        for (const f of JSON.parse(fs.readFileSync(process.argv[1], "utf8"))) {
          const rel = path.relative(process.cwd(), f.filePath);
          const lines = fs.readFileSync(f.filePath, "utf8").split("\n");
          for (const m of f.messages) {
            if (m.fatal || /^File ignored/.test(m.message)) {
              console.error("complexity: " + rel + " could not be parsed — unchecked");
              bad = true;
              continue;
            }
            if (m.ruleId !== "sonarjs/cognitive-complexity") continue;
            const score = (m.message.match(/Cognitive Complexity from (\d+) to/) || [])[1];
            if (!score) continue;
            const name = ((lines[m.line - 1] || "").slice(m.column - 1).match(/^[A-Za-z_$][\w$]*/) || [])[0] || "<anonymous>";
            console.log([rel + ":" + m.line, "js", name, "cognitive", score, process.env.LIMIT, process.env.SRC].join("\t"));
          }
        }
        process.exitCode = bad ? 3 : 0;
      ' "$tmp/out.json" >> "$tmp/offenders"
      [ $? -eq 3 ] && unchecked=1
    done <<EOF2
$(cut -f1 "$tmp/covered" | sort -u)
EOF2
    cat "$tmp/offenders"
    [ -s "$tmp/offenders" ] && exit 1
    [ $unchecked = 1 ] && exit 2
    exit 0
  fi
fi

# Prints "<biome.json|biome.jsonc> <limit|default>" when the rule is on; nothing when off.
biome_limit() {
  node -e '
    const fs = require("fs");
    const file = ["biome.json", "biome.jsonc"].find((f) => fs.existsSync(f));
    if (!file) process.exit(0);
    const strip = (t) => t.replace(/"(?:\\.|[^"\\])*"|\/\/[^\n]*|\/\*[\s\S]*?\*\/|,(?=\s*[}\]])/g, (m) => (m[0] === "\"" ? m : m[0] === "," ? "" : " "));
    let cfg;
    try { cfg = JSON.parse(strip(fs.readFileSync(file, "utf8"))); } catch (e) { process.exit(0); }
    const rule = (((cfg.linter || {}).rules || {}).complexity || {}).noExcessiveCognitiveComplexity;
    const level = rule && typeof rule === "object" ? rule.level : rule;
    if (typeof level !== "string" || level === "off") process.exit(0);
    const max = rule && typeof rule === "object" && rule.options ? rule.options.maxAllowedComplexity : undefined;
    console.log(file, Number.isInteger(max) && max > 0 ? max : "default");
  '
}

if [ -n "$(local_tool node_modules/.bin/biome)" ]; then
  read -r cfgfile configured <<< "$(biome_limit)"
  if [ -n "$cfgfile" ]; then
    [ $detect = 1 ] && exit 0
    limit=$(default_limit js) src="skill default"
    [ "$configured" != default ] && { limit=$configured; src=$cfgfile; }
    node_modules/.bin/biome lint --reporter=json "$@" > "$tmp/out.json" 2> "$tmp/err"
    [ $? -ge 2 ] && { cat "$tmp/err" >&2; exit 2; }
    LIMIT=$limit SRC=$src node -e '
      const fs = require("fs"), path = require("path");
      const raw = fs.readFileSync(process.argv[1], "utf8");
      const r = JSON.parse(raw.slice(raw.indexOf("{")));
      let bad = false;
      for (const d of r.diagnostics) {
        if (d.category === "parse" && d.location && d.location.path) {
          const p = path.relative(process.cwd(), path.resolve(d.location.path.file || d.location.path));
          console.error("complexity: " + p + " could not be parsed — unchecked");
          bad = true;
          continue;
        }
        if (d.category !== "lint/complexity/noExcessiveCognitiveComplexity") continue;
        const score = (d.message.match(/complexity of (\d+) detected/) || [])[1];
        if (!score || !d.location || !d.location.path) continue;
        const file = path.resolve(d.location.path.file || d.location.path);
        const line = (fs.readFileSync(file, "utf8").split("\n")[d.location.start.line - 1] || "");
        const name = (line.slice(d.location.start.column - 1).match(/^[A-Za-z_$][\w$]*/) || [])[0] || "<anonymous>";
        console.log([path.relative(process.cwd(), file) + ":" + d.location.start.line, "js", name, "cognitive", score, process.env.LIMIT, process.env.SRC].join("\t"));
      }
      process.exitCode = bad ? 3 : 0;
    ' "$tmp/out.json" > "$tmp/offenders"
    unchecked=$?
    cat "$tmp/offenders"
    [ -s "$tmp/offenders" ] && exit 1
    [ $unchecked -eq 3 ] && exit 2
    exit 0
  fi
fi
if [ $detect = 1 ]; then
  if [ -z "$(local_tool node_modules/.bin/eslint)" ]; then
    for cfg in eslint.config.* .eslintrc*; do
      [ -f "$cfg" ] && grep -q 'sonarjs' "$cfg" && { echo "eslint (configured in eslint config) is not installed — install the project's dependencies" >&2; exit 5; }
    done
  fi
  if [ -z "$(local_tool node_modules/.bin/biome)" ]; then
    for cfg in biome.json biome.jsonc; do
      [ -f "$cfg" ] && grep -q 'noExcessiveCognitiveComplexity' "$cfg" && ! grep -Eq 'noExcessiveCognitiveComplexity"?[[:space:]]*:[[:space:]]*"off"' "$cfg" &&
        { echo "biome (configured in $cfg) is not installed — install the project's dependencies" >&2; exit 5; }
    done
  fi
fi
exit 4
