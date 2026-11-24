# frozen_string_literal: true

require "optparse"

module YtMd
  # Parsed argv for the yt-md CLI.
  Options = Struct.new(:video_id, :output, :language, :timestamps, :json3_path, keyword_init: true) do
    def self.parse(argv)
      language = "en"
      timestamps = false
      output = nil
      json3_path = nil
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: yt_md.rb URL [-o FILE] [--lang LANG] [--timestamps] [--json3 FILE]"
        opts.on("-o", "--output FILE", "Write markdown to FILE") { |value| output = value }
        opts.on("--lang LANG", "Caption language (default: en)") { |value| language = value }
        opts.on("--timestamps", "Prefix each cue with a clock") { timestamps = true }
        opts.on("--json3 FILE", "Use a captured json3 timedtext file") { |value| json3_path = value }
      end
      rest = parser.parse(argv)
      new(
        video_id: VideoId.parse(rest.first),
        output: output,
        language: language,
        timestamps: timestamps,
        json3_path: json3_path
      )
    end
  end
end
