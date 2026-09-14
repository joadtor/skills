#!/usr/bin/env bash
# JavaScript / TypeScript mutation candidates (js, jsx, mjs, cjs, ts, tsx). See _common.sh.
. "$(dirname "$0")/_common.sh" '//'

# Lines a statement-deletion must leave alone: keywords, declarations, assignments, console output.
no_delete='^[[:space:]]*(if|else|for|while|do|switch|case|default|return|throw|new|function|async|const|let|var|class|import|export|try|catch|finally|typeof|delete|void|yield)([[:space:](.]|$)|^[[:space:]]*console\.|(^|[^=!<>])=($|[^=>])'

# high — the whole statement or branch changes meaning
rule high delete-call       '^([[:space:]]*)((await[[:space:]]+)?[A-Za-z_$][[:alnum:]_$.]*\(.*\);?)$' '\1// \2' "$no_delete"
rule high negate-condition  '(^|[^[:alnum:]_$])(if|while)[[:space:]]*\((.*)\)[[:space:]]*(\{?)[[:space:]]*$' '\1\2 (!(\3)) \4'
rule high return-undefined  '(^|[[:space:]])return[[:space:]]+[^[:space:];].*$'                 '\1return;'

# mid — an operator flips
rule mid  and-or            ' && '                                                               ' || '
rule mid  or-and            ' \|\| '                                                             ' \&\& '
rule mid  nullish-or        ' \?\? '                                                             ' || '
rule mid  drop-negation     '(^|[^[:alnum:]_$!])!([[:alpha:]_$(])'                               '\1\2'
rule mid  seq-sneq          ' === '                                                              ' !== '
rule mid  sneq-seq          ' !== '                                                              ' === '
rule mid  eq-neq            ' == '                                                               ' != '
rule mid  neq-eq            ' != '                                                               ' == '
rule mid  drop-optional     '\?\.'                                                               '.'
rule mid  some-every        '\.some\('                                                           '.every('
rule mid  every-some        '\.every\('                                                          '.some('

# low — boundaries and literals
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
rule low  incr-decr         '\+\+'                                                               '--'
rule low  decr-incr         '--'                                                                 '++'
rule low  true-false        '(^|[^[:alnum:]_$])true([^[:alnum:]_$]|$)'                           '\1false\2'
rule low  false-true        '(^|[^[:alnum:]_$])false([^[:alnum:]_$]|$)'                          '\1true\2'
rule low  zero-one          '(^|[^[:alnum:]_$.])0([^[:alnum:]_$.]|$)'                            '\11\2'
rule low  number-plus-one   '(^|[^[:alnum:]_$.])([1-9][0-9]*)([^[:alnum:]_$.]|$)'                '\1(\2 + 1)\3'
rule low  empty-string      '"([^"\\]|\\.)+"|'"'"'([^'"'"'\\]|\\.)+'"'"''                        '""'

run "$1"
