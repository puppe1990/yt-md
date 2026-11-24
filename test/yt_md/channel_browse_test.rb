# frozen_string_literal: true

require_relative "../test_helper"

class ChannelBrowseTest < YtMdTest
  FakeHttp = Struct.new(:posts, keyword_init: true) do
    def post(url, json:, **_)
      return posts.fetch(json.fetch("url")) if url.include?("resolve_url")

      if url.include?("/browse")
        key = json["continuation"] || json["browseId"]
        return posts.fetch(key)
      end
      raise "unexpected POST #{url}"
    end
  end

  def lockup(video_id, title)
    {
      "richItemRenderer" => {
        "content" => {
          "lockupViewModel" => {
            "contentId" => video_id,
            "contentType" => "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata" => {
              "lockupMetadataViewModel" => {
                "title" => { "content" => title }
              }
            }
          }
        }
      }
    }
  end

  def continuation_item(token)
    {
      "continuationItemRenderer" => {
        "continuationEndpoint" => {
          "continuationCommand" => {
            "token" => token,
            "request" => "CONTINUATION_REQUEST_TYPE_BROWSE"
          }
        }
      }
    }
  end

  def videos_page(items)
    JSON.generate(
      "metadata" => {
        "channelMetadataRenderer" => {
          "title" => "a16z",
          "externalId" => "UC9cn0TuPq4dnbTY-CBsm8XA"
        }
      },
      "contents" => {
        "twoColumnBrowseResultsRenderer" => {
          "tabs" => [
            { "tabRenderer" => { "title" => "Home" } },
            {
              "tabRenderer" => {
                "selected" => true,
                "title" => "Videos",
                "content" => { "richGridRenderer" => { "contents" => items } }
              }
            }
          ]
        }
      }
    )
  end

  def continuation_page(items)
    JSON.generate(
      "onResponseReceivedActions" => [
        { "appendContinuationItemsAction" => { "continuationItems" => items } }
      ]
    )
  end

  def resolve_body(browse_id)
    JSON.generate("endpoint" => { "browseEndpoint" => { "browseId" => browse_id } })
  end

  def test_lists_lockup_videos_and_follows_continuation
    first_id = fake_video_id
    second_id = fake_video_id
    first_title = fake_title
    second_title = fake_title
    browse_id = "UC#{Faker::Alphanumeric.alphanumeric(number: 22)}"
    token = Faker::Alphanumeric.alphanumeric(number: 24)
    http = FakeHttp.new(
      posts: {
        browse_id => videos_page([lockup(first_id, first_title), continuation_item(token)]),
        token => continuation_page([lockup(second_id, second_title)])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id))

    assert_equal [first_id, second_id], videos.map(&:video_id)
    assert_equal [first_title, second_title], videos.map(&:title)
  end

  def test_resolves_handle_via_resolve_url
    browse_id = "UC#{Faker::Alphanumeric.alphanumeric(number: 22)}"
    video_id = fake_video_id
    title = fake_title
    http = FakeHttp.new(
      posts: {
        "https://www.youtube.com/@a16z" => resolve_body(browse_id),
        browse_id => videos_page([lockup(video_id, title)])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse("@a16z"))

    assert_equal [video_id], videos.map(&:video_id)
    assert_equal [title], videos.map(&:title)
  end

  def test_limit_does_not_request_the_next_browse_page
    first_id = fake_video_id
    browse_id = "UC#{Faker::Alphanumeric.alphanumeric(number: 22)}"
    token = Faker::Alphanumeric.alphanumeric(number: 24)
    http = FakeHttp.new(
      posts: {
        browse_id => videos_page([lockup(first_id, fake_title), continuation_item(token)])
      }
    )

    videos = YtMd::ChannelBrowse.new(http: http).videos(YtMd::ChannelRef.parse(browse_id), limit: 1)

    assert_equal [first_id], videos.map(&:video_id)
  end
end
