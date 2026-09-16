#!/usr/bin/env bash
# Ruby mutation candidates. Protocol and rule syntax: see _common.sh.
. "$(dirname "$0")/_common.sh" '#'

# Lines a statement-deletion must leave alone: keywords, declarations, assignments, continuations.
no_delete='^[[:space:]]*(end|else|elsif|ensure|rescue|begin|do|def|class|module|if|unless|while|until|case|when|then|return|yield|next|break|super|private|protected|public|require|require_relative|include|extend|attr_reader|attr_writer|attr_accessor|puts|p|pp|logger|Rails\.logger)([[:space:](.]|$)|(^|[^=!<>~])=($|[^=~>])|[[:space:]]do([[:space:]]*\|[^|]*\|)?[[:space:]]*$|[{(,\\|][[:space:]]*$'

# high — the whole line or branch changes meaning
rule high delete-call       '^([[:space:]]*)([A-Za-z_@$][[:alnum:]_:@.]*[!?]?([[:space:](].*)?)$' '\1# \2' "$no_delete"
rule high if-unless         '(^|[^[:alnum:]_.])if([[:space:](])'                                 '\1unless\2'
rule high unless-if         '(^|[^[:alnum:]_.])unless([[:space:](])'                             '\1if\2'
rule high while-until       '(^|[^[:alnum:]_.])while([[:space:](])'                              '\1until\2'
rule high return-nil        '(^|[[:space:]])return[[:space:]]+[^[:space:]].*$'                   '\1return nil'

# mid — an operator or predicate flips
rule mid  and-or            ' && '                                                               ' || '
rule mid  or-and            ' \|\| '                                                             ' \&\& '
rule mid  and-or-word       '(^|[[:space:]])and([[:space:]])'                                    '\1or\2'
rule mid  or-and-word       '(^|[[:space:]])or([[:space:]])'                                     '\1and\2'
rule mid  drop-negation     '(^|[^[:alnum:]_!])!([[:alpha:]_(@])'                                '\1\2'
rule mid  eq-neq            ' == '                                                               ' != '
rule mid  neq-eq            ' != '                                                               ' == '
rule mid  present-blank     '\.present\?'                                                        '.blank?'
rule mid  blank-present     '\.blank\?'                                                          '.present?'
rule mid  any-none          '\.any\?'                                                            '.none?'
rule mid  empty-any         '\.empty\?'                                                          '.any?'
rule mid  nil-present       '\.nil\?'                                                            '.present?'
rule mid  drop-safe-nav     '&\.'                                                                '.'
rule mid  or-assign         ' \|\|= '                                                            ' = '

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
rule low  first-last        '\.first([^[:alnum:]_]|$)'                                           '.last\1'
rule low  last-first        '\.last([^[:alnum:]_]|$)'                                            '.first\1'
rule low  true-false        '(^|[^[:alnum:]_])true([^[:alnum:]_?]|$)'                            '\1false\2'
rule low  false-true        '(^|[^[:alnum:]_])false([^[:alnum:]_?]|$)'                           '\1true\2'
rule low  zero-one          '(^|[^[:alnum:]_.])0([^[:alnum:]_.]|$)'                              '\11\2'
rule low  number-plus-one   '(^|[^[:alnum:]_.])([1-9][0-9]*)([^[:alnum:]_.]|$)'                  '\1(\2 + 1)\3'
rule low  empty-string      '"([^"\\]|\\.)+"'                                                    '""'

run "$1"
