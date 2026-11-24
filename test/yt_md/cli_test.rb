# frozen_string_literal: true

require "stringio"
require_relative "../test_helper"

class CliTest < YtMdTest
  def transcript_sample(quote: Faker::Lorem.sentence)
    video_id = fake_video_id
    title = fake_title
    channel = fake_channel
    timedtext_url = timedtext_url_for(video_id)
    json3 = json3_body([{ start_ms: 160, text: [quote] }])
    http = FakeInnertube.new(
      posts: {
        video_id => player_payload_json(
          video_id: video_id, title: title, channel: channel, timedtext_url: timedtext_url
        )
      },
      gets: { "#{timedtext_url}&fmt=json3" => json3 }
    )
    {
      video_id: video_id,
      title: title,
      channel: channel,
      quote: quote,
      json3: json3,
      http: http,
      url: "https://www.youtube.com/watch?v=#{video_id}"
    }
  end

  def run_cli(argv, http:, stdout: StringIO.new)
    YtMd::Cli.new(http: http, stdout: stdout).run(argv)
    stdout
  end

  def test_prints_markdown_for_watch_url
    sample = transcript_sample
    stdout = run_cli([sample[:url]], http: sample[:http])
    markdown = stdout.string

    assert_includes markdown, "# #{sample[:title]}"
    assert_includes markdown, "- Canal: #{sample[:channel]}"
    assert_includes markdown, "- Fonte: #{sample[:url]}"
    assert_includes markdown, "- Faixa: en (ASR)"
    assert_includes markdown, "- Duração: 52 min"
    assert_includes markdown, sample[:quote]
  end

  def test_writes_markdown_to_output_file
    sample = transcript_sample
    Dir.mktmpdir do |dir|
      path = File.join(dir, "#{sample[:video_id]}.md")
      stdout = run_cli([sample[:url], "-o", path], http: sample[:http])

      assert_equal "", stdout.string
      written = File.read(path)
      assert_includes written, "# #{sample[:title]}"
      assert_includes written, sample[:quote]
    end
  end

  def test_timestamps_prefix_each_cue
    quote = Faker::Lorem.word
    sample = transcript_sample(quote: quote)
    stdout = run_cli([sample[:url], "--timestamps"], http: sample[:http])

    assert_includes stdout.string, "**00:00** #{quote}"
  end

  def test_json3_file_skips_timedtext_get
    sample = transcript_sample
    Dir.mktmpdir do |dir|
      path = File.join(dir, "captions.json3")
      File.write(path, sample[:json3])
      http = FakeInnertube.new(posts: sample[:http].posts, gets: {})
      stdout = run_cli([sample[:url], "--json3", path], http: http)

      assert_includes stdout.string, sample[:quote]
      assert_includes stdout.string, "# #{sample[:title]}"
    end
  end

  def test_rejects_blank_argv
    error = assert_raises(YtMd::VideoId::Invalid) do
      YtMd::Cli.new(http: FakeInnertube.new, stdout: StringIO.new).run([])
    end

    assert_includes error.message, 'received ""'
    assert_includes error.message, "expected YouTube id or URL"
  end
end
