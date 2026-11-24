# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module YtMd
  # Tiny Net::HTTP wrapper so tests inject a fake instead of hitting YouTube.
  class JsonHttp
    def initialize(starter: nil)
      @starter = starter || default_starter
    end

    def get(url, user_agent: Innertube::ANDROID_UA)
      request(url, Net::HTTP::Get.new(URI.parse(url)), user_agent: user_agent)
    end

    def post(url, json:, user_agent: Innertube::ANDROID_UA)
      uri = URI.parse(url)
      request_obj = Net::HTTP::Post.new(uri)
      request_obj["Content-Type"] = "application/json"
      request_obj.body = JSON.generate(json)
      request(url, request_obj, user_agent: user_agent)
    end

    private

    def request(url, request_obj, user_agent: Innertube::ANDROID_UA)
      uri = URI.parse(url)
      request_obj["User-Agent"] = user_agent
      response = @starter.call(uri) { |http| http.request(request_obj) }
      unless response.is_a?(Net::HTTPSuccess)
        raise ArgumentError, %(HTTP #{response.code} for #{uri.path}: received "#{response.body.to_s[0, 80]}")
      end

      response.body
    end

    def default_starter
      lambda do |uri, &block|
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", &block)
      end
    end
  end
end
