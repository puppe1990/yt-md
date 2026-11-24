# frozen_string_literal: true

require "minitest/autorun"
require "faker"
require "json"
require "tmpdir"

require_relative "../lib/yt_md"

Faker::Config.locale = "en"

# Shared helpers for yt-md tests. Network stays out: HTTP is injected.
class YtMdTest < Minitest::Test
  def fake_video_id
    Faker::Alphanumeric.alphanumeric(number: 11)
  end

  def fake_title
    Faker::Book.title
  end

  def fake_channel
    Faker::Internet.username
  end

  def json3_body(cues)
    events = cues.map do |cue|
      {
        "tStartMs" => cue.fetch(:start_ms),
        "dDurationMs" => cue.fetch(:duration_ms, 1000),
        "segs" => Array(cue.fetch(:text)).map { |piece| { "utf8" => piece } }
      }
    end
    JSON.generate("wireMagic" => "pb3", "events" => events)
  end
end
