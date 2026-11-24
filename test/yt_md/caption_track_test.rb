# frozen_string_literal: true

require_relative "../test_helper"

class CaptionTrackTest < YtMdTest
  def track(lang, kind: "asr", url: nil)
    {
      "languageCode" => lang,
      "kind" => kind,
      "baseUrl" => url || "https://www.youtube.com/api/timedtext?v=#{fake_video_id}&lang=#{lang}",
      "name" => { "runs" => [{ "text" => "#{lang} (auto-generated)" }] }
    }
  end

  def test_picks_requested_language
    tracks = [track("ar"), track("en"), track("pt")]

    picked = YtMd::CaptionTrack.pick(tracks, language: "en")

    assert_equal "en", picked.language
    assert_equal "asr", picked.kind
    assert_includes picked.timedtext_url, "fmt=json3"
  end

  def test_replaces_srv3_fmt_with_json3
    video_id = fake_video_id
    tracks = [track("en", url: "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=en&kind=asr&fmt=srv3")]

    picked = YtMd::CaptionTrack.pick(tracks, language: "en")

    assert_includes picked.timedtext_url, "fmt=json3"
    refute_includes picked.timedtext_url, "fmt=srv3"
  end

  def test_prefers_human_track_over_asr
    tracks = [track("en", kind: "asr"), track("en", kind: nil)]

    picked = YtMd::CaptionTrack.pick(tracks, language: "en")

    assert_nil picked.kind
  end

  def test_matches_language_prefix
    tracks = [track("en-US", kind: nil)]

    picked = YtMd::CaptionTrack.pick(tracks, language: "en")

    assert_equal "en-US", picked.language
  end

  def test_lists_available_languages_when_missing
    tracks = [track("ar"), track("de")]
    error = assert_raises(YtMd::CaptionTrack::Missing) do
      YtMd::CaptionTrack.pick(tracks, language: "pt")
    end

    assert_includes error.message, %(received "pt")
    assert_includes error.message, "ar, de"
  end
end
