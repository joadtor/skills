def helper(x)
  x if x                     # +1
end                          # helper = 1

class Order
  def total(x)
    x if x                   # +1
  end                        # Order#total = 1

  def self.build(x)
    x if x                   # +1
  end                        # Order.build = 1

  class << self
    def make(x)
      x if x                 # +1
    end                      # Order.make = 1
  end
end

module Shop
  class Order
    def total(x)
      x if x                 # +1
    end                      # Shop::Order#total = 1

    def outer(x)
      def inner(y)
        y if y && y.ok?      # +1 (modifier if) +1 (&&)
      end                    # Shop::Order#inner = 2, its own unit
      x if x                 # +1
    end                      # Shop::Order#outer = 1: inner's score is not added
  end
end

class Shop::Cart
  def items(x)
    x if x                   # +1
  end                        # Shop::Cart#items = 1
end
