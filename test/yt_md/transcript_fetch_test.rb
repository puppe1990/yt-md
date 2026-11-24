# frozen_string_literal: true

require_relative "../test_helper"

class TranscriptFetchTest < YtMdTest
  FakeHttp = Struct.new(:gets, :posts, keyword_init: true) do
    def get(url)
      gets.fetch(url) { raise "unexpected GET #{url}" }
    end

    def post(url, json:)
      raise "unexpected POST #{url}" unless url.include?("/youtubei/v1/player")
      raise "missing videoId" unless json.dig("context", "client", "clientName") == "ANDROID"

      posts.fetch(json.fetch("videoId"))
    end
  end

  def player_for(video_id, timedtext_url)
    JSON.generate(
      "playabilityStatus" => { "status" => "OK" },
      "videoDetails" => {
        "videoId" => video_id,
        "title" => "Why AI Has DHH Working 16-Hour Days",
        "author" => "a16z",
        "lengthSeconds" => "3135"
      },
      "captions" => {
        "playerCaptionsTracklistRenderer" => {
          "captionTracks" => [
            {
              "languageCode" => "en",
              "kind" => "asr",
              "baseUrl" => timedtext_url
            }
          ]
        }
      }
    )
  end

  def test_fetches_player_then_timedtext
    video_id = fake_video_id
    timedtext_url = "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=en&kind=asr"
    json3 = json3_body([{ start_ms: 160, text: ["Mac OS and Windows are just unfit"] }])
    http = FakeHttp.new(
      posts: { video_id => player_for(video_id, timedtext_url) },
      gets: { "#{timedtext_url}&fmt=json3" => json3 }
    )

    result = YtMd::TranscriptFetch.new(http: http).call(video_id, language: "en")

    assert_equal "Why AI Has DHH Working 16-Hour Days", result.meta[:title]
    assert_equal "a16z", result.meta[:channel]
    assert_equal "en", result.meta[:language]
    assert_equal "asr", result.meta[:kind]
    assert_includes result.cues.plain_text, "Mac OS and Windows are just unfit"
  end
end
