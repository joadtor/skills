# Each run of like boolean operators is +1; each change of operator starts a new run.
def all3(a, b, c)
  a && b && c          # +1 (one && sequence)
end                    # 1

def mixed(a, b, c)
  a && b || c          # +1 (&&) +1 (|| starts a new sequence)
end                    # 2

def mixed_right(a, b, c)
  a || b && c          # +1 (||) +1 (&&)
end                    # 2

def words(a, b, c)
  a and b or c         # +1 (and) +1 (or): same as && and ||
end                    # 2

def negated(a, b, c)
  a && !(b && c)       # +1: ! and the parens are skipped, so it reads && &&
end                    # 1

def in_condition(a, b)
  return 1 if a || b   # +1 (modifier if) +1 (||)
end                    # 2
