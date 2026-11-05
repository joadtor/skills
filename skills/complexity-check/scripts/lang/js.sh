#!/usr/bin/env bash
# JS/TS cognitive complexity from the project's own tool, ESLint first: eslint-plugin-sonarjs
# (sonarjs/cognitive-complexity), else Biome (complexity/noExcessiveCognitiveComplexity).
# Exit 4 when the project has neither configured.
# Usage: js.sh <file>...   (contract: see ../check.sh)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-js.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

# Prints the rule's numeric limit, or "default", when sonarjs/cognitive-complexity is on; nothing when off.
eslint_limit() {
  node_modules/.bin/eslint --print-config "$1" 2> /dev/null | node -e '
    const rule = (JSON.parse(require("fs").readFileSync(0, "utf8")).rules || {})["sonarjs/cognitive-complexity"];
    const [sev, opt] = Array.isArray(rule) ? rule : [rule];
    if (sev === undefined || sev === 0 || sev === "off") process.exit(0);
    console.log(Number.isInteger(opt) && opt > 0 ? opt : "default");
  '
}

if [ -n "$(local_tool node_modules/.bin/eslint)" ]; then
  configured=$(eslint_limit "$1")
  if [ -n "$configured" ]; then
    limit=$(default_limit js) src="skill default"
    [ "$configured" != default ] && { limit=$configured; src="eslint config"; }
    node_modules/.bin/eslint --format json "$@" > "$tmp/out.json" 2> "$tmp/err"
    [ $? -ge 2 ] && { cat "$tmp/err" >&2; exit 2; }
    LIMIT=$limit SRC=$src node -e '
      const fs = require("fs"), path = require("path");
      for (const f of JSON.parse(fs.readFileSync(process.argv[1], "utf8"))) {
        const lines = fs.readFileSync(f.filePath, "utf8").split("\n");
        for (const m of f.messages) {
          if (m.ruleId !== "sonarjs/cognitive-complexity") continue;
          const score = (m.message.match(/Cognitive Complexity from (\d+) to/) || [])[1];
          if (!score) continue;
          const name = ((lines[m.line - 1] || "").slice(m.column - 1).match(/^[A-Za-z_$][\w$]*/) || [])[0] || "<anonymous>";
          console.log([path.relative(process.cwd(), f.filePath) + ":" + m.line, "js", name, "cognitive", score, process.env.LIMIT, process.env.SRC].join("\t"));
        }
      }
    ' "$tmp/out.json" > "$tmp/offenders"
    cat "$tmp/offenders"
    [ -s "$tmp/offenders" ] && exit 1
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
    limit=$(default_limit js) src="skill default"
    [ "$configured" != default ] && { limit=$configured; src=$cfgfile; }
    node_modules/.bin/biome lint --reporter=json "$@" > "$tmp/out.json" 2> "$tmp/err"
    [ $? -ge 2 ] && { cat "$tmp/err" >&2; exit 2; }
    LIMIT=$limit SRC=$src node -e '
      const fs = require("fs"), path = require("path");
      const raw = fs.readFileSync(process.argv[1], "utf8");
      const r = JSON.parse(raw.slice(raw.indexOf("{")));
      for (const d of r.diagnostics) {
        if (d.category !== "lint/complexity/noExcessiveCognitiveComplexity") continue;
        const score = (d.message.match(/complexity of (\d+) detected/) || [])[1];
        if (!score || !d.location || !d.location.path) continue;
        const file = path.resolve(d.location.path.file || d.location.path);
        const line = (fs.readFileSync(file, "utf8").split("\n")[d.location.start.line - 1] || "");
        const name = (line.slice(d.location.start.column - 1).match(/^[A-Za-z_$][\w$]*/) || [])[0] || "<anonymous>";
        console.log([path.relative(process.cwd(), file) + ":" + d.location.start.line, "js", name, "cognitive", score, process.env.LIMIT, process.env.SRC].join("\t"));
      }
    ' "$tmp/out.json" > "$tmp/offenders"
    cat "$tmp/offenders"
    [ -s "$tmp/offenders" ] && exit 1
    exit 0
  fi
fi
exit 4
