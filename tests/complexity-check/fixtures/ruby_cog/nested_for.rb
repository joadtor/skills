# Same structure as Python `for i in items: if/if/if-else` = 11 under complexipy 8.3.0.
def total(items)
  t = 0
  for i in items      # +1 (nesting 0)
    if i.a            # +2 (nesting 1)
      if i.b          # +3 (nesting 2)
        if i.c        # +4 (nesting 3)
          t += 1
        else          # +1 (no nesting cost)
          t += 2
        end
      end
    end
  end
  t
end                   # 11
