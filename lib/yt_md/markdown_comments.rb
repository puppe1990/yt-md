# frozen_string_literal: true

module YtMd
  # Renders comment threads as markdown under a Portuguese header.
  class MarkdownComments
    def initialize(thread:, sort: :top)
      @thread = thread
      @sort = sort
    end

    def to_s
      [heading, "", source_lines, "", body, ""].flatten.join("\n")
    end

    private

    def heading
      "# #{@thread.meta.fetch(:title)} — comentários"
    end

    def source_lines
      [
        "- Canal: #{@thread.meta.fetch(:channel)}",
        "- Fonte: #{@thread.meta.fetch(:url)}",
        "- Ordem: #{sort_label}",
        "- Comentários: #{count_label}"
      ]
    end

    def sort_label
      @sort == :newest ? "mais recentes" : "principais"
    end

    def count_label
      declared = @thread.declared_count
      collected = @thread.comments.length
      return "#{collected} (YouTube informa #{declared})" if declared && @thread.truncated

      collected.to_s
    end

    def body
      @thread.comments.map { |comment| comment_block(comment).join("\n") }.join("\n\n")
    end

    def comment_block(comment)
      lines = ["### #{byline(comment)}", "", comment.text.to_s]
      comment.replies.each do |reply|
        lines << ""
        lines << "**#{byline(reply)}**"
        lines << ""
        lines << quote(reply.text.to_s)
      end
      lines
    end

    def byline(comment)
      parts = [comment.author]
      parts << "· canal" if comment.creator
      parts << "· #{comment.published}" if comment.published
      parts << "· #{comment.likes} likes" if comment.likes
      parts.join(" ")
    end

    def quote(text)
      text.lines.map { |line| "> #{line.chomp}" }.join("\n")
    end
  end
end
