# frozen_string_literal: true

require "json"
require_relative "../test_helper"

class JsonCommentsTest < YtMdTest
  def comment(**overrides)
    YtMd::Comment.new(
      id: "c1",
      author: "@AlexHormozi",
      creator: true,
      text: "roadmap here",
      published: "há 6 dias",
      likes: "19",
      pinned: nil,
      replies: [],
      **overrides
    )
  end

  def thread(comments, declared: "351", truncated: false)
    YtMd::CommentThread.new(
      meta: {
        video_id: "rRI0iH-cpjg",
        title: "It's Not Fun",
        channel: "Alex Hormozi",
        url: "https://www.youtube.com/watch?v=rRI0iH-cpjg"
      },
      comments: comments,
      declared_count: declared,
      truncated: truncated
    )
  end

  def document(**options)
    now = Time.utc(2026, 11, 27, 14, 18, 53.500)
    JSON.parse(YtMd::JsonComments.new(thread: thread([comment], **options), now: now).to_s)
  end

  def test_header_matches_the_capture_shape
    doc = document

    assert_equal "https://www.youtube.com/watch?v=rRI0iH-cpjg", doc["url"]
    assert_equal "rRI0iH-cpjg", doc["videoId"]
    assert_equal "It's Not Fun", doc["title"]
    assert_equal "2026-11-27T14:18:53.500Z", doc["collectedAt"]
    assert_equal "api", doc["mode"]
    refute doc["truncated"]
    assert_equal 1, doc["totalThreads"]
    assert_equal 0, doc["totalReplies"]
    assert_nil doc["visibleCommentCount"]
    assert_equal 351, doc["expectedCommentCount"]
  end

  def test_root_comment_keys_and_order
    row = document["data"].first

    assert_equal %w[index commentId author authorChannelUrl content published likes isReply repliesCount replies],
                 row.keys
    assert_equal 1, row["index"]
    assert_equal "c1", row["commentId"]
    assert_equal "@AlexHormozi", row["author"]
    assert_equal "https://www.youtube.com/@AlexHormozi", row["authorChannelUrl"]
    assert_equal "roadmap here", row["content"]
    assert_equal "há 6 dias", row["published"]
    assert_equal "19", row["likes"]
    refute row["isReply"]
    assert_equal 0, row["repliesCount"]
  end

  def test_reply_keys_and_parent_fields
    reply = comment(id: "c2", author: "@mickeypitt", creator: false, text: "OODA", likes: "1")
    doc = JSON.parse(
      YtMd::JsonComments.new(
        thread: thread([comment(replies: [reply], text: "parent text")]),
        now: Time.utc(2026)
      ).to_s
    )
    row = doc["data"].first
    reply_row = row["replies"].first

    assert_equal %w[commentId author authorChannelUrl content published likes parentCommentId parentAuthor
                    parentContentPreview replyIndex isReply], reply_row.keys
    assert_equal "c2", reply_row["commentId"]
    assert_equal "c1", reply_row["parentCommentId"]
    assert_equal "@AlexHormozi", reply_row["parentAuthor"]
    assert_equal "parent text", reply_row["parentContentPreview"]
    assert_equal 1, reply_row["replyIndex"]
    assert reply_row["isReply"]
    assert_equal 1, row["repliesCount"]
    assert_equal 1, doc["totalReplies"]
  end

  def test_preview_collapses_whitespace
    parent = comment(text: "line one\n\nline   two")
    doc = JSON.parse(
      YtMd::JsonComments.new(thread: thread([parent.tap { |c| c.replies = [comment(id: "c2")] }])).to_s
    )

    assert_equal "line one line two", doc["data"].first["replies"].first["parentContentPreview"]
  end

  def test_preview_cuts_at_utf16_limit_with_ellipsis
    long = "a" * 300
    doc = JSON.parse(
      YtMd::JsonComments.new(thread: thread([comment(text: long, replies: [comment(id: "c2")])])).to_s
    )
    preview = doc["data"].first["replies"].first["parentContentPreview"]

    assert_equal "#{'a' * 179}...", preview
  end

  def test_preview_counts_emoji_as_two_utf16_units
    text = "#{'a' * 178}🚀tail"
    doc = JSON.parse(YtMd::JsonComments.new(thread: thread([comment(text: text, replies: [comment(id: "c2")])])).to_s)
    preview = doc["data"].first["replies"].first["parentContentPreview"]

    assert_equal "#{'a' * 178}...", preview
  end

  def test_author_channel_url_keeps_non_ascii_handles_decoded
    doc = JSON.parse(
      YtMd::JsonComments.new(thread: thread([comment(author: "@FerdinandvonBürstelstrunk")])).to_s
    )

    assert_equal "https://www.youtube.com/@FerdinandvonBürstelstrunk", doc["data"].first["authorChannelUrl"]
  end

  def test_content_flattens_nbsp_and_soft_wraps
    text = "\u00A0@hrg_tv\u00A0 suboptimal\r\n\r\nDid you watch?"
    doc = JSON.parse(YtMd::JsonComments.new(thread: thread([comment(text: text)])).to_s)

    assert_equal "@hrg_tv suboptimal Did you watch?", doc["data"].first["content"]
  end

  def test_blank_like_counter_becomes_string_zero
    doc = JSON.parse(YtMd::JsonComments.new(thread: thread([comment(likes: nil)])).to_s)

    assert_equal "0", doc["data"].first["likes"]
  end

  def test_non_numeric_declared_count_stays_a_string
    doc = document(declared: "2,4 mil")

    assert_equal "2,4 mil", doc["expectedCommentCount"]
  end

  def test_truncated_flag_and_limit
    doc = document(truncated: true)

    assert doc["truncated"]
  end
end
