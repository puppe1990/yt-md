# frozen_string_literal: true

module YtMd
  # Public watch metadata plus the comments threads of one video.
  CommentThread = Struct.new(:meta, :comments, :declared_count, :truncated, keyword_init: true)

  # Pages youtubei/v1/next: comments panel, top-level comments, then replies.
  class CommentFetch
    def initialize(http:)
      @http = http
    end

    def call(video_id, sort: :top, limit: nil)
      panel = CommentPanel.new(watch_page(video_id), video_id: video_id).parse
      token = panel.sort_token(sort)
      raise CommentPanel::Disabled, missing_token_message(video_id) unless token

      comments, truncated = collect(token, limit)
      CommentThread.new(
        meta: meta_from(panel, video_id),
        comments: comments,
        declared_count: panel.declared_count,
        truncated: truncated
      )
    end

    private

    def missing_token_message(video_id)
      %(comments unavailable for #{video_id}: received no sort token, expected Top or Newest)
    end

    # The pinned comment appears twice: once at the top of page 1 and again in
    # its chronological slot near the end. Collected ids are tracked so the
    # second copy does not inflate the totals.
    def collect(token, limit)
      comments = []
      seen_tokens = {}
      seen_ids = {}
      while token && !seen_tokens[token]
        seen_tokens[token] = true
        page = CommentPage.new(next_page("continuation" => token))
        page.entries.each do |entry|
          next if seen_ids[entry.comment.id]

          seen_ids[entry.comment.id] = true
          comments << entry.comment
          return [comments, true] if limit && comments.length >= limit

          fetch_replies(entry)
        end
        token = page.next_token
      end
      [comments, false]
    end

    # Replies paginate on their own token; a thread shows only the first ones
    # until the "view replies" continuation is followed. Long threads then end
    # with a "show more replies" button that carries yet another token.
    def fetch_replies(entry)
      token = entry.reply_token
      seen_tokens = {}
      seen_ids = {}
      while token && !seen_tokens[token]
        seen_tokens[token] = true
        page = CommentPage.new(next_page("continuation" => token))
        page.entries.each do |reply|
          next if seen_ids[reply.comment.id]

          seen_ids[reply.comment.id] = true
          entry.comment.replies << reply.comment
        end
        token = page.next_token || page.more_replies_token
      end
    end

    def meta_from(panel, video_id)
      {
        video_id: video_id,
        title: panel.title,
        channel: panel.channel,
        url: "https://www.youtube.com/watch?v=#{video_id}",
        declared_count: panel.declared_count
      }
    end

    def next_page(identity)
      JSON.parse(post(Innertube::WEB_COMMENTS, identity))
    end

    # The watch page is requested in English so the title keeps the name the
    # creator published instead of a YouTube localized translation. The sort
    # token it yields still works with the Portuguese continuation requests,
    # which is what keeps "há 6 dias" in the dates.
    def watch_page(video_id)
      JSON.parse(post(Innertube::WEB, "videoId" => video_id))
    end

    def post(context, identity)
      @http.post(Innertube::NEXT_URL, json: context.merge(identity))
    end
  end
end
