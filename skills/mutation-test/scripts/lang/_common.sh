#!/usr/bin/env bash
# Shared matcher for the language scripts in this directory. Not run directly.
#
# A language script sources it with the language's line-comment marker, declares its rules,
# then calls `run "$file"`; the main script supplies "lineno<TAB>line" pairs on stdin:
#
#   . "$(dirname "$0")/_common.sh" '#'
#   rule high if-unless '(^|[^[:alnum:]_.])if([[:space:](])' '\1unless\2'
#   run "$1"
#
# rule <severity> <label> <pattern> <replacement> [<skip-pattern>]
#   pattern / skip-pattern: POSIX ERE (what `sed -E` and bash `=~` share) — no \b, no lookaround.
#   replacement: sed syntax — \1..\9 are groups, a literal & must be written \&.
#   skip-pattern: when the line also matches this, the rule does not apply (keywords, assignments…).
#   Declare rules high → mid → low: per line the output keeps that order, which is the triage order.
#
# Output, one candidate per line, tab-separated:
#   file:line  severity  label  original-line  mutated-line

COMMENT=$1
RULES=()
US=$'\037' # field separator inside a stored rule — never appears in a pattern

rule() { RULES+=("$1$US$2$US$3$US$4$US${5:-}"); }

trim() {
  local s=$1
  s=${s#"${s%%[![:space:]]*}"}
  printf '%s' "${s%"${s##*[![:space:]]}"}"
}

run() {
  local file=$1 d=$'\001' n line stripped r sev label pat rep skip mutant
  while IFS=$'\t' read -r n line; do
    stripped=$(trim "$line")
    [ -z "$stripped" ] && continue
    [[ $stripped == "$COMMENT"* ]] && continue
    for r in "${RULES[@]}"; do
      IFS=$US read -r sev label pat rep skip <<<"$r"
      [[ $line =~ $pat ]] || continue
      [[ -n $skip && $line =~ $skip ]] && continue
      mutant=$(printf '%s\n' "$line" | sed -E "s${d}${pat}${d}${rep}${d}")
      [ "$mutant" = "$line" ] && continue
      printf '%s:%s\t%s\t%s\t%s\t%s\n' "$file" "$n" "$sev" "$label" "$stripped" "$(trim "$mutant")"
    done
  done
}
