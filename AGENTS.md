# AGENTS.md

YouTube watch URL or id → markdown transcript. Innertube ANDROID player + json3 timedtext. Public CLI, no Network Listener token.

## Commands

- `bundle exec rake test` — full suite, one command, no live YouTube
- `ruby yt_md.rb URL [-o FILE] [--lang en] [--timestamps] [--json3 FILE]` — live fetch

## Layout

- `yt_md.rb` — thin CLI entry (parse errors → stderr, exit 1)
- `lib/yt_md.rb` — requires every library file
- `lib/yt_md/*.rb` — one responsibility per file, mirrored by `test/yt_md/*_test.rb`
- `test/test_helper.rb` — `YtMdTest` with Faker helpers and `json3_body`

## Rules

- HTTP is injected. Unit tests never hit YouTube.
- Prefer a human caption track over ASR for `--lang`. Default language is `en`.
- Errors include the received value and the expected shape (`VideoId::Invalid`, `CaptionTrack::Missing`, `PlayerPayload::Unplayable`, `CaptionCues::Invalid`).
- Markdown header labels stay Portuguese. Identifiers stay English.
- This is not AssemblyAI (`transcrever`) and not the YT Resumos site.
