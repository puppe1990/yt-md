# frozen_string_literal: true

require_relative "../test_helper"

class CommentPanelTest < YtMdTest
  def watch(**overrides) = JSON.parse(comments_watch_json(**overrides))

  def test_reads_title_channel_and_declared_count
    panel = YtMd::CommentPanel.new(watch(title: "Riqueza", channel: "Alex", count: "351"), video_id: "abc").parse

    assert_equal "Riqueza", panel.title
    assert_equal "Alex", panel.channel
    assert_equal "351", panel.declared_count
  end

  def test_sort_token_reads_by_position_not_localized_title
    json = watch(title: "t", channel: "c", sorts: %w[Principais Mais recentes], tokens: %w[top-tok new-tok])
    panel = YtMd::CommentPanel.new(json, video_id: "abc").parse

    assert_equal "top-tok", panel.sort_token(:top)
    assert_equal "new-tok", panel.sort_token(:newest)
  end

  def test_raises_when_comments_are_disabled
    error = assert_raises(YtMd::CommentPanel::Disabled) do
      YtMd::CommentPanel.new(watch(disabled: true), video_id: "abc").parse
    end

    assert_includes error.message, "abc"
    assert_includes error.message, YtMd::CommentPanel::PANEL_ID
  end

  def test_missing_sort_token_is_not_a_crash
    json = watch(title: "t", channel: "c", sorts: %w[Top], tokens: [nil])
    panel = YtMd::CommentPanel.new(json, video_id: "abc").parse

    assert_nil panel.sort_token(:newest)
  end
end
