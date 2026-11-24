# frozen_string_literal: true

module YtMd
  # Player metadata plus parsed json3 cues for one video.
  Transcript = Struct.new(:meta, :cues, keyword_init: true)

  # Loads Innertube player + json3 timedtext for one video id.
  class TranscriptFetch
    def initialize(http:)
      @http = http
    end

    def call(video_id, language:, timedtext: nil)
      payload = PlayerPayload.parse(
        @http.post(Innertube::PLAYER_URL, json: Innertube::ANDROID.merge("videoId" => video_id))
      )
      track = CaptionTrack.pick(payload.tracks, language: language)
      body = timedtext || @http.get(track.timedtext_url)
      cues = CaptionCues.parse(body)
      Transcript.new(meta: meta_from(payload, track), cues: cues)
    end

    private

    def meta_from(payload, track)
      {
        title: payload.title,
        channel: payload.channel,
        url: "https://www.youtube.com/watch?v=#{payload.video_id}",
        language: track.language,
        kind: track.kind,
        duration_seconds: payload.duration_seconds
      }
    end
  end
end
