# frozen_string_literal: true

require_relative "../test_helper"

class TranscriptFetchTest < YtMdTest
  def test_fetches_player_then_timedtext
    video_id = fake_video_id
    timedtext_url = timedtext_url_for(video_id)
    json3 = json3_body([{ start_ms: 160, text: ["Mac OS and Windows are just unfit"] }])
    http = FakeInnertube.new(
      posts: {
        video_id => player_payload_json(
          video_id: video_id,
          title: "Why AI Has DHH Working 16-Hour Days",
          channel: "a16z",
          timedtext_url: timedtext_url
        )
      },
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
