# frozen_string_literal: true

require_relative "../test_helper"

class ChannelBrowseTest < YtMdTest
  def test_lists_lockup_videos_and_follows_continuation
    first_id = fake_video_id
    second_id = fake_video_id
    first_title = fake_title
    second_title = fake_title
    browse_id = fake_browse_id
    token = Faker::Alphanumeric.alphanumeric(number: 24)
    http = FakeInnertube.new(
      posts: {
        browse_id => videos_tab_page(
          [videos_tab_lockup(first_id, first_title), videos_tab_continuation(token)]
        ),
        token => videos_tab_continuation_page([videos_tab_lockup(second_id, second_title)])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id))

    assert_equal [first_id, second_id], videos.map(&:video_id)
    assert_equal [first_title, second_title], videos.map(&:title)
  end

  def test_resolves_handle_via_resolve_url
    browse_id = fake_browse_id
    video_id = fake_video_id
    title = fake_title
    http = FakeInnertube.new(
      posts: {
        "https://www.youtube.com/@a16z" => resolve_url_json(browse_id),
        browse_id => videos_tab_page([videos_tab_lockup(video_id, title)])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse("@a16z"))

    assert_equal [video_id], videos.map(&:video_id)
    assert_equal [title], videos.map(&:title)
  end

  def test_limit_does_not_request_the_next_browse_page
    first_id = fake_video_id
    browse_id = fake_browse_id
    token = Faker::Alphanumeric.alphanumeric(number: 24)
    http = FakeInnertube.new(
      posts: {
        browse_id => videos_tab_page(
          [videos_tab_lockup(first_id, fake_title), videos_tab_continuation(token)]
        )
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id), limit: 1)

    assert_equal [first_id], videos.map(&:video_id)
  end

  def test_lists_a_video_whose_id_equals_the_previous_continuation_token
    browse_id = fake_browse_id
    first_id = fake_video_id
    token = fake_video_id
    http = FakeInnertube.new(
      posts: {
        browse_id => videos_tab_page(
          [videos_tab_lockup(first_id, fake_title), videos_tab_continuation(token)]
        ),
        token => videos_tab_continuation_page([videos_tab_lockup(token, fake_title)])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id))

    assert_equal [first_id, token], videos.map(&:video_id)
  end

  def test_does_not_browse_again_when_the_page_has_no_continuation
    browse_id = fake_browse_id
    video_id = fake_video_id
    http = FakeInnertube.new(
      posts: { browse_id => videos_tab_page([videos_tab_lockup(video_id, fake_title)]) }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id))

    assert_equal [video_id], videos.map(&:video_id)
    assert_equal 1, http.post_calls.size
  end

  def test_does_not_follow_a_continuation_on_an_empty_page
    browse_id = fake_browse_id
    token = Faker::Alphanumeric.alphanumeric(number: 24)
    http = FakeInnertube.new(
      posts: {
        browse_id => videos_tab_page([videos_tab_continuation(token)]),
        token => videos_tab_continuation_page([])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id))

    assert_empty videos
    assert_equal 1, http.post_calls.size
  end

  def test_raises_when_resolve_url_has_no_browse_id
    http = FakeInnertube.new(
      posts: { "https://www.youtube.com/@a16z" => JSON.generate("endpoint" => {}) }
    )

    error = assert_raises(YtMd::ChannelBrowse::Missing) do
      YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse("@a16z"))
    end
    assert_match(/no browseId/, error.message)
    assert_match(/@a16z/, error.message)
  end

  def test_uses_the_videos_tab_when_none_is_marked_selected
    browse_id = fake_browse_id
    video_id = fake_video_id
    title = fake_title
    http = FakeInnertube.new(
      posts: {
        browse_id => JSON.generate(
          "contents" => {
            "twoColumnBrowseResultsRenderer" => {
              "tabs" => [
                { "tabRenderer" => { "title" => "Home" } },
                {
                  "tabRenderer" => {
                    "title" => "Videos",
                    "content" => {
                      "richGridRenderer" => { "contents" => [videos_tab_lockup(video_id, title)] }
                    }
                  }
                }
              ]
            }
          }
        )
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id))

    assert_equal [video_id], videos.map(&:video_id)
    assert_equal [title], videos.map(&:title)
  end
end
