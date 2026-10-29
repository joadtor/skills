class Order
  def total(x)
    r = 0
    r += 0 if x == 0
    r += 1 if x == 1
    r += 2 if x == 2
    r += 3 if x == 3
    r += 4 if x == 4
    r += 5 if x == 5
    r += 6 if x == 6
    r += 7 if x == 7
    r
  end
end
