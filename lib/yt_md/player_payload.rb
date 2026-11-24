# frozen_string_literal: true

require "json"

module YtMd
  # Decodes youtubei/v1/player JSON into video metadata and captionTracks.
  class PlayerPayload
    class Unplayable < ArgumentError; end

    attr_reader :video_id, :title, :channel, :duration_seconds, :tracks

    def self.parse(body)
      new(body).parse
    end

    def initialize(body)
      @body = body.to_s
    end

    def parse
      json = JSON.parse(@body)
      assert_playable!(json)
      details = json.fetch("videoDetails")
      tracks = caption_tracks(json)
      raise Unplayable, "no captionTracks in player payload" if tracks.empty?

      @video_id = details.fetch("videoId")
      @title = details.fetch("title")
      @channel = details.fetch("author")
      @duration_seconds = Integer(details.fetch("lengthSeconds"))
      @tracks = tracks
      self
    end

    private

    def assert_playable!(json)
      status = json.dig("playabilityStatus", "status").to_s
      return if status.empty? || status == "OK"

      reason = json.dig("playabilityStatus", "reason").to_s
      raise Unplayable, %(player unplayable: received "#{status}"#{reason.empty? ? '' : " (#{reason})"})
    end

    def caption_tracks(json)
      json.dig("captions", "playerCaptionsTracklistRenderer", "captionTracks") || []
    end
  end
end
