# SonarSource cognitive complexity for Ruby, over Ripper's sexp. Stdlib only; Ruby 2.6+.
# Usage: ruby_cognitive.rb <root> <abs-file>...
#   stdout  one row per method: <file relative to root>:<def line> TAB <name> TAB <score>
#   exit    0, or 2 when a file could not be parsed
# Parses, never runs: files are read as text, nothing from the project is required.
require 'ripper'

class CognitiveScorer
  LOGIC = { :'&&' => :and, :and => :and, :'||' => :or, :or => :or }.freeze

  attr_reader :units

  def initialize
    @units = []
  end

  def run(sexp)
    find(sexp)
  end

  private

  # Finds the methods under node; ns = enclosing class/module names, sep = '#' (instance) or '.' (singleton)
  def find(node, ns = [], sep = '#')
    return unless node.is_a?(Array)
    return node.each { |n| find(n, ns, sep) } unless node[0].is_a?(Symbol)
    case node[0]
    when :def then score_def(node[1], node[3], ns, sep)
    when :defs then score_def(node[3], node[5], ns, '.')
    when :class, :module then find(node.drop(2), ns + [const_name(node[1])])
    when :sclass then find(node.drop(2), ns, '.')
    else node.drop(1).each { |n| find(n, ns, sep) }
    end
  end

  def const_name(node)
    consts = []
    collect = lambda do |n|
      next unless n.is_a?(Array)
      n[0] == :@const ? consts << n[1] : n.each { |c| collect.call(c) }
    end
    collect.call(node)
    consts.join('::')
  end

  def score_def(token, body, ns, sep)
    name = ns.empty? ? token[1] : "#{ns.join('::')}#{sep}#{token[1]}"
    unit = { name: name, method: token[1], line: token[2][0], score: 0, ns: ns, sep: sep }
    @units << unit
    outer = @unit
    @unit = unit
    walk(body, 0)
    @unit = outer
  end

  def inc(n)
    @unit[:score] += n
  end

  def walk(node, nesting)
    return unless node.is_a?(Array)
    return node.each { |n| walk(n, nesting) } unless node[0].is_a?(Symbol)
    case node[0]
    when :def, :defs, :class, :module, :sclass
      find(node, @unit[:ns], @unit[:sep])
    when :if, :unless
      inc(1 + nesting)
      walk(node[1], nesting)
      walk(node[2], nesting + 1)
      else_part(node[3], nesting)
    when :if_mod, :unless_mod, :while, :until, :while_mod, :until_mod
      inc(1 + nesting)
      walk(node[1], nesting)
      walk(node[2], nesting + 1)
    when :for
      inc(1 + nesting)
      walk(node[1], nesting)
      walk(node[2], nesting)
      walk(node[3], nesting + 1)
    when :case
      inc(1 + nesting)
      walk(node[1], nesting)
      clauses(node[2], nesting + 1)
    when :ifop
      inc(1 + nesting)
      walk(node[1], nesting)
      walk(node.drop(2), nesting + 1)
    when :rescue
      inc(1 + nesting)
      walk(node[1], nesting)
      walk(node[2], nesting)
      walk(node[3], nesting + 1)
      walk(node[4], nesting)
    when :rescue_mod
      inc(1 + nesting)
      walk(node[1], nesting)
      walk(node[2], nesting + 1)
    when :brace_block, :do_block, :lambda
      node.drop(1).each { |n| walk(n, nesting + 1) }
    when :fcall, :vcall, :command, :call, :command_call
      inc(1) if recursive?(node)
      node.drop(1).each { |n| walk(n, nesting) }
    when :binary
      return node.drop(1).each { |n| walk(n, nesting) } unless LOGIC[node[2]]
      ops = []
      leaves = []
      flatten(node, ops, leaves)
      inc(ops.each_with_index.count { |op, i| i.zero? || op != ops[i - 1] })
      leaves.each { |n| walk(n, nesting) }
    else
      node.drop(1).each { |n| walk(n, nesting) }
    end
  end

  # A call by the method's own name, bare (`foo`, `foo(x)`, `foo x`) or on self (`self.foo`)
  def recursive?(node)
    callee = %i[call command_call].include?(node[0]) ? (self_ref?(node[1]) && node[3]) : node[1]
    callee.is_a?(Array) && callee[0] == :@ident && callee[1] == @unit[:method]
  end

  def self_ref?(node)
    node.is_a?(Array) && node[0] == :var_ref && node[1][0, 2] == [:@kw, 'self']
  end

  # A boolean expression read left to right through parens and !, as its operators and its operands
  def flatten(node, ops, leaves)
    if node[0] == :binary && LOGIC[node[2]]
      flatten(node[1], ops, leaves)
      ops << LOGIC[node[2]]
      flatten(node[3], ops, leaves)
    elsif node[0] == :unary && %i[! not].include?(node[1])
      flatten(node[2], ops, leaves)
    elsif node[0] == :paren && node[1].is_a?(Array) && node[1].size == 1 && node[1][0].is_a?(Array)
      flatten(node[1][0], ops, leaves)
    else
      leaves << node
    end
  end

  # elsif / else of an if or unless: +1 each, no nesting cost; bodies at the if body's nesting
  def else_part(node, nesting)
    return unless node.is_a?(Array)
    inc(1)
    if node[0] == :elsif
      walk(node[1], nesting)
      walk(node[2], nesting + 1)
      else_part(node[3], nesting)
    else
      walk(node[1], nesting + 1)
    end
  end

  # when / else clauses of a case: the case already scored once, so they add nothing
  def clauses(node, nesting)
    return unless node.is_a?(Array)
    if node[0] == :else
      walk(node[1], nesting)
    else
      walk(node[1], nesting)
      walk(node[2], nesting)
      clauses(node[3], nesting)
    end
  end
end

root = ARGV.shift
status = 0
ARGV.each do |path|
  rel = path.sub("#{root}/", '')
  sexp = Ripper.sexp(File.read(path, encoding: Encoding::UTF_8))
  unless sexp
    warn "complexity: #{rel} could not be parsed — unchecked"
    status = 2
    next
  end
  scorer = CognitiveScorer.new
  scorer.run(sexp)
  scorer.units.each { |u| puts "#{rel}:#{u[:line]}\t#{u[:name]}\t#{u[:score]}" }
end
exit status
