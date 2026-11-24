# frozen_string_literal: true

require "stringio"
require_relative "../test_helper"

class ChannelCliTest < YtMdTest
  def channel_http(videos)
    browse_id = fake_browse_id
    posts = {
      "https://www.youtube.com/@a16z" => resolve_url_json(browse_id),
      browse_id => videos_tab_page(videos.map { |row| videos_tab_lockup(row[:id], row[:title]) })
    }
    gets = {}
    videos.each do |row|
      timedtext_url = timedtext_url_for(row[:id])
      posts[row[:id]] = player_payload_json(
        video_id: row[:id],
        title: row[:title],
        channel: "a16z",
        timedtext_url: timedtext_url,
        length: "120"
      )
      gets["#{timedtext_url}&fmt=json3"] = json3_body([{ start_ms: 0, text: [row[:quote]] }])
    end
    FakeInnertube.new(posts: posts, gets: gets)
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
