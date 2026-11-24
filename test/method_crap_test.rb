# frozen_string_literal: true

require "stringio"

require_relative "test_helper"
require_relative "../tools/method_crap"

class MethodCrapTest < Minitest::Test
  SAMPLE = File.expand_path("fixtures/method_crap_sample.rb", __dir__)

  def functions
    MethodCrap.functions_in_file(SAMPLE)
  end

  def named(name, namespace: "SampleNs::Box")
    functions.find { |function| function.name == name && function.namespace == namespace }
  end

  def test_plain_method_has_complexity_one
    function = named("plain")
    assert_equal 1, function.complexity
    assert_equal SAMPLE, function.path
  end

  def test_if_modifier_adds_one_decision
    assert_equal 2, named("guarded").complexity
  end

  def test_and_adds_one_decision
    assert_equal 2, named("anded").complexity
  end

  def test_rescue_clause_adds_one_decision
    assert_equal 2, named("rescued").complexity
  end

  def test_nested_class_namespace
    function = named("inner_plain", namespace: "SampleNs::Box::Inner")
    refute_nil function
    assert_equal 1, function.complexity
  end

  def test_crap_at_zero_coverage_is_cc_squared_plus_cc
    assert_in_delta 30.0, MethodCrap.crap_score(5, 0.0), 0.0001
  end

  def test_crap_at_full_coverage_equals_complexity
    assert_in_delta 5.0, MethodCrap.crap_score(5, 100.0), 0.0001
  end

  def test_crap_at_half_coverage
    assert_in_delta 8.125, MethodCrap.crap_score(5, 50.0), 0.0001
  end

  def test_line_coverage_percent_for_a_span
    lines = [nil, 1, 1, 0, nil, 1]
    assert_in_delta 75.0, MethodCrap.line_coverage_percent(lines, 2, 6), 0.0001
  end

  def test_missing_lines_count_as_zero_coverage
    assert_in_delta 0.0, MethodCrap.line_coverage_percent(nil, 1, 4), 0.0001
  end

  def test_report_exits_two_when_crap_meets_threshold
    Dir.mktmpdir do |dir|
      stdout = StringIO.new
      status = MethodCrap.report(
        lib_glob: SAMPLE,
        resultset_path: File.join(dir, "missing.json"),
        stdout: stdout,
        threshold: 5
      )
      assert_equal 2, status
      assert_includes stdout.string, "CRAP Report"
    end
  end

  def test_report_passes_when_threshold_is_above_zero_coverage_crap
    stdout = StringIO.new
    status = MethodCrap.report(
      lib_glob: SAMPLE,
      resultset_path: "coverage/.resultset.json",
      stdout: stdout,
      threshold: 100
    )
    assert_equal 0, status
  end
end
