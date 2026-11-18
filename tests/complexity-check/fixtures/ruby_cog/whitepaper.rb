# The whitepaper's Java examples, ported. Java sumOfPrimes = 7, but 1 of that is `continue OUT` (a jump to a
# label). Ruby has no labels, so the jump becomes a flag checked after the inner loop: a real conditional.
def sum_of_primes(max)
  total = 0
  for i in 1..max         # +1 (nesting 0)
    prime = true
    for j in 2...i        # +2 (nesting 1)
      if i % j == 0       # +3 (nesting 2)
        prime = false
        break             # 0: break is not counted
      end
    end
    next unless prime     # +2 (modifier unless, nesting 1) in place of Java's +1 for `continue OUT`
    total += i
  end
  total
end                       # 8 = 7 - 1 + 2

def get_words(number)
  case number             # +1 (once for the whole case)
  when 1 then "one"
  when 2 then "a couple"
  when 3 then "a few"
  else "lots"             # 0: a case's else adds nothing (the whitepaper scores the switch once)
  end
end                       # 1
