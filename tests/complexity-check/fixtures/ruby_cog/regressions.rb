# Differential regressions (agreed with complexipy, gocognit and the whitepaper). Per line:
# +1 per run of like boolean operators, +1 per `if`/`while`/ternary/recursion plus the nesting level,
# a block or lambda raises nesting without scoring itself, `else` is +1.
def and_or(a, b, c)
  a && b || c                  # +1 +1
end                            # 2

def or_and(a, b, c)
  a || b && c                  # +1 +1
end                            # 2

def and_or_and(a, b, c, d)
  a && b || c && d             # +1 +1 +1
end                            # 3

def negated_runs(a, b, c)
  !a || !(b || c)              # +1 (||) +1 (the negated group)
end                            # 2

def grouped_left(a, b, c)
  (a || b) && c                # +1 (||) +1 (&&)
end                            # 2

def grouped_both(a, b, c, d)
  (a||b)&&(c||d)               # +1 +1 +1
end                            # 3

def f(n) n.zero? ? 0 : f(n-1) end  # +1 (ternary) +1 (recursion): 2

def lambda_in_method(x)
  l = lambda do |y|            # nesting 1, no score
    if y                       # +2 (if at nesting 1)
      1
    else                       # +1
      2
    end
  end
  l.call(x)
end                            # 3

def break_in_loop(x)
  loop do                      # nesting 1, no score
    break if x                 # +2 (modifier if at nesting 1)
  end
end                            # 2

def modifier_while(a)
  x = 0
  x += 1 while a               # +1
end                            # 1
