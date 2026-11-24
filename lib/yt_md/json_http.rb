# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module YtMd
  # Tiny Net::HTTP wrapper so tests inject a fake instead of hitting YouTube.
  class JsonHttp
    USER_AGENT = "com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip"

    def get(url, user_agent: USER_AGENT)
      request(url, Net::HTTP::Get.new(URI.parse(url)), user_agent: user_agent)
    end

    def post(url, json:, user_agent: USER_AGENT)
      uri = URI.parse(url)
      request_obj = Net::HTTP::Post.new(uri)
      request_obj["Content-Type"] = "application/json"
      request_obj.body = JSON.generate(json)
      request(url, request_obj, user_agent: user_agent)
    end

    private

    def request(url, request_obj, user_agent: USER_AGENT)
      uri = URI.parse(url)
      request_obj["User-Agent"] = user_agent
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request_obj)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise ArgumentError, %(HTTP #{response.code} for #{uri.path}: received "#{response.body.to_s[0, 80]}")
      end

      response.body
    end
  end
end
