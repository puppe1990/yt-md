# frozen_string_literal: true

module YtMd
  # One public comment. `replies` holds the nested level-1 comments.
  Comment = Struct.new(:id, :author, :creator, :text, :published, :likes, :pinned, :replies,
                       keyword_init: true)

  # Decodes one comments continuation page from youtubei/v1/next.
  #
  # Each thread item carries only a commentViewModel key; the text, author and
  # like counts arrive separately in frameworkUpdates.entityBatchUpdate.
  class CommentPage
    Entry = Struct.new(:comment, :reply_token, keyword_init: true)

    NEXT_TOKEN = %w[continuationItemRenderer continuationEndpoint continuationCommand token].freeze
    REPLY_PATH = %w[replies commentRepliesRenderer contents].freeze
    REPLY_TOKEN = %w[continuationItemRenderer continuationEndpoint continuationCommand token].freeze

    def initialize(json)
      @json = json
      @entities = entities
    end

    def entries
      page_items.filter_map { |item| entry_from(item) }
    end

    def next_token
      page_items.filter_map { |item| item.dig(*NEXT_TOKEN) }.first
    end

    # "Mostrar mais respostas" ends a reply page: the token hangs off the
    # button's command, not off continuationEndpoint like the first page.
    def more_replies_token
      page_items.filter_map { |item| more_replies_token_of(item) }.first
    end

    private

    def more_replies_token_of(item)
      button = item.dig("continuationItemRenderer", "button", "buttonRenderer")
      return unless button

      button.dig("command", "continuationCommand", "token") ||
        button.dig("navigationEndpoint", "continuationCommand", "token")
    end

    def entry_from(item)
      view = view_model(item)
      return unless view

      Entry.new(comment: comment_from(view), reply_token: reply_token(item))
    end

    # "View replies" is a one-item continuation list, not always present.
    def reply_token(item)
      thread = item["commentThreadRenderer"]
      return unless thread

      contents = thread.dig(*REPLY_PATH) || []
      contents.filter_map { |entry| entry.dig(*REPLY_TOKEN) }.first
    end

    def view_model(item)
      if item["commentThreadRenderer"]
        item.dig("commentThreadRenderer", "commentViewModel", "commentViewModel")
      else
        item["commentViewModel"]
      end
    end

    def comment_from(view)
      payload = @entities[view["commentKey"]] || {}
      properties = payload["properties"] || {}
      author = payload["author"] || {}
      Comment.new(
        id: properties["commentId"] || view["commentId"],
        author: author["displayName"],
        creator: author["isCreator"] == true,
        text: properties.dig("content", "content").to_s,
        published: properties["publishedTime"],
        likes: count(payload.dig("toolbar", "likeCountNotliked") || payload.dig("toolbar", "likeCountLiked")),
        pinned: view["pinnedText"],
        replies: []
      )
    end

    # YouTube pads empty counters with a single space.
    def count(value)
      text = value.to_s.strip
      text.empty? ? nil : text
    end

    def entities
      mutations = @json.dig("frameworkUpdates", "entityBatchUpdate", "mutations") || []
      mutations.to_h do |mutation|
        [mutation["entityKey"], mutation.dig("payload", "commentEntityPayload")]
      end.compact
    end

    def page_items
      @page_items ||= endpoints.flat_map { |endpoint| items_of(endpoint) }
    end

    def endpoints
      @json["onResponseReceivedEndpoints"] || []
    end

    def items_of(endpoint)
      endpoint.dig("reloadContinuationItemsCommand", "continuationItems") ||
        endpoint.dig("appendContinuationItemsAction", "continuationItems") || []
    end
  end
end
