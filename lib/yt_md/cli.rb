# frozen_string_literal: true

require "fileutils"

module YtMd
  # Fetches a YouTube transcript and writes markdown to stdout or -o.
  class Cli
    def initialize(http: JsonHttp.new, stdout: $stdout, sleeper: nil)
      @http = http
      @stdout = stdout
      @sleeper = sleeper || ->(seconds) { sleep(seconds) if seconds.positive? }
    end

    def run(argv)
      options = Options.parse(argv)
      return run_channel(options) if options.channel

      markdown = render(fetch(options), timestamps: options.timestamps)
      write(markdown, options.output)
    end

    private

    def run_channel(options)
      videos = ChannelBrowse.new(http: @http).videos(options.channel, limit: options.limit)
      dir = options.output || options.channel.folder_name
      FileUtils.mkdir_p(dir)
      @stdout.puts("listed #{videos.length} videos from #{options.channel.folder_name}")
      videos.each_with_index do |video, index|
        write_channel_video(video, index, videos.length, dir, options)
        @sleeper.call(options.sleep)
      end
    end

    def write_channel_video(video, index, total, dir, options)
      path = File.join(dir, "#{video.video_id}.md")
      label = "#{index + 1}/#{total} #{video.video_id}"
      if File.exist?(path)
        @stdout.puts("skip #{label} exists")
        return
      end

      transcript = TranscriptFetch.new(http: @http).call(video.video_id, language: options.language)
      File.write(path, render(transcript, timestamps: options.timestamps))
      @stdout.puts("ok #{label}")
    rescue ArgumentError => e
      @stdout.puts("skip #{label} #{e.message}")
    end

    def fetch(options)
      timedtext = options.json3_path && File.read(options.json3_path)
      TranscriptFetch.new(http: @http).call(
        options.video_id,
        language: options.language,
        timedtext: timedtext
      )
    end

    def render(transcript, timestamps:)
      MarkdownTranscript.new(
        meta: transcript.meta,
        cues: transcript.cues,
        timestamps: timestamps
      ).to_s
    end

    def write(markdown, path)
      return File.write(path, markdown) if path

      @stdout.write(markdown)
    end
  end
end
