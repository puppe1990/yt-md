# frozen_string_literal: true

require "json"

module YtMd
  # One Videos-tab lockup (id + title).
  ChannelVideo = Struct.new(:video_id, :title, keyword_init: true)

  # Pages the channel Videos tab through Innertube WEB browse.
  class ChannelBrowse
    BROWSE_URL = "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false"
    RESOLVE_URL = "https://www.youtube.com/youtubei/v1/navigation/resolve_url?prettyPrint=false"
    VIDEOS_TAB = "EgZ2aWRlb3PyBgQKAjoA"
    WEB_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
             "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    WEB = {
      "context" => {
        "client" => {
          "clientName" => "WEB",
          "clientVersion" => "2.20251120.01.00",
          "hl" => "en",
          "gl" => "US"
        }
      }
    }.freeze

    class Missing < ArgumentError; end

    def initialize(http:)
      @http = http
    end

    def videos(ref, limit: nil)
      browse_id = resolve(ref)
      collected = []
      token = nil
      seen = {}
      loop do
        page_videos, token = parse_page(JSON.parse(browse(browse_id, token)))
        page_videos.each do |video|
          next if seen[video.video_id]

          seen[video.video_id] = true
          collected << video
          return collected.first(limit) if limit && collected.length >= limit
        end
        break if page_videos.empty?
        break if token.nil? || seen[token]

        seen[token] = true
      end
      collected
    end

    private

    def resolve(ref)
      return ref.browse_id if ref.browse_id

      body = JSON.parse(post(RESOLVE_URL, WEB.merge("url" => ref.url)))
      browse_id = body.dig("endpoint", "browseEndpoint", "browseId").to_s
      return browse_id unless browse_id.empty?

      raise Missing, %(no browseId for channel: received "#{ref.url}", expected endpoint.browseEndpoint.browseId)
    end

    def browse(browse_id, token)
      payload = token ? WEB.merge("continuation" => token) : WEB.merge("browseId" => browse_id, "params" => VIDEOS_TAB)
      post(BROWSE_URL, payload)
    end

    def post(url, json)
      @http.post(url, json: json, user_agent: WEB_UA)
    end

    def parse_page(json)
      videos = []
      token = nil
      grid_items(json).each do |item|
        if (video = video_from(item))
          videos << video
        elsif (next_token = item.dig("continuationItemRenderer", "continuationEndpoint", "continuationCommand",
                                     "token"))
          token = next_token
        end
      end
      [videos, token]
    end

    def grid_items(json)
      actions = json["onResponseReceivedActions"]
      return continuation_items(actions) if actions

      tab = selected_videos_tab(json)
      tab.dig("content", "richGridRenderer", "contents") || []
    end

    def continuation_items(actions)
      actions.flat_map { |action| action.dig("appendContinuationItemsAction", "continuationItems") || [] }
    end

    def selected_videos_tab(json)
      tabs = json.dig("contents", "twoColumnBrowseResultsRenderer", "tabs") || []
      renderers = tabs.filter_map { |tab| tab["tabRenderer"] }
      renderers.find { |tab| tab["selected"] } ||
        renderers.find { |tab| tab["title"].to_s.downcase == "videos" } ||
        {}
    end

    def video_from(item)
      lockup = item.dig("richItemRenderer", "content", "lockupViewModel")
      return unless lockup && lockup["contentType"] == "LOCKUP_CONTENT_TYPE_VIDEO"

      video_id = lockup["contentId"].to_s
      return if video_id.empty?

      title = lockup.dig("metadata", "lockupMetadataViewModel", "title", "content").to_s
      ChannelVideo.new(video_id: video_id, title: title)
    end
  end
end
