# frozen_string_literal: true

module YtMd
  # The comments panel inside the watch youtubei/v1/next payload.
  #
  # Sorts are read by position and selection flag, not by title: the menu is
  # localized ("Top"/"Principais", "Newest"/"Mais recentes") but always lists
  # Top first and Newest second.
  class CommentPanel
    PANEL_ID = "engagement-panel-comments-section"
    SORTS = %i[top newest].freeze

    class Disabled < ArgumentError; end

    attr_reader :title, :channel

    def initialize(json, video_id:)
      @json = json
      @video_id = video_id
    end

    def parse
      panel_header
      @title = primary_text("videoPrimaryInfoRenderer", "title")
      @channel = channel_text
      self
    end

    def sort_token(sort)
      item = sort_items[sort == :newest ? 1 : 0]
      item&.dig("serviceEndpoint", "continuationCommand", "token")
    end

    def declared_count
      @declared_count ||= panel_header.dig("contextualInfo", "runs", 0, "text")
    end

    private

    def panel_header
      panel = (watch_contents("engagementPanels") || []).find do |candidate|
        candidate.dig("engagementPanelSectionListRenderer", "panelIdentifier") == PANEL_ID
      end
      raise Disabled, disabled_message unless panel

      panel.dig("engagementPanelSectionListRenderer", "header", "engagementPanelTitleHeaderRenderer") || {}
    end

    def disabled_message
      %(comments unavailable for #{@video_id}: received no #{PANEL_ID}, expected a comment panel)
    end

    def sort_items
      panel_header.dig("menu", "sortFilterSubMenuRenderer", "subMenuItems") || []
    end

    def primary_text(renderer, *keys)
      selected_renderer(renderer)&.dig(*keys, "runs", 0, "text").to_s
    end

    # Collab videos replace `title` with `attributedTitle.content`
    # ("Kelvin Cleto e Rodrigo Lopes"), so the channel needs both shapes.
    def channel_text
      owner = selected_renderer("videoSecondaryInfoRenderer")&.dig("owner", "videoOwnerRenderer") || {}
      owner.dig("title", "runs", 0, "text").to_s.then do |text|
        text.empty? ? owner.dig("attributedTitle", "content").to_s : text
      end
    end

    def selected_renderer(renderer)
      watch_contents("contents", "twoColumnWatchNextResults", "results", "results", "contents")
        &.find { |content| content[renderer] }
        &.[](renderer)
    end

    def watch_contents(*path)
      @json.dig(*path)
    end
  end
end
