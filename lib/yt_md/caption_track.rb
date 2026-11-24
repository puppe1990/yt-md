# frozen_string_literal: true

require "uri"

module YtMd
  # One captionTracks entry from the Innertube player payload.
  class CaptionTrack
    class Missing < ArgumentError; end

    attr_reader :language, :kind, :base_url

    def self.pick(tracks, language:)
      new_from_list(tracks, language: language)
    end

    def self.new_from_list(tracks, language:)
      wanted = language.to_s.downcase
      matches = Array(tracks).filter_map { |raw| from_raw(raw) }
        .select { |track| track.matches?(wanted) }
      raise missing(wanted, tracks) if matches.empty?

      matches.min_by { |track| track.kind == "asr" ? 1 : 0 }
    end

    def self.from_raw(raw)
      url = raw["baseUrl"].to_s
      return if url.empty?

      new(
        language: raw["languageCode"].to_s,
        kind: raw["kind"].to_s.empty? ? nil : raw["kind"].to_s,
        base_url: url
      )
    end

    def self.missing(wanted, tracks)
      available = Array(tracks).map { |raw| raw["languageCode"] }.compact.uniq.join(", ")
      listed = available.empty? ? "(none)" : available
      Missing.new(
        %(no caption track for language: received "#{wanted}", expected one of #{listed})
      )
    end
    private_class_method :new_from_list, :from_raw, :missing

    def initialize(language:, kind:, base_url:)
      @language = language
      @kind = kind
      @base_url = base_url
    end

    def matches?(wanted)
      code = language.downcase
      code == wanted || code.start_with?("#{wanted}-")
    end

    # Player baseUrl is usually fmt=srv3 XML. CaptionCues only parses json3.
    def timedtext_url
      uri = URI.parse(base_url)
      params = URI.decode_www_form(uri.query.to_s)
      params.reject! { |key, _| key == "fmt" }
      params << %w[fmt json3]
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end
  end
end
