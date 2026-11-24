# frozen_string_literal: true

module YtMd
  # Fetches a YouTube transcript and writes markdown to stdout or -o.
  class Cli
    def initialize(http: JsonHttp.new, stdout: $stdout)
      @http = http
      @stdout = stdout
    end

    def run(argv)
      options = Options.parse(argv)
      transcript = fetch(options)
      markdown = MarkdownTranscript.new(
        meta: transcript.meta,
        cues: transcript.cues,
        timestamps: options.timestamps
      ).to_s
      write(markdown, options.output)
    end

    private

    def fetch(options)
      timedtext = options.json3_path && File.read(options.json3_path)
      TranscriptFetch.new(http: @http).call(
        options.video_id,
        language: options.language,
        timedtext: timedtext
      )
    end

    def write(markdown, path)
      return File.write(path, markdown) if path

      @stdout.write(markdown)
    end
  end
end
