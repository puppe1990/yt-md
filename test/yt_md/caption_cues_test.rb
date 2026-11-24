# frozen_string_literal: true

require_relative "../test_helper"

class CaptionCuesTest < YtMdTest
  def test_joins_word_segments_into_cues
    body = json3_body(
      [
        { start_ms: 160, duration_ms: 4400, text: ["Mac OS and Windows ", "are just unfit"] }
      ]
    )

    cues = YtMd::CaptionCues.parse(body)

    assert_equal 1, cues.length
    assert_equal 160, cues.first.start_ms
    assert_equal 4560, cues.first.end_ms
    assert_equal "Mac OS and Windows are just unfit", cues.first.text
  end

  def test_skips_empty_and_music_markers
    body = json3_body(
      [
        { start_ms: 0, text: ["\n"] },
        { start_ms: 100, text: ["[Music]"] },
        { start_ms: 200, text: [Faker::Lorem.word] }
      ]
    )

    cues = YtMd::CaptionCues.parse(body)

    assert_equal 1, cues.length
    refute_equal "[Music]", cues.first.text
  end

  def test_plain_text_joins_cues
    first = Faker::Lorem.sentence(word_count: 3)
    second = Faker::Lorem.sentence(word_count: 3)
    body = json3_body(
      [
        { start_ms: 0, text: [first] },
        { start_ms: 1200, text: [second] }
      ]
    )

    text = YtMd::CaptionCues.parse(body).plain_text

    assert_includes text, first.sub(/[.?!]\z/, "")
    assert_includes text, second.sub(/[.?!]\z/, "")
  end

  def test_rejects_non_json
    received = "<timedtext>#{Faker::Lorem.word}</timedtext>"
    error = assert_raises(YtMd::CaptionCues::Invalid) { YtMd::CaptionCues.parse(received) }

    assert_includes error.message, "received "
    assert_match(/expected json3 timedtext/, error.message)
  end
end
