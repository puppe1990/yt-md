# frozen_string_literal: true

require_relative "test_helper"
require_relative "../tools/method_mutate"

class MethodMutateTest < Minitest::Test
  def test_finds_and_and_or_operators
    sites = MethodMutate.sites_in("a && b || c")
    assert_equal ["&&", "||"], sites.map(&:from)
    assert_equal ["||", "&&"], sites.map(&:to)
  end

  def test_apply_swaps_operator_at_index
    assert_equal "a || b", MethodMutate.apply("a && b", 2, "&&", "||")
  end
end
