# frozen_string_literal: true

require_relative "../test_helper"

class CommentPageTest < YtMdTest
  def test_reads_author_text_likes_and_published_from_entities
    json = comments_page_json(
      [{ author: "@AlexHormozi", text: "roadmap here", likes: "19", published: "há 6 dias", creator: true }]
    )
    comment = YtMd::CommentPage.new(JSON.parse(json)).entries.first.comment

    assert_equal "@AlexHormozi", comment.author
    assert_equal "roadmap here", comment.text
    assert_equal "19", comment.likes
    assert_equal "há 6 dias", comment.published
    assert comment.creator
  end

  def test_blank_like_counter_becomes_nil
    json = comments_page_json([{ author: "@a", text: "great", likes: " " }])
    comment = YtMd::CommentPage.new(JSON.parse(json)).entries.first.comment

    assert_nil comment.likes
  end

  def test_exposes_next_and_reply_tokens
    json = comments_page_json(
      [{ author: "@a", text: "hi", replies: 9 }],
      next_token: "next-page",
      reply_token: "reply-page"
    )
    page = YtMd::CommentPage.new(JSON.parse(json))

    assert_equal "next-page", page.next_token
    assert_equal "reply-page", page.entries.first.reply_token
  end

  def test_entries_have_no_reply_token_for_reply_items
    json = comments_page_json([{ author: "@a", text: "reply", likes: "2" }], level: 1)
    entry = YtMd::CommentPage.new(JSON.parse(json)).entries.first

    assert_nil entry.reply_token
    assert_equal "reply", entry.comment.text
  end

  def test_reads_the_show_more_replies_button_token
    page = YtMd::CommentPage.new(
      "onResponseReceivedEndpoints" => [
        { "appendContinuationItemsAction" => { "continuationItems" => [
          { "commentViewModel" => { "commentKey" => "k", "commentId" => "c1" } },
          {
            "continuationItemRenderer" => {
              "button" => {
                "buttonRenderer" => {
                  "text" => { "runs" => [{ "text" => "Mostrar mais respostas" }] },
                  "command" => { "continuationCommand" => { "token" => "more-token" } }
                }
              }
            }
          }
        ] } }
      ]
    )

    assert_equal "more-token", page.more_replies_token
    assert_nil page.next_token
  end

  def test_more_replies_token_is_nil_without_a_button
    json = comments_page_json([{ author: "@a", text: "hi" }])
    page = YtMd::CommentPage.new(JSON.parse(json))

    assert_nil page.more_replies_token
  end

  def test_falls_back_when_entities_are_missing
    page = YtMd::CommentPage.new(
      "onResponseReceivedEndpoints" => [
        { "appendContinuationItemsAction" => { "continuationItems" => [
          { "commentViewModel" => { "commentKey" => "missing", "commentId" => "c1", "pinnedText" => "Pinned by @x" } }
        ] } }
      ]
    )
    comment = page.entries.first.comment

    assert_equal "c1", comment.id
    assert_equal "", comment.text
    assert_equal "Pinned by @x", comment.pinned
    assert_nil page.next_token
  end
end
