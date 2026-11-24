# frozen_string_literal: true

require "stringio"
require_relative "../test_helper"

class ChannelCliTest < YtMdTest
  FakeHttp = Struct.new(:posts, :gets, keyword_init: true) do
    def get(url, **_)
      gets.fetch(url) { raise "unexpected GET #{url}" }
    end

    def post(url, json:, **_)
      return posts.fetch(json.fetch("url")) if url.include?("resolve_url")
      return posts.fetch(json["continuation"] || json["browseId"]) if url.include?("/browse")
      return posts.fetch(json.fetch("videoId")) if url.include?("/player")

      raise "unexpected POST #{url}"
    end
  end

  def lockup(video_id, title)
    {
      "richItemRenderer" => {
        "content" => {
          "lockupViewModel" => {
            "contentId" => video_id,
            "contentType" => "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata" => {
              "lockupMetadataViewModel" => { "title" => { "content" => title } }
            }
          }
        }
      }
    }
  end

  def videos_page(items)
    JSON.generate(
      "contents" => {
        "twoColumnBrowseResultsRenderer" => {
          "tabs" => [
            {
              "tabRenderer" => {
                "selected" => true,
                "title" => "Videos",
                "content" => { "richGridRenderer" => { "contents" => items } }
              }
            }
          ]
        }
      }
    )
  end

  def player_for(video_id:, title:, channel:, timedtext_url:)
    JSON.generate(
      "playabilityStatus" => { "status" => "OK" },
      "videoDetails" => {
        "videoId" => video_id,
        "title" => title,
        "author" => channel,
        "lengthSeconds" => "120"
      },
      "captions" => {
        "playerCaptionsTracklistRenderer" => {
          "captionTracks" => [
            { "languageCode" => "en", "kind" => "asr", "baseUrl" => timedtext_url }
          ]
        }
      }
    )
  end

  def channel_http(videos)
    browse_id = "UC#{Faker::Alphanumeric.alphanumeric(number: 22)}"
    posts = {
      "https://www.youtube.com/@a16z" => JSON.generate(
        "endpoint" => { "browseEndpoint" => { "browseId" => browse_id } }
      ),
      browse_id => videos_page(videos.map { |row| lockup(row[:id], row[:title]) })
    }
    gets = {}
    videos.each do |row|
      timedtext_url = "https://www.youtube.com/api/timedtext?v=#{row[:id]}&lang=en&kind=asr"
      posts[row[:id]] = player_for(
        video_id: row[:id],
        title: row[:title],
        channel: "a16z",
        timedtext_url: timedtext_url
      )
      gets["#{timedtext_url}&fmt=json3"] = json3_body([{ start_ms: 0, text: [row[:quote]] }])
    end
    FakeHttp.new(posts: posts, gets: gets)
  end

  def test_writes_one_markdown_file_per_channel_video
    rows = [
      { id: fake_video_id, title: fake_title, quote: Faker::Lorem.sentence },
      { id: fake_video_id, title: fake_title, quote: Faker::Lorem.sentence }
    ]
    http = channel_http(rows)
    Dir.mktmpdir do |dir|
      stdout = StringIO.new
      YtMd::Cli.new(http: http, stdout: stdout).run(["@a16z", "-o", dir])

      rows.each do |row|
        markdown = File.read(File.join(dir, "#{row[:id]}.md"))
        assert_includes markdown, "# #{row[:title]}"
        assert_includes markdown, row[:quote]
        assert_includes markdown, "- Canal: a16z"
      end
      assert_includes stdout.string, "listed 2 videos from a16z"
      assert_includes stdout.string, "ok 1/2 #{rows[0][:id]}"
      assert_includes stdout.string, "ok 2/2 #{rows[1][:id]}"
    end
  end

  def test_skips_existing_channel_markdown
    row = { id: fake_video_id, title: fake_title, quote: Faker::Lorem.sentence }
    http = channel_http([row])
    Dir.mktmpdir do |dir|
      path = File.join(dir, "#{row[:id]}.md")
      File.write(path, "already here")
      stdout = StringIO.new
      YtMd::Cli.new(http: http, stdout: stdout).run(["https://www.youtube.com/@a16z/videos", "-o", dir])

      assert_equal "already here", File.read(path)
      assert_includes stdout.string, "skip 1/1 #{row[:id]} exists"
    end
  end

  def test_limit_stops_after_n_videos
    rows = [
      { id: fake_video_id, title: fake_title, quote: Faker::Lorem.word },
      { id: fake_video_id, title: fake_title, quote: Faker::Lorem.word }
    ]
    http = channel_http(rows)
    Dir.mktmpdir do |dir|
      YtMd::Cli.new(http: http, stdout: StringIO.new).run(["@a16z", "-o", dir, "--limit", "1"])

      assert_equal ["#{rows[0][:id]}.md"], Dir.children(dir)
    end
  end
end
