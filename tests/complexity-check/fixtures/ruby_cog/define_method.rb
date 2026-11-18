class Widget
  define_method(:risky) do |a, b|
    if a                         # +1
      if b                       # +2 (nested)
        1
      end
    end
  end                            # Widget#risky = 3

  define_singleton_method :build do |x|
    x if x                       # +1
  end                            # Widget.build = 1

  define_method(:plain) { |x| x ? 1 : 2 }   # +1 (ternary): Widget#plain = 1

  helper(:other) do |x|
    x if x                       # a DSL block that is not define_method: no unit
  end

  define_method(name) { |x| x if x }  # a computed name: not a unit

  included do
    def tally(x)
      x if x                     # +1
    end                          # Widget#tally = 1: a def inside a DSL block is still a method
  end

  Class.new do
    def call(x)
      x ? 1 : 2                  # +1
    end                          # Widget#call = 1: a def in a block's receiver is still a method
  end.tap { |k| k }

  define_method(:wrap) do
    def inner(x)
      x if x                     # +1
    end                          # Widget#inner = 1, listed once
  end                            # Widget#wrap = 0
end
