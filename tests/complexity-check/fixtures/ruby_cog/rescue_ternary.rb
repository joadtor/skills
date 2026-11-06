# rescue and the ternary score +1 plus nesting; blocks and lambdas raise nesting without an increment.
def fetch_all(items)
  items.each do |i|          # 0, nesting -> 1
    begin                    # 0: begin is not counted
      i.fetch
    rescue IOError           # +2 (1 + nesting 1)
      i.ok? ? retry : i.skip # +3 (ternary inside the rescue body: nesting 2)
    rescue StandardError     # +2 (each rescue clause)
      i.fail
    else                     # 0: the else of begin/rescue is not counted
      i.done
    ensure                   # 0: ensure is not counted
      i.close
    end
  end
end                          # 7

def values(items)
  items.map { |i| i.ok? ? i.value : 0 }  # 0 block, +2 ternary (nesting 1)
end                          # 2

def handler
  ->(v) { v ? 1 : 2 }        # 0 lambda, +2 ternary (nesting 1)
end                          # 2

def safe(x)
  x.call rescue nil          # +1: a rescue modifier counts like a catch
end                          # 1

def safe_in_block(xs)
  xs.map { |x| x.call rescue nil }  # +2 (rescue modifier at nesting 1)
end                          # 2

def method_rescue(x)
  x.call
rescue ArgumentError         # +1 (a rescue clause of the method body, nesting 0)
  nil
end                          # 1
