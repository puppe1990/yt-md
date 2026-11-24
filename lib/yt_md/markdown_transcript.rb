# frozen_string_literal: true

module YtMd
  # Renders a markdown transcript with a Portuguese source header.
  class MarkdownTranscript
    def initialize(meta:, cues:, timestamps: false)
      @meta = meta
      @cues = cues
      @timestamps = timestamps
    end

    def to_s
      [heading, "", source_lines, "", body, ""].flatten.join("\n")
    end

    private

    def heading
      "# #{@meta.fetch(:title)}"
    end

    def source_lines
      [
        "- Canal: #{@meta.fetch(:channel)}",
        "- Fonte: #{@meta.fetch(:url)}",
        "- Faixa: #{track_label}",
        "- Duração: #{duration_label}"
      ]
    end

    def track_label
      language = @meta.fetch(:language)
      return "#{language} (ASR)" if @meta[:kind].to_s == "asr"

      language
    end

    def duration_label
      seconds = Integer(@meta.fetch(:duration_seconds))
      minutes = (seconds / 60.0).round
      "#{minutes} min"
    end

    def body
      return timestamped_body if @timestamps

      @cues.plain_text
    end

    def timestamped_body
      @cues.map { |cue| "**#{clock(cue.start_ms)}** #{cue.text}" }.join("\n\n")
    end

    def clock(ms)
      total = Integer(ms) / 1000
      hours, rem = total.divmod(3600)
      minutes, seconds = rem.divmod(60)
      return format("%02d:%02d:%02d", hours, minutes, seconds) if hours.positive?

      format("%02d:%02d", minutes, seconds)
    end
  end
end
