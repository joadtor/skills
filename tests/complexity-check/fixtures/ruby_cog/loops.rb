def drain(q)
  while q.any?               # +1 (nesting 0)
    until q.ready?           # +2 (nesting 1)
      q.wait
    end
    q.pop while q.full?      # +2 (modifier while, nesting 1)
    q.push until q.ok?       # +2 (modifier until, nesting 1)
  end
end                          # 7

def grade(n)
  if n > 90                  # +1
    :a
  elsif n > 80               # +1 (no nesting cost)
    n > 85 ? :b_plus : :b    # +2 (ternary inside the elsif body: nesting 1)
  else                       # +1
    :c
  end
end                          # 5

def label(x)
  unless x                   # +1
    'none'
  else                       # +1
    x.to_s
  end
end                          # 2
