# Conditions, subjects, loop and rescue headers, and call arguments are scored where they stand.
def if_condition(a, b)
  if a && b                  # +1 if, +1 &&
    1
  end
end                          # 2

def elsif_condition(a, b, c)
  if a                       # +1
    1
  elsif b || c               # +1 elsif, +1 ||
    2
  end
end                          # 3

def case_subject(a, b)
  case a || b                # +1 case, +1 ||
  when 1 then :one
  end
end                          # 2

def for_collection(a, b)
  for x in a || b            # +1 for, +1 ||
    x
  end
end                          # 2

def for_target(h, xs, a)
  for h[a ? 1 : 2] in xs     # +1 for, +1 ternary in the loop target (nesting 0)
    h
  end
end                          # 2

def ternary_condition(a, b)
  a && b ? 1 : 2             # +1 ternary, +1 &&
end                          # 2

def rescue_classes(strict)
  run
rescue (strict ? ArgumentError : StandardError)  # +1 rescue, +1 ternary (nesting 0)
  nil
end                          # 2

def rescue_target(h, a)
  run
rescue => h[a ? 1 : 2]       # +1 rescue, +1 ternary in the target (nesting 0)
  nil
end                          # 2

def rescue_mod_expr(a)
  fetch(a ? 1 : 2) rescue nil  # +1 rescue modifier, +1 ternary (nesting 0)
end                          # 2

def rescue_mod_value(a)
  fetch rescue (a ? 1 : 2)   # +1 rescue modifier, +2 ternary in the fallback (nesting 1)
end                          # 3

def command_args(a)
  log a ? 1 : 2              # +1 ternary in a command's argument
end                          # 1

def comparisons(x, y)
  x > 0 && y > 0             # +1: one && sequence; comparisons are not boolean operators
end                          # 1

def statements_in_parens(a, b, c)
  a && (log(b); b || c)      # +1 &&, +1 ||: a multi-statement paren is not a grouping
end                          # 2
