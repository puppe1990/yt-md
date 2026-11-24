# frozen_string_literal: true

require_relative "../test_helper"

class VideoIdTest < YtMdTest
  def test_returns_an_11_character_id
    video_id = fake_video_id

    assert_equal video_id, YtMd::VideoId.parse(video_id)
  end

  def test_extracts_id_from_watch_url
    video_id = fake_video_id
    url = "https://www.youtube.com/watch?v=#{video_id}&t=12s"

    assert_equal video_id, YtMd::VideoId.parse(url)
  end

  def test_extracts_id_from_short_url
    video_id = fake_video_id

    assert_equal video_id, YtMd::VideoId.parse("https://youtu.be/#{video_id}")
  end

  def test_extracts_id_from_shorts_url
    video_id = fake_video_id

    assert_equal video_id, YtMd::VideoId.parse("https://www.youtube.com/shorts/#{video_id}")
  end

  def test_rejects_blank_input
    error = assert_raises(YtMd::VideoId::Invalid) { YtMd::VideoId.parse("   ") }

    assert_match(/received ""/, error.message)
    assert_match(/expected YouTube id or URL/, error.message)
  end

  def test_rejects_unknown_shape
    received = "https://vimeo.com/#{Faker::Number.number(digits: 8)}"
    error = assert_raises(YtMd::VideoId::Invalid) { YtMd::VideoId.parse(received) }

    assert_includes error.message, %(received "#{received}")
  end
end
