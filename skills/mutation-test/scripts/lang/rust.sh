#!/usr/bin/env bash
# Rust mutation candidates. See _common.sh.
. "$(dirname "$0")/_common.sh" '//'

# Lines a statement-deletion must leave alone: keywords, declarations, assignments, prints.
no_delete='^[[:space:]]*(let|return|if|else|match|while|for|loop|use|mod|fn|pub|impl|struct|enum|const|static|println!|eprintln!|dbg!|panic!|todo!|unimplemented!)([[:space:](]|$)|(^|[^=!<>])=($|[^=>])'

# high — the whole statement or branch changes meaning
rule high delete-call       '^([[:space:]]*)([a-z_][[:alnum:]_:.]*!?\(.*\)[?]?;)$'               '\1// \2' "$no_delete"
rule high negate-condition  '(^|[^[:alnum:]_])(if|while)[[:space:]]+(.*[^[:space:]])[[:space:]]*\{[[:space:]]*$' '\1\2 !(\3) {' '(if|while)[[:space:]]+let[[:space:]]'
rule high return-default    '(^|[[:space:]])return[[:space:]]+[^[:space:];].*;$'                '\1return Default::default();'
rule high some-none         'Some\(([^()]*)\)'                                                   'None'

# mid — an operator or predicate flips
rule mid  and-or            ' && '                                                               ' || '
rule mid  or-and            ' \|\| '                                                             ' \&\& '
rule mid  drop-negation     '(^|[^[:alnum:]_!])!([[:alpha:]_(])'                                 '\1\2'
rule mid  eq-neq            ' == '                                                               ' != '
rule mid  neq-eq            ' != '                                                               ' == '
rule mid  some-none-check   '\.is_some\(\)'                                                      '.is_none()'
rule mid  none-some-check   '\.is_none\(\)'                                                      '.is_some()'
rule mid  ok-err-check      '\.is_ok\(\)'                                                        '.is_err()'
rule mid  err-ok-check      '\.is_err\(\)'                                                       '.is_ok()'
rule mid  break-continue    '(^|[[:space:]])break;'                                              '\1continue;'
rule mid  continue-break    '(^|[[:space:]])continue;'                                           '\1break;'

# low — boundaries and literals
rule low  inclusive-range   '\.\.='                                                              '..'
rule low  ge-gt             ' >= '                                                               ' > '
rule low  le-lt             ' <= '                                                               ' < '
rule low  gt-ge             ' > '                                                                ' >= '
rule low  lt-le             ' < '                                                                ' <= '
rule low  plus-minus        ' \+ '                                                               ' - '
rule low  minus-plus        ' - '                                                                ' + '
rule low  mul-div           ' \* '                                                               ' / '
rule low  div-mul           ' / '                                                                ' * '
rule low  plus-assign       ' \+= '                                                              ' -= '
rule low  minus-assign      ' -= '                                                               ' += '
rule low  true-false        '(^|[^[:alnum:]_])true([^[:alnum:]_]|$)'                             '\1false\2'
rule low  false-true        '(^|[^[:alnum:]_])false([^[:alnum:]_]|$)'                            '\1true\2'
rule low  zero-one          '(^|[^[:alnum:]_.])0([^[:alnum:]_.]|$)'                              '\11\2'
rule low  number-plus-one   '(^|[^[:alnum:]_.])([1-9][0-9]*)([^[:alnum:]_.]|$)'                  '\1(\2 + 1)\3'
rule low  empty-string      '"([^"\\]|\\.)+"'                                                    '""'

run "$1"
