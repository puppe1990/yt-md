# frozen_string_literal: true

require_relative "../test_helper"

class CommentFetchTest < YtMdTest
  def sample(tokens: nil, rows: [], page: nil, next_token: nil, replies: nil)
    video_id = fake_video_id
    tokens ||= %w[top-token new-token]
    page ||= comments_page_json(rows, next_token: next_token)
    posts = { video_id => comments_watch_json(tokens: tokens) }
    posts[tokens.first] = page
    posts["reply-token"] = replies if replies
    {
      video_id: video_id,
      tokens: tokens,
      http: FakeInnertube.new(posts: posts),
      url: "https://www.youtube.com/watch?v=#{video_id}"
    }
  end

  def test_collects_top_level_comments
    rows = [{ author: "@a", text: "first", likes: "5" }, { author: "@b", text: "second" }]
    fixture = sample(rows: rows)

    thread = YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])

    assert_equal %w[first second], thread.comments.map(&:text)
    assert_equal fixture[:url], thread.meta[:url]
    refute thread.truncated
  end

  def test_follows_next_page_tokens
    first = comments_page_json([{ author: "@a", text: "one" }], next_token: "page-2")
    second = comments_page_json([{ author: "@b", text: "two" }])
    fixture = sample(page: first)
    fixture[:http].posts["page-2"] = second

    thread = YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])

    assert_equal %w[one two], thread.comments.map(&:text)
  end

  def test_newest_sort_uses_the_second_menu_token
    fixture = sample(rows: [{ author: "@a", text: "x" }])
    fixture[:http].posts["new-token"] = comments_page_json([{ author: "@n", text: "newest" }])

    thread = YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id], sort: :newest)

    assert_equal ["newest"], thread.comments.map(&:text)
  end

  def test_fetches_replies_for_a_thread
    page = comments_page_json([{ author: "@a", text: "parent", replies: 2 }], reply_token: "reply-token")
    replies = comments_page_json([{ author: "@r", text: "child", likes: "1" }], level: 1)
    fixture = sample(page: page, replies: replies)

    thread = YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])

    assert_equal ["child"], thread.comments.first.replies.map(&:text)
    assert_equal "1", thread.comments.first.replies.first.likes
  end

  def test_follows_the_show_more_replies_button
    page = comments_page_json([{ author: "@a", text: "parent", replies: 9 }], reply_token: "reply-token")
    first = comments_page_json([{ author: "@r", text: "child one" }], level: 1, more_token: "more-token")
    more = comments_page_json([{ author: "@r2", text: "child two" }], level: 1)
    fixture = sample(page: page, replies: first)
    fixture[:http].posts["more-token"] = more

    thread = YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])

    assert_equal ["child one", "child two"], thread.comments.first.replies.map(&:text)
  end

  def test_limit_stops_and_marks_truncated
    rows = [{ author: "@a", text: "one" }, { author: "@b", text: "two" }, { author: "@c", text: "three" }]
    fixture = sample(rows: rows)

    thread = YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id], limit: 2)

    assert_equal %w[one two], thread.comments.map(&:text)
    assert thread.truncated
  end

  def test_watch_page_is_requested_in_english_for_the_original_title
    fixture = sample(rows: [{ author: "@a", text: "one" }])
    YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])

    watch = fixture[:http].post_calls.first
    assert_equal "en", watch.dig("context", "client", "hl")
  end

  def test_continuations_are_requested_in_portuguese_for_localized_dates
    fixture = sample(rows: [{ author: "@a", text: "one" }])
    YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])

    continuation = fixture[:http].post_calls.last
    assert_equal "pt", continuation.dig("context", "client", "hl")
    assert_equal "top-token", continuation["continuation"]
  end

  def test_raises_when_sort_token_is_missing
    fixture = sample(tokens: [nil, nil])

    error = assert_raises(YtMd::CommentPanel::Disabled) do
      YtMd::CommentFetch.new(http: fixture[:http]).call(fixture[:video_id])
    end
    assert_includes error.message, fixture[:video_id]
  end
end
