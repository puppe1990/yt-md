# frozen_string_literal: true

require "json"
require "time"

module YtMd
  # Renders comment threads as JSON, matching the capture shape scripts expect.
  #
  # Counter strings stay verbatim ("19", never 19) because YouTube localizes
  # big numbers ("2,4 mil") and the caller may want the original label.
  class JsonComments
    MODE = "api"
    PREVIEW_LIMIT = 179
    # JavaScript's \s, which includes NBSP and the Unicode spaces YouTube emits.
    WHITESPACE = /[[:space:]\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+/

    def initialize(thread:, sort: :top, now: nil)
      @thread = thread
      @sort = sort
      @now = now || Time.now
    end

    def to_s
      "#{JSON.pretty_generate(document)}\n"
    end

    private

    def document
      {
        "url" => @thread.meta.fetch(:url),
        "videoId" => @thread.meta.fetch(:video_id),
        "title" => @thread.meta.fetch(:title),
        "collectedAt" => @now.utc.iso8601(3),
        "mode" => MODE,
        "truncated" => @thread.truncated == true,
        "totalThreads" => @thread.comments.length,
        "totalReplies" => @thread.comments.sum { |comment| comment.replies.length },
        "visibleCommentCount" => nil,
        "expectedCommentCount" => expected_count,
        "data" => @thread.comments.each_with_index.map { |comment, index| thread_hash(comment, index + 1) }
      }
    end

    # The panel reports a localized label; keep it as a number when it is one.
    def expected_count
      raw = @thread.declared_count.to_s.strip
      raw.match?(/\A\d+\z/) ? Integer(raw) : raw
    end

    def thread_hash(comment, index)
      {
        "index" => index,
        "commentId" => comment.id,
        "author" => comment.author,
        "authorChannelUrl" => channel_url(comment),
        "content" => flatten(comment.text.to_s),
        "published" => comment.published,
        "likes" => like_count(comment.likes),
        "isReply" => false,
        "repliesCount" => comment.replies.length,
        "replies" => comment.replies.each_with_index.map { |reply, position| reply_hash(reply, comment, position + 1) }
      }
    end

    def reply_hash(reply, parent, reply_index)
      {
        "commentId" => reply.id,
        "author" => reply.author,
        "authorChannelUrl" => channel_url(reply),
        "content" => flatten(reply.text.to_s),
        "published" => reply.published,
        "likes" => like_count(reply.likes),
        "parentCommentId" => parent.id,
        "parentAuthor" => parent.author,
        "parentContentPreview" => preview(flatten(parent.text.to_s)),
        "replyIndex" => reply_index,
        "isReply" => true
      }
    end

    # Innertube percent-encodes non-ASCII handles in canonicalBaseUrl; the
    # capture builds the URL from the handle itself, so "ü" stays "ü".
    def channel_url(comment)
      handle = comment.author.to_s
      return nil if handle.empty?

      "https://www.youtube.com/#{handle}"
    end

    # Unliked comments arrive with a blank counter; the capture stores "0".
    def like_count(likes)
      likes.to_s.strip.empty? ? "0" : likes
    end

    # Comment bodies carry NBSP and soft wraps; the capture flattens runs of
    # whitespace (NBSP included) into one space and trims the ends.
    def flatten(text)
      text.gsub(WHITESPACE, " ").strip
    end

    # The caller flattens first, so this only cuts: 179 UTF-16 units (what JS
    # length counts, so emoji count as two) and an ellipsis.
    def preview(text)
      return text if utf16_length(text) <= PREVIEW_LIMIT

      "#{utf16_slice(text, PREVIEW_LIMIT)}..."
    end

    def utf16_length(text)
      text.encode("UTF-16LE").bytesize / 2
    end

    def utf16_slice(text, limit)
      bytes = text.encode("UTF-16LE").byteslice(0, limit * 2)
      bytes.force_encoding("UTF-16LE").encode("UTF-8", invalid: :replace, undef: :replace).delete("\uFFFD")
    end
  end
end
