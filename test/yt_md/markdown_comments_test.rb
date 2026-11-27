# frozen_string_literal: true

require_relative "../test_helper"

class MarkdownCommentsTest < YtMdTest
  def thread(comments, declared: "351", truncated: false)
    YtMd::CommentThread.new(
      meta: {
        title: "It's Not Fun, But It Will Make You Rich",
        channel: "Alex Hormozi",
        url: "https://www.youtube.com/watch?v=abc"
      },
      comments: comments,
      declared_count: declared,
      truncated: truncated
    )
  end

  def comment(**overrides)
    YtMd::Comment.new(
      id: "c1",
      author: "@AlexHormozi",
      creator: true,
      text: "roadmap here",
      published: "há 6 dias",
      likes: "19",
      pinned: "Pinned by @AlexHormozi",
      replies: [],
      **overrides
    )
  end

  def test_renders_header_and_byline
    markdown = YtMd::MarkdownComments.new(thread: thread([comment])).to_s

    assert_includes markdown, "# It's Not Fun, But It Will Make You Rich — comentários"
    assert_includes markdown, "- Canal: Alex Hormozi"
    assert_includes markdown, "- Fonte: https://www.youtube.com/watch?v=abc"
    assert_includes markdown, "- Ordem: principais"
    assert_includes markdown, "- Comentários: 1"
    assert_includes markdown, "### @AlexHormozi · canal · há 6 dias · 19 likes"
    assert_includes markdown, "roadmap here"
  end

  def test_newest_label
    markdown = YtMd::MarkdownComments.new(thread: thread([comment]), sort: :newest).to_s

    assert_includes markdown, "- Ordem: mais recentes"
  end

  def test_truncated_count_shows_declared_total
    markdown = YtMd::MarkdownComments.new(thread: thread([comment], declared: "351", truncated: true)).to_s

    assert_includes markdown, "- Comentários: 1 (YouTube informa 351)"
  end

  def test_omits_a_missing_like_count
    markdown = YtMd::MarkdownComments.new(thread: thread([comment(likes: nil, pinned: nil)])).to_s

    refute_includes markdown, "likes"
  end

  def test_quotes_replies
    reply = comment(author: "@mickeypitt", creator: false, likes: "1", pinned: nil, replies: [])
    markdown = YtMd::MarkdownComments.new(thread: thread([comment(replies: [reply])])).to_s

    assert_includes markdown, "**@mickeypitt · há 6 dias · 1 likes**"
    assert_includes markdown, "> roadmap here"
  end
end
