# frozen_string_literal: true

require "json"

# McCabe + CRAP for Ruby methods. Uncle Bob's crapper does not parse .rb;
# this lever scores lib/ with the same formula: CC² × (1 − coverage)³ + CC.
module MethodCrap
  DECISIONS = %i[IF UNLESS WHILE UNTIL FOR WHEN AND OR].freeze
  STOP = %i[DEFN DEFS CLASS MODULE].freeze

  Function = Struct.new(:name, :namespace, :complexity, :start_line, :end_line, :path, keyword_init: true)
  Entry = Struct.new(:function, :coverage, :crap, keyword_init: true)

  module_function

  def functions_in_file(path)
    source = File.read(path)
    ast = RubyVM::AbstractSyntaxTree.parse(source)
    found = []
    walk_namespace(ast, [], path, found)
    found
  end

  def crap_score(complexity, coverage_pct)
    uncovered = 1.0 - (coverage_pct.to_f / 100.0)
    (complexity * complexity * uncovered * uncovered * uncovered) + complexity
  end

  def line_coverage_percent(lines, start_line, end_line)
    return 0.0 if lines.nil?

    slice = Array(lines)[(start_line - 1)...end_line] || []
    relevant = slice.compact
    return 0.0 if relevant.empty?

    100.0 * relevant.count(&:positive?) / relevant.size
  end

  def load_line_map(resultset_path)
    return {} unless File.file?(resultset_path)

    payload = JSON.parse(File.read(resultset_path))
    merged = {}
    payload.each_value do |run|
      (run["coverage"] || {}).each do |file, record|
        merged[File.expand_path(file)] = coverage_lines(record)
      end
    end
    merged
  end

  def score_function(function, line_map)
    lines = line_map[File.expand_path(function.path)]
    coverage = line_coverage_percent(lines, function.start_line, function.end_line)
    Entry.new(function: function, coverage: coverage, crap: crap_score(function.complexity, coverage))
  end

  def report(lib_glob:, resultset_path:, stdout:, threshold:)
    line_map = load_line_map(resultset_path)
    entries = Dir.glob(lib_glob).flat_map { |path| functions_in_file(path) }
      .map { |function| score_function(function, line_map) }
      .sort_by { |entry| -entry.crap }
    print_table(entries, stdout)
    return 2 if entries.any? { |entry| entry.crap >= threshold }

    0
  end

  def walk_namespace(node, namespace, path, found)
    return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)

    case node.type
    when :MODULE, :CLASS
      name = const_name(node.children[0])
      child_ns = name ? namespace + [name] : namespace
      node.children.each { |child| walk_namespace(child, child_ns, path, found) }
    when :DEFN
      found << build_function(node, node.children[0].to_s, namespace, path)
      node.children.each { |child| walk_namespace(child, namespace, path, found) }
    when :DEFS
      found << build_function(node, node.children[1].to_s, namespace, path)
      node.children.each { |child| walk_namespace(child, namespace, path, found) }
    else
      node.children.each { |child| walk_namespace(child, namespace, path, found) }
    end
  end

  def build_function(node, name, namespace, path)
    Function.new(
      name: name,
      namespace: namespace.join("::"),
      complexity: complexity(node),
      start_line: node.first_lineno,
      end_line: node.last_lineno,
      path: path
    )
  end

  def complexity(root)
    score = 1
    stack = [[root, true]]
    while stack.any?
      node, is_root = stack.pop
      next unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
      next if !is_root && STOP.include?(node.type)

      score += 1 if DECISIONS.include?(node.type)
      score += 1 if node.type == :RESBODY
      node.children.each { |child| stack << [child, false] }
    end
    score
  end

  def const_name(node)
    return node.to_s if node.is_a?(Symbol)
    return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
    return unless %i[COLON2 COLON3 CONST].include?(node.type)

    node.children.reverse.each do |child|
      found = const_name(child)
      return found if found
      return child.to_s if child.is_a?(Symbol)
    end
    nil
  end

  def coverage_lines(record)
    return record if record.is_a?(Array)

    record["lines"]
  end

  def print_table(entries, stdout)
    stdout.puts "CRAP Report"
    stdout.puts "==========="
    stdout.printf "%-8s %-8s %-8s %s\n", "CC", "Cov%", "CRAP", "Function"
    stdout.puts "-" * 72
    entries.each do |entry|
      fn = entry.function
      stdout.printf(
        "%-8d %-8.1f %-8.2f %s#%s  %s:%d\n",
        fn.complexity,
        entry.coverage,
        entry.crap,
        fn.namespace,
        fn.name,
        fn.path,
        fn.start_line
      )
    end
  end
end
