# frozen_string_literal: true

module YtMd
  # A YouTube channel handle (@a16z) or UC browse id.
  class ChannelRef
    HANDLE = /@[A-Za-z0-9._-]+/
    CHANNEL_ID = /UC[A-Za-z0-9_-]{22}/

    class Invalid < ArgumentError; end

    attr_reader :handle, :browse_id, :url

    def self.parse(input)
      new(input).parse
    end

    def self.match?(input)
      parse(input)
      true
    rescue Invalid
      false
    end

    def initialize(input)
      @input = input.to_s.strip
    end

    def parse
      return from_channel_id if @input.match(/\A(#{CHANNEL_ID})\z/) ||
                                @input.match(%r{youtube\.com/channel/(#{CHANNEL_ID})})
      return from_handle if @input.match(HANDLE)

      raise invalid
    end

    def folder_name
      (handle || browse_id).to_s.delete_prefix("@")
    end

    private

    def from_channel_id
      @browse_id = @input.match(CHANNEL_ID)[0]
      @handle = nil
      @url = "https://www.youtube.com/channel/#{@browse_id}"
      self
    end

    def from_handle
      @handle = @input.match(HANDLE)[0]
      @browse_id = nil
      @url = "https://www.youtube.com/#{@handle}"
      self
    end

    def invalid
      Invalid.new(
        %(invalid channel: received "#{@input}", expected channel handle, /channel/ id, or UC id)
      )
    end
  end
end
