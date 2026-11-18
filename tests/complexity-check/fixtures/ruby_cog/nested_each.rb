# nested_for.rb with an each block instead of the for loop: a block raises nesting but adds no +1.
def total(items)
  t = 0
  items.each do |i|   # 0, nesting -> 1
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
end                   # 10
