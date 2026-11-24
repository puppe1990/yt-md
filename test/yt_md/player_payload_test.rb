# frozen_string_literal: true

require_relative "../test_helper"

class PlayerPayloadTest < YtMdTest
  def test_reads_video_details_and_tracks
    video_id = fake_video_id
    title = fake_title
    channel = fake_channel
    payload = YtMd::PlayerPayload.parse(
      player_payload_json(
        video_id: video_id,
        title: title,
        channel: channel,
        tracks: [
          {
            "languageCode" => "en",
            "kind" => "asr",
            "baseUrl" => "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=en"
          }
        ]
      )
    )

    assert_equal video_id, payload.video_id
    assert_equal title, payload.title
    assert_equal channel, payload.channel
    assert_equal 3135, payload.duration_seconds
    assert_equal 1, payload.tracks.length
  end

  def test_rejects_unplayable_status
    video_id = fake_video_id
    body = player_payload_json(
      video_id: video_id,
      tracks: [],
      status: "LOGIN_REQUIRED",
      reason: "Sign in"
    )
    error = assert_raises(YtMd::PlayerPayload::Unplayable) { YtMd::PlayerPayload.parse(body) }

    assert_includes error.message, %(received "LOGIN_REQUIRED")
    assert_includes error.message, "Sign in"
  end

  def test_rejects_missing_caption_tracks
    body = player_payload_json(video_id: fake_video_id, tracks: [])
    error = assert_raises(YtMd::PlayerPayload::Unplayable) { YtMd::PlayerPayload.parse(body) }

    assert_match(/no captionTracks/, error.message)
  end
end
