# frozen_string_literal: true

unless ENV["SKIP_SIMPLECOV"]
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    skip "/test/"
    skip "/tools/"
    cover "lib/**/*.rb"
    command_name "Minitest"
  end
end

require "minitest/autorun"
require "faker"
require "json"
require "tmpdir"

require_relative "../lib/yt_md"
require_relative "yt_md/fake_innertube"

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

  def fake_browse_id
    "UC#{Faker::Alphanumeric.alphanumeric(number: 22)}"
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

  def timedtext_url_for(video_id, language: "en")
    "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=#{language}&kind=asr"
  end

  def player_payload_json(video_id:, title: fake_title, channel: fake_channel, timedtext_url: nil,
                          tracks: nil, status: "OK", reason: nil, length: "3135")
    tracks ||= [
      { "languageCode" => "en", "kind" => "asr", "baseUrl" => timedtext_url }
    ]
    JSON.generate(
      "playabilityStatus" => { "status" => status, "reason" => reason },
      "videoDetails" => {
        "videoId" => video_id,
        "title" => title,
        "author" => channel,
        "lengthSeconds" => length
      },
      "captions" => {
        "playerCaptionsTracklistRenderer" => { "captionTracks" => tracks }
      }
    )
  end

  def videos_tab_lockup(video_id, title)
    {
      "richItemRenderer" => {
        "content" => {
          "lockupViewModel" => {
            "contentId" => video_id,
            "contentType" => "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata" => {
              "lockupMetadataViewModel" => { "title" => { "content" => title } }
            }
          }
        }
      }
    }
  end

  def videos_tab_continuation(token)
    {
      "continuationItemRenderer" => {
        "continuationEndpoint" => {
          "continuationCommand" => { "token" => token }
        }
      }
    }
  end

  def videos_tab_page(items)
    JSON.generate(
      "contents" => {
        "twoColumnBrowseResultsRenderer" => {
          "tabs" => [
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

  def videos_tab_continuation_page(items)
    JSON.generate(
      "onResponseReceivedActions" => [
        { "appendContinuationItemsAction" => { "continuationItems" => items } }
      ]
    )
  end

  def resolve_url_json(browse_id)
    JSON.generate("endpoint" => { "browseEndpoint" => { "browseId" => browse_id } })
  end
end
