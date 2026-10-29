#!/usr/bin/env bash
# Ruby complexity: rubocop Metrics/CyclomaticComplexity and Metrics/PerceivedComplexity.
# Usage: ruby.sh <file>...   (contract: see ../check.sh)
. "$(dirname "${BASH_SOURCE[0]}")/../_common.sh" || exit 1

default=$(default_limit ruby)
export DEFAULT=$default
IFS=$'\t' read -r CYC_LIMIT CYC_SRC PERC_LIMIT PERC_SRC <<EOF2
$(ruby -ryaml -e '
  cfg = File.exist?(".rubocop.yml") ? (YAML.safe_load(File.read(".rubocop.yml"), aliases: true) || {}) : {}
  row = ["Metrics/CyclomaticComplexity", "Metrics/PerceivedComplexity"].flat_map do |cop|
    max = (cfg[cop] || {})["Max"]
    disabled = (cfg[cop] || {})["Enabled"] == false || (cfg["Metrics"] || {})["Enabled"] == false
    [max.nil? ? "-" : max.to_s, disabled ? "disabled" : "enabled"]
  end
  puts row.join("\t")
' 2>/dev/null)
EOF2
SRC_FILE=".rubocop.yml"
for k in CYC PERC; do
  eval "v=\$${k}_LIMIT d=\$${k}_SRC"
  case $v in
    ''|*[!0-9]*)
      v=$default
      [ "$d" = disabled ] && d="skill default (project disables the cop)" || d="skill default" ;;
    *) d=$SRC_FILE ;;
  esac
  eval "${k}_LIMIT=\$v ${k}_SRC=\$d"
done
export CYC_LIMIT CYC_SRC PERC_LIMIT PERC_SRC

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cc-ruby.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT

write_config() {
  {
    [ "$1" = inherit ] && printf 'inherit_from: %s\n' "$PWD/.rubocop.yml"
    cat <<EOF2
Metrics/CyclomaticComplexity:
  Enabled: true
  Max: $CYC_LIMIT
Metrics/PerceivedComplexity:
  Enabled: true
  Max: $PERC_LIMIT
EOF2
  } > "$tmp/rubocop.yml"
}

run=$(resolve rubocop)
[ -z "$run" ] && { echo "rubocop not found" >&2; exit 3; }
run_rubocop() {
  $run -c "$tmp/rubocop.yml" --only Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity \
    --format json --force-exclusion "$@" > "$tmp/out.json" 2> "$tmp/err"
}

if [ -f .rubocop.yml ]; then write_config inherit; else write_config plain; fi
run_rubocop "$@"; status=$?
if [ $status -ge 2 ] && [ -f .rubocop.yml ]; then
  write_config plain
  echo "complexity: Ruby — project .rubocop.yml bypassed ($(head -n 1 "$tmp/err"))" >&2
  run_rubocop "$@"; status=$?
fi
if [ $status -ge 2 ]; then
  head -n 1 "$tmp/err" >&2
  exit 2
fi

ruby -rjson -e '
  names = {"Metrics/CyclomaticComplexity" => ["cyclomatic", ENV["CYC_LIMIT"], ENV["CYC_SRC"]],
           "Metrics/PerceivedComplexity"  => ["perceived",  ENV["PERC_LIMIT"], ENV["PERC_SRC"]]}
  JSON.parse(File.read(ARGV[0]))["files"].each do |f|
    lines = File.readlines(f["path"])
    f["offenses"].each do |o|
      metric, limit, src = names[o["cop_name"]]
      line = o["location"]["start_line"]
      meth = o["message"][/ for (\S+) is too high/, 1]
      def_line = lines[line - 1]
      indent = def_line[/\A */].size
      ctx = []
      (line - 2).downto(0) do |i|
        m = lines[i].match(/\A( *)(?:class|module)\s+([\w:]+)/)
        next unless m && m[1].size < indent
        ctx.unshift(m[2])
        indent = m[1].size
      end
      sep = def_line =~ /\bdef\s+self\./ ? "." : "#"
      fn = ctx.empty? ? meth : ctx.join("::") + sep + meth
      score = o["message"][/\[(\d+)\//, 1]
      puts [f["path"] + ":" + line.to_s, "ruby", fn, metric, score, limit, src].join("\t")
    end
  end
' "$tmp/out.json" > "$tmp/lines"
cat "$tmp/lines"
[ -s "$tmp/lines" ] && exit 1
exit 0
