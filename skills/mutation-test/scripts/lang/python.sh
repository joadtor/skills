#!/usr/bin/env bash
# Python mutation candidates. See _common.sh.
. "$(dirname "$0")/_common.sh" '#'

# Lines a statement-deletion must leave alone: keywords, declarations, assignments, logging.
no_delete='^[[:space:]]*(if|elif|else|for|while|return|raise|yield|def|class|import|from|with|try|except|finally|assert|print|pass|break|continue|lambda|del|global|nonlocal|super|logging|logger|log)([[:space:](.]|$)|(^|[^=!<>])=($|[^=>])'

# high — the whole statement or branch changes meaning
rule high delete-call       '^([[:space:]]*)([A-Za-z_][[:alnum:]_.]*\(.*\)[[:space:]]*)$'        '\1pass  # \2' "$no_delete"
rule high negate-condition  '^([[:space:]]*)(if|elif|while)[[:space:]]+(.*[^[:space:]]):[[:space:]]*$' '\1\2 not (\3):'
rule high return-none       '(^|[[:space:]])return[[:space:]]+[^[:space:]].*$'                   '\1return None'

# mid — an operator flips
rule mid  and-or            ' and '                                                              ' or '
rule mid  or-and            ' or '                                                               ' and '
rule mid  drop-negation     '(^|[[:space:](])not[[:space:]]+'                                    '\1' 'is[[:space:]]+not|not[[:space:]]+in'
rule mid  is-isnot          ' is '                                                               ' is not ' 'is[[:space:]]+not'
rule mid  isnot-is          ' is not '                                                           ' is '
rule mid  in-notin          ' in '                                                               ' not in ' 'not[[:space:]]+in|(^|[[:space:]])for[[:space:]]'
rule mid  notin-in          ' not in '                                                           ' in '
rule mid  eq-neq            ' == '                                                               ' != '
rule mid  neq-eq            ' != '                                                               ' == '
rule mid  any-all           '(^|[^[:alnum:]_.])any\('                                            '\1all('
rule mid  all-any           '(^|[^[:alnum:]_.])all\('                                            '\1any('
rule mid  min-max           '(^|[^[:alnum:]_.])min\('                                            '\1max('
rule mid  max-min           '(^|[^[:alnum:]_.])max\('                                            '\1min('
rule mid  break-continue    '^([[:space:]]*)break$'                                              '\1continue'
rule mid  continue-break    '^([[:space:]]*)continue$'                                           '\1break'

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
rule low  range-plus-one    '(^|[^[:alnum:]_.])range\((.*)\)'                                    '\1range(\2 + 1)'
rule low  true-false        '(^|[^[:alnum:]_])True([^[:alnum:]_]|$)'                             '\1False\2'
rule low  false-true        '(^|[^[:alnum:]_])False([^[:alnum:]_]|$)'                            '\1True\2'
rule low  zero-one          '(^|[^[:alnum:]_.])0([^[:alnum:]_.]|$)'                              '\11\2'
rule low  number-plus-one   '(^|[^[:alnum:]_.])([1-9][0-9]*)([^[:alnum:]_.]|$)'                  '\1(\2 + 1)\3'
rule low  empty-string      '"([^"\\]|\\.)+"|'"'"'([^'"'"'\\]|\\.)+'"'"''                        '""'

run "$1"
