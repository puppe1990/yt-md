# frozen_string_literal: true

require "json"

module YtMd
  # One timedtext event after skip filters.
  Cue = Struct.new(:start_ms, :end_ms, :text, keyword_init: true)

  # Turns YouTube json3 timedtext into timed cues and a plain paragraph.
  class CaptionCues
    SKIP = /\A(\[Music\]|\[Applause\]|\[Laughter\]|\[Musik\])\z/i

    class Invalid < ArgumentError; end

    def self.parse(body)
      new(body).parse
    end

    def initialize(body)
      @body = body.to_s
    end

    def parse
      events = json_events
      cues = events.filter_map { |event| cue_from(event) }
      Collection.new(cues)
    end

    private

    def json_events
      payload = JSON.parse(@body)
      payload.fetch("events")
    rescue JSON::ParserError, KeyError, TypeError
      preview = @body[0, 80].to_s.gsub(/\s+/, " ")
      raise Invalid, %(invalid timedtext: received "#{preview}", expected json3 timedtext)
    end

    def cue_from(event)
      start_ms = Integer(event["tStartMs"] || 0)
      duration_ms = Integer(event["dDurationMs"] || 0)
      text = joined_text(event["segs"])
      return if text.empty? || text.match?(SKIP)

      Cue.new(start_ms: start_ms, end_ms: start_ms + duration_ms, text: text)
    end

    def joined_text(segs)
      pieces = Array(segs).map { |seg| seg["utf8"].to_s }
      pieces.join.gsub(/\s+/, " ").strip
    end

    # Enumerable list of Cue with a joined transcript.
    class Collection
      include Enumerable

      def initialize(cues)
        @cues = cues
      end

      def each(&block)
        @cues.each(&block)
      end

      def length
        @cues.length
      end

      def first
        @cues.first
      end

      def plain_text
        joined = @cues.map(&:text).join(" ")
        joined.gsub(/\s+([,.?!:;])/, '\1').gsub(/\s+/, " ").strip
      end
    end
  end
end
