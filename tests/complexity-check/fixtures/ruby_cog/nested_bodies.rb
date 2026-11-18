# Bodies sit one nesting level inside the construct that holds them.
def case_in_if(a, b)
  if a                       # +1
    case b                   # +2 (nesting 1)
    when 1 then :one
    end
  end
end                          # 3

def when_bodies(a, b, c)
  case a                     # +1
  when (c ? 1 : 2)           # +2 ternary in a when value (nesting 1)
    1
  when 3
    b if b                   # +2 (nesting 1)
  else
    c if c                   # +2 (nesting 1)
  end
end                          # 7

def ternary_in_ternary(a, b)
  a ? (b ? 1 : 2) : 3        # +1, +2 nested ternary in the then-branch (nesting 1)
end                          # 3

def rescue_body(x)
  x.call
rescue ArgumentError         # +1
  x.reset if x               # +2 (nesting 1)
end                          # 3

def else_body(a, b)
  if a                       # +1
    1
  else                       # +1
    2 if b                   # +2 (nesting 1)
  end
end                          # 4
