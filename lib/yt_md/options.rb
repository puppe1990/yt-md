# frozen_string_literal: true

require "optparse"

module YtMd
  # Parsed argv for the yt-md CLI.
  Options = Struct.new(:video_id, :channel, :output, :language, :timestamps, :json3_path, :limit, :sleep,
                       :comments, :sort, keyword_init: true) do
    def self.parse(argv)
      flags = parse_flags(argv)
      input = flags.delete(:input)
      if ChannelRef.match?(input)
        new(video_id: nil, channel: ChannelRef.parse(input), **flags)
      else
        new(video_id: VideoId.parse(input), channel: nil, **flags)
      end
    end

    def self.parse_flags(argv)
      language = "en"
      timestamps = false
      output = nil
      json3_path = nil
      limit = nil
      sleep = 0.0
      comments = false
      sort = :top
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: yt_md.rb URL [-o FILE] [--lang LANG] [--timestamps] [--json3 FILE] " \
                      "[--comments [--sort top|newest]] [--limit N]"
        opts.on("-o", "--output FILE", "Write markdown to FILE or channel directory") { |value| output = value }
        opts.on("--lang LANG", "Caption language (default: en)") { |value| language = value }
        opts.on("--timestamps", "Prefix each cue with a clock") { timestamps = true }
        opts.on("--json3 FILE", "Use a captured json3 timedtext file") { |value| json3_path = value }
        opts.on("--comments", "Write the video comments instead of the transcript") { comments = true }
        opts.on("--sort ORDER", %w[top newest], "Comment order (default: top)") { |value| sort = value.to_sym }
        opts.on("--limit N", Integer, "Stop after N channel videos or comments") { |value| limit = value }
        opts.on("--sleep SECONDS", Float, "Pause between channel videos") { |value| sleep = value }
      end
      {
        input: parser.parse(argv).first,
        output: output,
        language: language,
        timestamps: timestamps,
        json3_path: json3_path,
        limit: limit,
        sleep: sleep,
        comments: comments,
        sort: sort
      }
    end
    private_class_method :parse_flags
  end
end
