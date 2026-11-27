# frozen_string_literal: true

require "stringio"
require_relative "../test_helper"

class CommentsCliTest < YtMdTest
  def fixture(rows: [{ author: "@AlexHormozi", text: "roadmap here", likes: "19", replies: 0 }])
    video_id = fake_video_id
    top_token = "top-token"
    returns = comments_page_json(rows)
    http = FakeInnertube.new(
      posts: {
        video_id => comments_watch_json(count: "351", tokens: [top_token, "new-token"]),
        top_token => returns
      }
    )
    { video_id: video_id, http: http, url: "https://www.youtube.com/watch?v=#{video_id}" }
  end

  def run_cli(argv, http:, stdout: StringIO.new)
    YtMd::Cli.new(http: http, stdout: stdout).run(argv)
    stdout
  end

  def test_writes_comment_markdown_to_stdout
    sample = fixture
    markdown = run_cli([sample[:url], "--comments"], http: sample[:http]).string

    assert_includes markdown, "— comentários"
    assert_includes markdown, "- Fonte: #{sample[:url]}"
    assert_includes markdown, "roadmap here"
    assert_includes markdown, "@AlexHormozi"
  end

  def test_writes_comment_markdown_to_output_file
    sample = fixture
    Dir.mktmpdir do |dir|
      path = File.join(dir, "comments.md")
      stdout = run_cli([sample[:url], "--comments", "-o", path], http: sample[:http])

      assert_equal "", stdout.string
      assert_includes File.read(path), "roadmap here"
    end
  end

  def test_sort_newest_uses_the_second_token
    sample = fixture
    sample[:http].posts["new-token"] = comments_page_json([{ author: "@n", text: "newest one" }])
    markdown = run_cli([sample[:url], "--comments", "--sort", "newest"], http: sample[:http]).string

    assert_includes markdown, "- Ordem: mais recentes"
    assert_includes markdown, "newest one"
  end

  def test_limit_caps_collected_comments
    rows = [{ author: "@a", text: "one" }, { author: "@b", text: "two" }]
    sample = fixture(rows: rows)
    markdown = run_cli([sample[:url], "--comments", "--limit", "1"], http: sample[:http]).string

    assert_includes markdown, "one"
    refute_includes markdown, "two"
    assert_includes markdown, "(YouTube informa 351)"
  end

  def test_rejects_an_unknown_sort
    error = assert_raises(OptionParser::InvalidArgument) do
      YtMd::Options.parse(["abc", "--sort", "oldest"])
    end

    assert_includes error.message, "oldest"
  end

  def test_comments_flag_defaults_to_top_and_off
    options = YtMd::Options.parse(["abcdefghijk"])

    refute options.comments
    assert_equal :top, options.sort
  end
end
