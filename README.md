# yt-md

Ruby CLI that pulls the captions YouTube already publishes and writes markdown.
One video becomes one file; one channel becomes a folder with a `.md` per video
from the Videos tab.

[![CI](https://github.com/puppe1990/yt-md/actions/workflows/ci.yml/badge.svg)](https://github.com/puppe1990/yt-md/actions/workflows/ci.yml)

It talks to Innertube (`youtubei/v1/player` ANDROID + `timedtext` json3) and
runs on the stdlib (`net/http`, `json`, `optparse`).

## Install

Ruby 3.4 or 4.x.

```bash
git clone https://github.com/puppe1990/yt-md.git
cd yt-md
ruby yt_md.rb --help
```

`bundle` and `npm` only exist for tests, lint and the pre-commit hook.

## One video

Accepts an 11-character id, `watch`, `youtu.be`, Shorts, embed and live URLs.

```bash
ruby yt_md.rb https://www.youtube.com/watch?v=TtOoLanFzGw
ruby yt_md.rb TtOoLanFzGw -o interview.md --timestamps
ruby yt_md.rb https://youtu.be/TtOoLanFzGw --lang pt
ruby yt_md.rb TtOoLanFzGw --json3 captions.json3 -o interview.md
```

Without `-o`, the markdown goes to stdout.

## Comments

`--comments` swaps the transcript for the video's public comments. The markdown
carries a header, one `###` per thread, and replies quoted under their parent.

```bash
ruby yt_md.rb https://www.youtube.com/watch?v=rRI0iH-cpjg --comments
ruby yt_md.rb rRI0iH-cpjg --comments --sort newest -o comments.md
ruby yt_md.rb rRI0iH-cpjg --comments --limit 50
```

`--sort` takes `top` (default) or `newest`. `--limit` stops early; the header
then shows the total YouTube declares. Without `--limit` the CLI pages to the
last thread and fetches every thread's replies.

With `--json` the output becomes a single document with the header metrics and a
`data` list of threads carrying nested `replies`:

```bash
ruby yt_md.rb rRI0iH-cpjg --comments --json -o comments.json
```

```json
{
  "url": "https://www.youtube.com/watch?v=rRI0iH-cpjg",
  "videoId": "rRI0iH-cpjg",
  "title": "It's Not Fun, But It Will Make You Rich",
  "collectedAt": "2026-11-27T15:08:10.557Z",
  "mode": "api",
  "truncated": false,
  "totalThreads": 220,
  "totalReplies": 80,
  "visibleCommentCount": null,
  "expectedCommentCount": 351,
  "data": [
    {
      "index": 1,
      "commentId": "Ugz6OBPklGBWz8zjC5d4AaABAg",
      "author": "@AlexHormozi",
      "authorChannelUrl": "https://www.youtube.com/@AlexHormozi",
      "content": "Download your free scaling roadmap here: …",
      "published": "há 6 dias",
      "likes": "19",
      "isReply": false,
      "repliesCount": 9,
      "replies": [
        {
          "commentId": "Ugz6OBPklGBWz8zjC5d4AaABAg.AdSGUO94V7P…",
          "author": "@mickeypitt",
          "authorChannelUrl": "https://www.youtube.com/@mickeypitt",
          "content": "Alex, welcome to the OODA Loop.",
          "published": "há 4 dias",
          "likes": "1",
          "parentCommentId": "Ugz6OBPklGBWz8zjC5d4AaABAg",
          "parentAuthor": "@AlexHormozi",
          "parentContentPreview": "Download your free scaling roadmap here: …",
          "replyIndex": 1,
          "isReply": true
        }
      ]
    }
  ]
}
```

Counters stay strings (`"19"`, `"2,4 mil"`) because YouTube localizes big
numbers. A comment with no likes comes back `"0"`; `expectedCommentCount` only
becomes a number when the label is purely numeric. `parentContentPreview`
flattens whitespace and cuts at 179 UTF-16 units with `...`.

`published` comes back in the request locale, so the values depend on
`Innertube::WEB_COMMENTS`: `"6 days ago"` with `hl=en`, `"há 6 dias"` with
`hl=pt`.

The markdown form:

```markdown
# É chato, mas vai te deixar rico — comentários

- Canal: Alex Hormozi
- Fonte: https://www.youtube.com/watch?v=rRI0iH-cpjg
- Ordem: principais
- Comentários: 220

### @AlexHormozi · canal · há 6 dias · 19 likes

Download your free scaling roadmap here: …

**@mickeypitt · há 4 dias · 1 likes**

> Alex, welcome to the OODA Loop.
```

## One channel

Accepts `@handle`, a `youtube.com/@handle` URL, `/channel/UCxx` and the `UC…` id.

```bash
ruby yt_md.rb @a16z -o ./a16z --limit 10
ruby yt_md.rb https://www.youtube.com/@a16z -o ~/Downloads/a16z-transcripts --sleep 0.4
```

Lists the Videos tab (Innertube WEB continuations), creates the `-o` directory
(or the handle when `-o` is missing) and writes `{videoId}.md`. A file that
already exists is skipped, and so is a video without a track in `--lang`, with a
`skip` line in the log.

```
listed 10 videos from a16z
ok 1/10 TtOoLanFzGw
skip 2/10 xxxxxxxxxxxx exists
skip 3/10 yyyyyyyyyyy no captionTracks in player payload
```

Run it again in the same directory to resume where it stopped. `--sleep` pauses
between one player call and the next.

## Flags

| Flag              | Default         | Effect                                             |
| ----------------- | --------------- | -------------------------------------------------- |
| `-o`, `--output`  | stdout / handle | Video file, or channel directory                   |
| `--lang LANG`     | `en`            | Caption language. Prefers human; falls back to ASR |
| `--timestamps`    | off             | Prefixes each cue with a clock (`**00:09**`)       |
| `--json3 FILE`    | live            | Uses a captured json3 timedtext instead of the GET |
| `--comments`      | off             | Video comments instead of the transcript           |
| `--json`          | off             | Comments as JSON instead of markdown               |
| `--sort ORDER`    | `top`           | `top` or `newest`                                  |
| `--limit N`       | whole tab       | Stops pagination after N videos or comments        |
| `--sleep SECONDS` | `0`             | Pause between channel videos                       |

## Markdown

The transcript header and the comment labels are written in Portuguese; the
prose of this README is English. `[Music]`, `[Applause]` and `[Laughter]` cues
are dropped.

```markdown
# Why AI Has DHH Working 16-Hour Days

- Canal: a16z
- Fonte: https://www.youtube.com/watch?v=TtOoLanFzGw
- Faixa: en (ASR)
- Duração: 52 min

MacOS and Windows are just unfit for the age of agents. …
```

With `--timestamps`:

```markdown
**00:00** Mac OS

**00:09** Linux
```

`Faixa: pt` is a human track; `Faixa: en (ASR)` is the automatic one.

## How it fetches

1. Video: `POST /youtubei/v1/player` (ANDROID client) → `captionTracks` → GET
   timedtext with `fmt=json3` (the player usually hands back `srv3`; the CLI
   swaps it).
2. Channel: `POST /youtubei/v1/navigation/resolve_url` turns the `@handle` into a
   `UC…` browse id, then `POST /youtubei/v1/browse` on the Videos tab until the
   continuation runs out or `--limit` is hit.
3. Comments: `POST /youtubei/v1/next` (WEB client) on the `videoId` returns the
   `engagement-panel-comments-section` panel and the sort token. Later pages go
   through `next` with a `continuation`. Each comment's text is not on the item:
   it arrives in `frameworkUpdates.entityBatchUpdate`, matched by `commentKey`.
   Long threads end with a "show more replies" button whose token lives on
   `continuationItemRenderer.button.buttonRenderer.command`.

HTTP is injectable. The tests never hit YouTube.

## Tests

```bash
bin/setup               # bundle install + npm ci
bundle exec rake test   # suite
bin/crap --threshold 10 # CRAP < 10 on lib/
bin/dry --threshold 0.8 # structural duplication on lib/
npm run ci              # Prettier + ESLint + RuboCop + suite + CRAP + dry
```

The Husky pre-commit hook runs lint-staged and the suite.

## License

MIT. See [LICENSE](LICENSE).
