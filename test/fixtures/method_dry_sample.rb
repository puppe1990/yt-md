# frozen_string_literal: true

module DrySample
  class Left
    def pick_video(item)
      lockup = item.dig("richItemRenderer", "content", "lockupViewModel")
      return unless lockup && lockup["contentType"] == "LOCKUP_CONTENT_TYPE_VIDEO"

      video_id = lockup["contentId"].to_s
      return if video_id.empty?

      title = lockup.dig("metadata", "lockupMetadataViewModel", "title", "content").to_s
      [video_id, title]
    end
  end

  class Right
    def choose_video(row)
      model = row.dig("richItemRenderer", "content", "lockupViewModel")
      return unless model && model["contentType"] == "LOCKUP_CONTENT_TYPE_VIDEO"

      content_id = model["contentId"].to_s
      return if content_id.empty?

      heading = model.dig("metadata", "lockupMetadataViewModel", "title", "content").to_s
      [content_id, heading]
    end
  end

  class Other
    def sum_lengths(items)
      total = 0
      items.each { |item| total += item.length }
      total
    end
  end
end
