# frozen_string_literal: true

require_relative "method_crap"

# Structural duplication for Ruby methods. Uncle Bob's dryer does not parse .rb;
# this lever ranks method bodies after locals and literals are stripped.
module MethodDry
  STOP = MethodCrap::STOP
  Pair = Struct.new(:left, :right, :score, keyword_init: true)
  Form = Struct.new(:function, :tokens, keyword_init: true)

  module_function

  def functions_in_file(path)
    MethodCrap.functions_in_file(path).map do |function|
      Form.new(function: function, tokens: tokens_for(function))
    end
  end

  def similarity(left, right)
    union = (left.tokens | right.tokens).size
    return 0.0 if union.zero?

    (left.tokens & right.tokens).size.to_f / union
  end

  def report(lib_glob:, stdout:, threshold:, min_lines:, min_nodes:)
    forms = Dir.glob(lib_glob).flat_map { |path| functions_in_file(path) }
      .select { |form| eligible?(form, min_lines, min_nodes) }
    pairs = pair_forms(forms).select { |pair| pair.score >= threshold }
      .sort_by { |pair| -pair.score }
    print_pairs(pairs, stdout)
    pairs.empty? ? 0 : 2
  end

  def eligible?(form, min_lines, min_nodes)
    function = form.function
    lines = function.end_line - function.start_line + 1
    lines >= min_lines && form.tokens.size >= min_nodes
  end

  def pair_forms(forms)
    pairs = []
    forms.combination(2) { |left, right| pairs << Pair.new(left: left, right: right, score: similarity(left, right)) }
    pairs
  end

  def tokens_for(function)
    ast = RubyVM::AbstractSyntaxTree.parse(File.read(function.path))
    node = find_method(ast, function)
    return [] unless node

    fingerprint(node)
  end

  def find_method(node, function)
    return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
    return node if method_node?(node, function)

    node.children.each do |child|
      found = find_method(child, function)
      return found if found
    end
    nil
  end

  def method_node?(node, function)
    return false unless %i[DEFN DEFS].include?(node.type)
    return false unless node.first_lineno == function.start_line

    name = node.type == :DEFN ? node.children[0].to_s : node.children[1].to_s
    name == function.name
  end

  def fingerprint(root)
    tokens = []
    stack = [[root, true]]
    while stack.any?
      node, is_root = stack.pop
      next unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
      next if !is_root && STOP.include?(node.type)

      tokens.concat(node_tokens(node))
      node.children.each { |child| stack << [child, false] }
    end
    tokens.uniq
  end

  def node_tokens(node)
    case node.type
    when :FCALL, :VCALL
      ["call:#{node.children[0]}"]
    when :CALL, :OPCALL, :QCALL, :ATTRASGN
      ["call:#{node.children[1]}"]
    when :STR, :INTEGER, :FLOAT, :SYM, :LIT, :NIL, :TRUE, :FALSE, :DSTR
      ["lit"]
    when :LVAR, :DVAR, :IVAR, :GVAR, :CVAR, :LASGN, :DASGN, :IASGN
      ["var"]
    else
      [node.type.to_s]
    end
  end

  def print_pairs(pairs, stdout)
    stdout.puts "Dry Report"
    stdout.puts "=========="
    if pairs.empty?
      stdout.puts "No pairs at or above the threshold."
      return
    end

    pairs.each do |pair|
      left = pair.left.function
      right = pair.right.function
      stdout.printf(
        "%.2f  %s#%s (%s:%d)  %s#%s (%s:%d)\n",
        pair.score,
        left.namespace,
        left.name,
        left.path,
        left.start_line,
        right.namespace,
        right.name,
        right.path,
        right.start_line
      )
    end
  end
end
