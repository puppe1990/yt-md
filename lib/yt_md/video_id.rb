# frozen_string_literal: true

module YtMd
  # Pulls the 11-character YouTube id out of a bare id or a watch/share URL.
  class VideoId
    PATTERN = /[A-Za-z0-9_-]{11}/
    WATCH = %r{[?&]v=(#{PATTERN})}
    PATH = %r{(?:youtu\.be/|youtube\.com/(?:shorts|embed|live)/)(#{PATTERN})}

    class Invalid < ArgumentError; end

    def self.parse(input)
      new(input).parse
    end

    def initialize(input)
      @input = input.to_s.strip
    end

    def parse
      raise invalid if @input.empty?
      return @input if @input.match?(/\A#{PATTERN}\z/)

      match = @input.match(WATCH) || @input.match(PATH)
      raise invalid unless match

      match[1]
    end

    private

    def invalid
      Invalid.new(%(invalid YouTube id: received "#{@input}", expected YouTube id or URL))
    end
  end
end
