# frozen_string_literal: true

require_relative "../test_helper"

class MarkdownTranscriptTest < YtMdTest
  def transcript_meta
    {
      title: fake_title,
      channel: fake_channel,
      url: "https://www.youtube.com/watch?v=#{fake_video_id}",
      language: "en",
      kind: "asr",
      duration_seconds: 3135
    }
  end

  def test_renders_title_and_source_list
    meta = transcript_meta
    cues = YtMd::CaptionCues.parse(json3_body([{ start_ms: 160, text: ["Hello agents"] }]))
    markdown = YtMd::MarkdownTranscript.new(meta: meta, cues: cues).to_s

    assert_includes markdown, "# #{meta[:title]}"
    assert_includes markdown, "- Canal: #{meta[:channel]}"
    assert_includes markdown, "- Fonte: #{meta[:url]}"
    assert_includes markdown, "- Faixa: en (ASR)"
    assert_includes markdown, "- Duração: 52 min"
    assert_includes markdown, "Hello agents"
  end

  def test_timestamps_prefix_merged_cues
    cues = YtMd::CaptionCues.parse(
      json3_body(
        [
          { start_ms: 160, duration_ms: 4000, text: ["Mac OS"] },
          { start_ms: 9000, duration_ms: 2000, text: ["Linux"] }
        ]
      )
    )
    markdown = YtMd::MarkdownTranscript.new(meta: transcript_meta, cues: cues, timestamps: true).to_s

    assert_includes markdown, "**00:00** Mac OS"
    assert_includes markdown, "**00:09** Linux"
  end

  def test_human_track_omits_asr_label
    meta = transcript_meta.merge(kind: nil, language: "pt")
    cues = YtMd::CaptionCues.parse(json3_body([{ start_ms: 0, text: ["Oi"] }]))
    markdown = YtMd::MarkdownTranscript.new(meta: meta, cues: cues).to_s

    assert_includes markdown, "- Faixa: pt"
    refute_includes markdown, "ASR"
  end
end
