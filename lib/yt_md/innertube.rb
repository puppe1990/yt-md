# frozen_string_literal: true

module YtMd
  # Innertube clients and endpoints in one place.
  #
  # ANDROID player returns captionTracks; WEB player is out for this CLI.
  # ANDROID browse of the Videos tab returns HTTP 400, so listing uses WEB.
  # browseId "@handle" also 400s — resolve_url first, then the UC id.
  module Innertube
    PLAYER_URL = "https://www.youtube.com/youtubei/v1/player?prettyPrint=false"
    BROWSE_URL = "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false"
    RESOLVE_URL = "https://www.youtube.com/youtubei/v1/navigation/resolve_url?prettyPrint=false"
    VIDEOS_TAB = "EgZ2aWRlb3PyBgQKAjoA"
    ANDROID_UA = "com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip"
    WEB_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
             "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    ANDROID = {
      "context" => {
        "client" => {
          "clientName" => "ANDROID",
          "clientVersion" => "20.10.38",
          "hl" => "en",
          "gl" => "US"
        }
      }
    }.freeze
    WEB = {
      "context" => {
        "client" => {
          "clientName" => "WEB",
          "clientVersion" => "2.20251120.01.00",
          "hl" => "en",
          "gl" => "US"
        }
      }
    }.freeze
  end
end
