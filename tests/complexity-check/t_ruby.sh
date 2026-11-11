# Tests for scripts/lang/ruby.sh and lang/ruby_cognitive.rb (SonarSource cognitive complexity over Ripper).
# Each fixture in fixtures/ruby_cog/ carries its hand-computed score, with the rule applied, per line.
RUBY_SH="$SCRIPTS/lang/ruby.sh"
RUBY_COG="$SCRIPTS/lang/ruby_cognitive.rb"
TAB=$(printf '\t')

# cog <fixture>: every unit the scorer finds, as "line<TAB>name<TAB>score"
cog() {
  skip_unless_cmd ruby
  local d; d="$(mktmp)"
  cp "$FIXTURES/ruby_cog/$1" "$d/$1"
  (cd "$d" && ruby --disable-gems "$RUBY_COG" "$d" "$d/$1") | sed "s#^$1:##"
}

t_ruby_whitepaper_examples() {
  assert_eq "$(cog whitepaper.rb)" "3${TAB}sum_of_primes${TAB}8
19${TAB}get_words${TAB}1"
}

t_ruby_nested_total_for_and_each() {
  assert_eq "$(cog nested_for.rb)" "2${TAB}total${TAB}11"
  assert_eq "$(cog nested_each.rb)" "2${TAB}total${TAB}10"
}

t_ruby_boolean_sequences() {
  assert_eq "$(cog booleans.rb)" "2${TAB}all3${TAB}1
6${TAB}mixed${TAB}2
10${TAB}mixed_right${TAB}2
14${TAB}words${TAB}2
18${TAB}negated${TAB}2
22${TAB}parens${TAB}1
26${TAB}in_condition${TAB}2"
}

t_ruby_define_method_blocks_are_units() {
  assert_eq "$(cog define_method.rb)" "2${TAB}Widget#risky${TAB}3
10${TAB}Widget.build${TAB}1
14${TAB}Widget#plain${TAB}1"
}

t_ruby_rescue_and_ternary_nested_in_blocks() {
  assert_eq "$(cog rescue_ternary.rb)" "2${TAB}fetch_all${TAB}7
18${TAB}values${TAB}2
22${TAB}handler${TAB}2
26${TAB}safe${TAB}1
30${TAB}safe_in_block${TAB}2
34${TAB}method_rescue${TAB}1"
}

t_ruby_loops_elsif_and_unless_else() {
  assert_eq "$(cog loops.rb)" "1${TAB}drain${TAB}7
11${TAB}grade${TAB}5
21${TAB}label${TAB}2"
}

t_ruby_recursion() {
  assert_eq "$(cog recursion.rb)" "2${TAB}fact${TAB}2
7${TAB}countdown${TAB}2
11${TAB}walk${TAB}1
15${TAB}poll${TAB}1
19${TAB}size${TAB}0"
}

t_ruby_naming() {
  assert_eq "$(cog naming.rb)" "1${TAB}helper${TAB}1
6${TAB}Order#total${TAB}1
10${TAB}Order.build${TAB}1
15${TAB}Order.make${TAB}1
23${TAB}Shop::Order#total${TAB}1
27${TAB}Shop::Order#outer${TAB}1
28${TAB}Shop::Order#inner${TAB}2
37${TAB}Shop::Cart#items${TAB}1"
}

# ruby_repo <fixture-path:dest>...: a repo with the given fixtures copied in
ruby_repo() {
  skip_unless_cmd ruby
  local r a; r="$(fixture)"
  for a in "$@"; do copy_fixture "$r" "${a%%:*}" "${a#*:}"; done
  echo "$r"
}

t_ruby_flat_over_and_at_limit() {
  local r; r="$(ruby_repo cognitive/ruby/over.rb:src/over.rb cognitive/ruby/at_limit.rb:src/at_limit.rb)" || exit $?
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/over.rb src/at_limit.rb
  assert_exit 1
  assert_eq "$OUT" "src/over.rb:2${TAB}ruby${TAB}Sample#risky${TAB}cognitive${TAB}16${TAB}15${TAB}skill default"
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/at_limit.rb
  assert_exit 0
  assert_eq "$OUT" ""
}

t_ruby_unparsable_is_unchecked() {
  local r; r="$(ruby_repo cognitive/ruby/over.rb:src/over.rb)" || exit $?
  add_file "$r" src/broken.rb - <<'RB'
class Broken
  def risky(x)
    if x
      1
  end
RB
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/broken.rb
  assert_exit 2
  assert_eq "$ERR" "complexity: src/broken.rb could not be parsed — unchecked"
  assert_eq "$OUT" ""
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/broken.rb src/over.rb
  assert_exit 1
  assert_eq "$ERR" "complexity: src/broken.rb could not be parsed — unchecked"
  assert_contains "$OUT" "src/over.rb:2${TAB}ruby${TAB}Sample#risky"
}

# no_ruby_path: a PATH dir with the basic commands the scripts need, and no ruby
no_ruby_path() {
  local d="$TEST_TMP/noruby" c p
  mkdir -p "$d"
  for c in bash git grep sort sed awk cat dirname basename mkdir rm ln tr head tail cut env mktemp wc; do
    p="$(command -v "$c")" && ln -sf "$p" "$d/$c"
  done
  echo "$d"
}

t_ruby_missing_exits_3() {
  local r; r="$(fixture)"
  copy_fixture "$r" cognitive/ruby/over.rb src/over.rb
  run_in "$r" env PATH="$(no_ruby_path)" XDG_CACHE_HOME="$TEST_TMP/empty-cache" "$RUBY_SH" src/over.rb
  assert_exit 3
  assert_eq "$ERR" "ruby not installed"
  assert_eq "$OUT" ""
}

t_ruby_missing_is_skipped_without_lizard() {
  local r s; r="$(fixture)"; s="$TEST_TMP/scripts"
  copy_fixture "$r" cognitive/ruby/over.rb src/over.rb
  mkdir -p "$s/lang"
  ln -s "$SCRIPTS/_common.sh" "$s/_common.sh"
  ln -s "$RUBY_SH" "$s/lang/ruby.sh"
  ln -s "$RUBY_COG" "$s/lang/ruby_cognitive.rb"
  printf '#!/usr/bin/env bash\necho "$*" >> "%s/lizard-calls"\n' "$TEST_TMP" > "$s/lang/lizard.sh"
  chmod +x "$s/lang/lizard.sh"
  run_in "$r" env PATH="$(no_ruby_path)" XDG_CACHE_HOME="$TEST_TMP/empty-cache" COMPLEXITY_CHECK_LANG_DIR="$s/lang" \
    "$SCRIPTS/check.sh" src/over.rb
  assert_exit 0
  assert_contains "$ERR" "complexity: skipped Ruby (ruby not installed — run setup) — unchecked: src/over.rb"
  [ ! -e "$TEST_TMP/lizard-calls" ] || fail "lizard.sh was called for Ruby: $(cat "$TEST_TMP/lizard-calls")"
}

ruby_snapshot() {
  (cd "$1" && find . -path ./.git -prune -o -print | sort | while IFS= read -r p; do
    if [ -f "$p" ]; then cksum "$p"; else echo "$p"; fi
  done)
}

# The scorer parses, never runs: no project file is loaded, whether named by a shebang, RUBYOPT, RUBYLIB or a Gemfile.
t_ruby_never_interferes() {
  local r m before; r="$(ruby_repo cognitive/ruby/over.rb:src/over.rb)" || exit $?; m="$TEST_TMP/markers"
  mkdir -p "$m"
  add_file "$r" evil.rb "File.write('$m/evil', 'x')"
  add_file "$r" lib/ripper.rb "File.write('$m/ripper', 'x')"
  add_file "$r" Gemfile "File.write('$m/gemfile', 'x')"
  add_file "$r" .ruby-version "$(ruby -e 'print RUBY_VERSION')"
  add_file "$r" src/trap.rb - <<RB
#!/usr/bin/env ruby -r$r/evil.rb
def risky(x)
  x if x
end
RB
  add_file "$r" .gitignore "*.log"
  add_file "$r" x.log "ignored"
  before="$(ruby_snapshot "$r")"
  run_in "$r" env RUBYOPT="-r$r/evil.rb" RUBYLIB="$r/lib" XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/over.rb src/trap.rb
  assert_eq "$(ls "$m")" "" "a project file was loaded"
  assert_exit 1
  assert_eq "$OUT" "src/over.rb:2${TAB}ruby${TAB}Sample#risky${TAB}cognitive${TAB}16${TAB}15${TAB}skill default"
  assert_eq "$(ruby_snapshot "$r")" "$before" "project files changed"
}

t_ruby_detect() {
  skip_unless_cmd ruby
  local r; r="$(fixture)"
  add_file "$r" src/a.rb "def a; end"
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" --detect src/a.rb
  assert_exit 0
  assert_eq "$OUT$ERR" ""
  run_in "$r" env PATH="$(no_ruby_path)" XDG_CACHE_HOME="$TEST_TMP/empty-cache" "$RUBY_SH" --detect src/a.rb
  assert_exit 5
  assert_eq "$OUT" ""
  assert_eq "$ERR" "ruby is not installed — install Ruby"
}

t_ruby_utf8_source_parses_under_any_locale() {
  local r; r="$(ruby_repo)" || exit $?
  add_file "$r" src/cafe.rb - <<'RB'
def name(x)
  x ? "café" : "thé"
end
RB
  run_in "$r" env LC_ALL=C LANG=C XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/cafe.rb
  assert_exit 0
  assert_eq "$ERR" ""
}

t_ruby_a_scorer_crash_is_a_failure_not_clean() {
  local r bin; r="$(ruby_repo cognitive/ruby/over.rb:src/over.rb)" || exit $?; bin="$TEST_TMP/fake"
  mkdir -p "$bin"
  printf '#!/bin/sh\n[ "$1" = --version ] && exit 0\necho "boom: first" >&2\necho "second line" >&2\nexit 1\n' > "$bin/ruby"
  chmod +x "$bin/ruby"
  run_in "$r" env PATH="$bin:/usr/bin:/bin" XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/over.rb
  assert_exit 2
  assert_eq "$OUT" ""
  assert_eq "$ERR" "boom: first"
}

t_ruby_a_file_the_scorer_chokes_on_is_unchecked_and_the_rest_is_still_scored() {
  local r i; r="$(ruby_repo cognitive/ruby/over.rb:src/over.rb)" || exit $?
  add_file "$r" src/locked.rb "def a; end"
  chmod 000 "$r/src/locked.rb"
  { printf 'def deep\n  x = 1'; i=0; while [ $i -lt 10000 ]; do printf ' + 1'; i=$((i + 1)); done; printf '\nend\n'; } > "$r/src/deep.rb"
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/locked.rb src/deep.rb src/over.rb
  chmod 644 "$r/src/locked.rb"
  assert_exit 1
  assert_eq "$OUT" "src/over.rb:2${TAB}ruby${TAB}Sample#risky${TAB}cognitive${TAB}16${TAB}15${TAB}skill default"
  assert_contains "$ERR" "complexity: src/locked.rb could not be parsed — unchecked"
  assert_contains "$ERR" "complexity: src/deep.rb could not be parsed — unchecked"
  assert_not_contains "$ERR" "stack level"
}

t_ruby_scorer_runs_from_a_temp_dir() {
  local r; r="$(ruby_repo cognitive/ruby/over.rb:src/over.rb)" || exit $?
  add_file "$r" src/pwd.rb "def a; end"
  mkdir -p "$TEST_TMP/fake"
  printf '#!/bin/sh\npwd > "%s/cwd"\nexec /usr/bin/env -i PATH="$PATH" "%s" "$@"\n' "$TEST_TMP" "$(command -v ruby)" > "$TEST_TMP/fake/ruby"
  chmod +x "$TEST_TMP/fake/ruby"
  run_in "$r" env PATH="$TEST_TMP/fake:$PATH" XDG_CACHE_HOME="$TEST_TMP/cache" "$RUBY_SH" src/over.rb
  case "$(cat "$TEST_TMP/cwd")" in "$(cd "$r" && pwd -P)"|"$r") fail "the scorer ran in the repo: $(cat "$TEST_TMP/cwd")" ;; esac
}

t_ruby_end_to_end_a_broken_file_is_named_unchecked_beside_a_measured_one() {
  local r; r="$(ruby_repo cognitive/ruby/at_limit.rb:src/fine.rb)" || exit $?
  add_file "$r" src/broken.rb - <<'RB'
def risky(x)
  if x
    1
RB
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$SCRIPTS/check.sh"
  assert_exit 0
  assert_eq "$OUT" ""
  assert_contains "$ERR" "complexity: src/broken.rb could not be parsed — unchecked"
  assert_not_contains "$ERR" "fine.rb"
  assert_contains "$ERR" "complexity: clean — 1 file(s) unchecked"
  copy_fixture "$r" cognitive/ruby/over.rb src/over.rb
  run_in "$r" env XDG_CACHE_HOME="$TEST_TMP/cache" "$SCRIPTS/check.sh"
  assert_exit 1
  assert_eq "$OUT" "src/over.rb:2${TAB}ruby${TAB}Sample#risky${TAB}cognitive${TAB}16${TAB}15${TAB}skill default"
  assert_contains "$ERR" "complexity: src/broken.rb could not be parsed — unchecked"
  assert_contains "$ERR" "complexity: 1 function(s) over the limit — 1 file(s) unchecked"
}

t_ruby_differential_regressions() {
  assert_eq "$(cog regressions.rb)" "4${TAB}and_or${TAB}2
8${TAB}or_and${TAB}2
12${TAB}and_or_and${TAB}3
16${TAB}negated_runs${TAB}2
20${TAB}grouped_left${TAB}2
24${TAB}grouped_both${TAB}3
28${TAB}f${TAB}2
30${TAB}lambda_in_method${TAB}3
41${TAB}break_in_loop${TAB}2
47${TAB}modifier_while${TAB}1"
}
