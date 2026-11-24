# frozen_string_literal: true

require "stringio"

require_relative "test_helper"
require_relative "../tools/method_dry"

class MethodDryTest < Minitest::Test
  SAMPLE = File.expand_path("fixtures/method_dry_sample.rb", __dir__)

  def functions
    MethodDry.functions_in_file(SAMPLE)
  end

  def named(name)
    functions.find { |form| form.function.name == name }
  end

  def test_renamed_locals_still_rank_as_duplicates
    score = MethodDry.similarity(named("pick_video"), named("choose_video"))
    assert_operator score, :>=, 0.8
  end

  def test_different_shape_stays_below_threshold
    score = MethodDry.similarity(named("pick_video"), named("sum_lengths"))
    assert_operator score, :<, 0.8
  end

  def test_report_lists_pairs_at_or_above_threshold
    stdout = StringIO.new
    status = MethodDry.report(
      lib_glob: SAMPLE,
      stdout: stdout,
      threshold: 0.8,
      min_lines: 4,
      min_nodes: 8
    )
    assert_equal 2, status
    assert_includes stdout.string, "pick_video"
    assert_includes stdout.string, "choose_video"
  end
end
