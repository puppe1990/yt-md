# frozen_string_literal: true

require_relative "../test_helper"

class ChannelRefTest < YtMdTest
  def test_parses_handle
    ref = YtMd::ChannelRef.parse("@a16z")

    assert_equal "@a16z", ref.handle
    assert_equal "https://www.youtube.com/@a16z", ref.url
    assert_nil ref.browse_id
  end

  def test_parses_channel_url_with_videos_tab
    ref = YtMd::ChannelRef.parse("https://www.youtube.com/@a16z/videos")

    assert_equal "@a16z", ref.handle
    assert_equal "https://www.youtube.com/@a16z", ref.url
  end

  def test_parses_uc_channel_id
    channel_id = fake_browse_id
    ref = YtMd::ChannelRef.parse(channel_id)

    assert_equal channel_id, ref.browse_id
    assert_nil ref.handle
  end

  def test_parses_channel_uc_url
    channel_id = fake_browse_id
    ref = YtMd::ChannelRef.parse("https://www.youtube.com/channel/#{channel_id}")

    assert_equal channel_id, ref.browse_id
  end

  def test_rejects_watch_url
    video_id = fake_video_id
    received = "https://www.youtube.com/watch?v=#{video_id}"
    error = assert_raises(YtMd::ChannelRef::Invalid) { YtMd::ChannelRef.parse(received) }

    assert_includes error.message, %(received "#{received}")
    assert_includes error.message, "expected channel handle, /channel/ id, or UC id"
  end
end
