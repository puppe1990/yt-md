# frozen_string_literal: true

require "json"

module YtMd
  # One Videos-tab lockup (id + title).
  ChannelVideo = Struct.new(:video_id, :title, keyword_init: true)

  # Pages the channel Videos tab through Innertube WEB browse.
  class ChannelBrowse
    CONTINUATION_TOKEN_PATH = %w[
      continuationItemRenderer continuationEndpoint continuationCommand token
    ].freeze

    class Missing < ArgumentError; end

    def initialize(http:)
      @http = http
    end

    def videos(ref, limit: nil)
      browse_id = resolve(ref)
      collected = []
      token = nil
      # Tokens and video ids are different identities. One Hash would skip a
      # video whose id equalled a continuation token already seen.
      seen_ids = {}
      seen_tokens = {}
      loop do
        page_videos, token = parse_page(JSON.parse(browse(browse_id, token)))
        return collected if take_page(collected, seen_ids, page_videos, limit)
        break if page_videos.empty? || token.nil? || seen_tokens[token]

        seen_tokens[token] = true
      end
      collected
    end

    private

    def take_page(collected, seen_ids, page_videos, limit)
      page_videos.each do |video|
        next if seen_ids[video.video_id]

        seen_ids[video.video_id] = true
        collected << video
        return true if limit && collected.length >= limit
      end
      false
    end

    def resolve(ref)
      return ref.browse_id if ref.browse_id

      body = JSON.parse(post(Innertube::RESOLVE_URL, Innertube::WEB.merge("url" => ref.url)))
      browse_id = body.dig("endpoint", "browseEndpoint", "browseId").to_s
      return browse_id unless browse_id.empty?

      raise Missing, %(no browseId for channel: received "#{ref.url}", expected endpoint.browseEndpoint.browseId)
    end

    def browse(browse_id, token)
      payload = if token
                  Innertube::WEB.merge("continuation" => token)
                else
                  Innertube::WEB.merge("browseId" => browse_id, "params" => Innertube::VIDEOS_TAB)
                end
      post(Innertube::BROWSE_URL, payload)
    end

    def post(url, json)
      @http.post(url, json: json, user_agent: Innertube::WEB_UA)
    end

    def parse_page(json)
      videos = []
      token = nil
      grid_items(json).each do |item|
        if (video = video_from(item))
          videos << video
        elsif (next_token = item.dig(*CONTINUATION_TOKEN_PATH))
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
