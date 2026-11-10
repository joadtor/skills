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
end
