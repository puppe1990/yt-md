# frozen_string_literal: true

# Named fake for Innertube POST/GET. Keys: resolve url, browseId/continuation, videoId.
class FakeInnertube
  attr_reader :posts, :gets, :post_calls

  def initialize(posts: {}, gets: {})
    @posts = posts
    @gets = gets
    @post_calls = []
  end

  def get(url, **_)
    @gets.fetch(url) { raise "unexpected GET #{url}" }
  end

  def post(url, json:, **_)
    raise "missing ANDROID client" if player?(url) && json.dig("context", "client", "clientName") != "ANDROID"

    @post_calls << json
    @posts.fetch(post_key(url, json)) { raise "unexpected POST #{url}" }
  end

  private

  def post_key(url, json)
    return json.fetch("url") if url.include?("resolve_url")
    return json["continuation"] || json["browseId"] if url.include?("/browse")
    return json.fetch("videoId") if player?(url)

    raise "unexpected POST #{url}"
  end

  def player?(url)
    url.include?("/youtubei/v1/player")
  end
end
