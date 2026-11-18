# +1 for each direct call to the enclosing method's own name.
def fact(n)
  return 1 if n <= 1          # +1 (modifier if)
  n * fact(n - 1)             # +1 (recursion)
end                           # 2

def countdown(n)
  countdown n - 1 unless n.zero?  # +1 (modifier unless) +1 (recursion, command form)
end                           # 2

def walk(node)
  node.children.each { |c| self.walk(c) }  # 0 block, +1 (recursion through self)
end                           # 1

def poll
  poll                        # +1 (recursion, bare name)
end                           # 1

def size(list)
  list.size + other.size(1)   # 0: same name on another receiver is not recursion
end                           # 0

def drain(q)
  self.drain q.rest if q      # +1 (modifier if) +1 (recursion through self, command form)
end                           # 2
