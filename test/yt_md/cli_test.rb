# frozen_string_literal: true

require "stringio"
require_relative "../test_helper"

class CliTest < YtMdTest
  FakeHttp = Struct.new(:gets, :posts, keyword_init: true) do
    def get(url)
      gets.fetch(url) { raise "unexpected GET #{url}" }
    end

    def post(url, json:)
      raise "unexpected POST #{url}" unless url.include?("/youtubei/v1/player")
      raise "missing ANDROID client" unless json.dig("context", "client", "clientName") == "ANDROID"

      posts.fetch(json.fetch("videoId"))
    end
  end

  def player_for(video_id:, title:, channel:, timedtext_url:)
    JSON.generate(
      "playabilityStatus" => { "status" => "OK" },
      "videoDetails" => {
        "videoId" => video_id,
        "title" => title,
        "author" => channel,
        "lengthSeconds" => "3135"
      },
      "captions" => {
        "playerCaptionsTracklistRenderer" => {
          "captionTracks" => [
            {
              "languageCode" => "en",
              "kind" => "asr",
              "baseUrl" => timedtext_url
            }
          ]
        }
      }
    )
  end

  def fixture(quote: Faker::Lorem.sentence)
    video_id = fake_video_id
    title = fake_title
    channel = fake_channel
    timedtext_url = "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=en&kind=asr"
    json3 = json3_body([{ start_ms: 160, text: [quote] }])
    http = FakeHttp.new(
      posts: { video_id => player_for(video_id: video_id, title: title, channel: channel, timedtext_url: timedtext_url) },
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
    data = fixture
    stdout = run_cli([data[:url]], http: data[:http])
    markdown = stdout.string

    assert_includes markdown, "# #{data[:title]}"
    assert_includes markdown, "- Canal: #{data[:channel]}"
    assert_includes markdown, "- Fonte: #{data[:url]}"
    assert_includes markdown, "- Faixa: en (ASR)"
    assert_includes markdown, "- Duração: 52 min"
    assert_includes markdown, data[:quote]
  end

  def test_writes_markdown_to_output_file
    data = fixture
    Dir.mktmpdir do |dir|
      path = File.join(dir, "#{data[:video_id]}.md")
      stdout = run_cli([data[:url], "-o", path], http: data[:http])

      assert_equal "", stdout.string
      written = File.read(path)
      assert_includes written, "# #{data[:title]}"
      assert_includes written, data[:quote]
    end
  end

  def test_timestamps_prefix_each_cue
    quote = Faker::Lorem.word
    data = fixture(quote: quote)
    stdout = run_cli([data[:url], "--timestamps"], http: data[:http])

    assert_includes stdout.string, "**00:00** #{quote}"
  end

  def test_json3_file_skips_timedtext_get
    data = fixture
    Dir.mktmpdir do |dir|
      path = File.join(dir, "captions.json3")
      File.write(path, data[:json3])
      http = FakeHttp.new(posts: data[:http].posts, gets: {})
      stdout = run_cli([data[:url], "--json3", path], http: http)

      assert_includes stdout.string, data[:quote]
      assert_includes stdout.string, "# #{data[:title]}"
    end
  end

  def test_rejects_blank_argv
    error = assert_raises(YtMd::VideoId::Invalid) do
      YtMd::Cli.new(http: FakeHttp.new(gets: {}, posts: {}), stdout: StringIO.new).run([])
    end

    assert_includes error.message, 'received ""'
    assert_includes error.message, "expected YouTube id or URL"
  end
end
