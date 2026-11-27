# yt-md

YouTube URL or id → markdown transcript. Innertube ANDROID player + json3
timedtext. Channel `@handle` → Videos tab, one `.md` per video. Public CLI.

## Caveats

- Player: ANDROID `youtubei/v1/player`. WEB player is out.
- Timedtext: force `fmt=json3`. Player `baseUrl` ships `srv3` XML; CaptionCues
  only parses json3.
- Channel list: WEB browse. ANDROID browse of the Videos tab returns HTTP 400.
- `@handle` as browseId returns HTTP 400. `resolve_url` first, then UC id.
- Videos tab params `EgZ2aWRlb3PyBgQKAjoA`. Shorts/Live on the channel header
  are a different tab.
- Captions come from Innertube `captionTracks`. Do not call AssemblyAI
  (`transcrever`) or the YT Resumos app. No Network Listener token.
- Comments: `youtubei/v1/next` (WEB) with no cookie returns public comments.
  The token is not in the panel body — it sits on the header's
  `sortFilterSubMenuRenderer.subMenuItems[*].serviceEndpoint`. The menu is
  localized ("Top"/"Principais"), so read it by position: index 0 top, 1 newest.
- Comment items carry only a `commentViewModel` key. Text, author, `isCreator`
  and like counts live in `frameworkUpdates.entityBatchUpdate.mutations`,
  matched by `entityKey == commentKey`. Blank counters arrive as `" "`.
- Replies page on their own token under
  `commentThreadRenderer.replies.commentRepliesRenderer.contents[0]`. Do not
  read `contents[0]` as a fixed index with `dig` — `dig` rejects integer paths,
  walk the array.
- Long reply threads end with a "Mostrar mais respostas" button. Its token is
  NOT on `continuationEndpoint`: it hangs off
  `continuationItemRenderer.button.buttonRenderer.command.continuationCommand`.
  Missing it silently truncates threads (a 379-comment video came back short by
  26 replies), so `CommentPage#more_replies_token` must be followed.
- Comments request `hl=pt` (`Innertube::WEB_COMMENTS`) so dates read "há 6 dias";
  captions stay `hl=en` (`Innertube::WEB`) to keep the `--lang` codes stable.
- The comments watch page is fetched with `hl=en` (`Innertube::WEB`) so the
  title stays the original ("It's Not Fun") instead of YouTube's pt translation
  ("É chato"). The sort token from that page still works with the pt
  continuations, so dates stay localized.
- Collab videos replace `owner.title` with `owner.attributedTitle.content`
  ("Kelvin Cleto e Rodrigo Lopes"); `CommentPanel#channel_text` reads both.
- `--json` mirrors the capture shape scripts already consume: same key order,
  `likes` as a string (`"0"` when blank), content flattened with JS `\s`
  (NBSP included), `authorChannelUrl` built from the handle (Innertube
  percent-encodes "ü"), and `parentContentPreview` cut at 179 UTF-16 units.
- Markdown labels stay Portuguese (`Canal` / `Fonte` / `Faixa` / `Duração`).
  Identifiers stay English.
- Default `--lang en`. Prefer a human track over ASR.

## Commands

```bash
bin/setup                 # bundle install + npm ci
bundle exec rake test     # suite, no live YouTube
bin/crap --threshold 10   # CRAP < 10 on lib/ (needs coverage from the suite)
bin/dry --threshold 0.8   # structural dups in lib/
bin/mutate                # &&/|| swap mutants in lib/
npm run ci                # Prettier + ESLint + RuboCop + suite + crap + dry
ruby yt_md.rb URL [-o FILE] [--lang en] [--timestamps] [--json3 FILE] [--limit N]
ruby yt_md.rb URL --comments [--sort top|newest] [-o FILE] [--limit N]
ruby yt_md.rb URL --comments --json [-o FILE]
ruby yt_md.rb @handle -o DIR [--limit N] [--sleep 0.4]
```

## Code style

- Functions: 4-20 lines. Files: under 500, target 200-300.
- One thing per function, one responsibility per module (SRP).
- Names: specific and unique. Avoid `data`, `handler`, `Manager`.
  Prefer names that return <5 grep hits.
- Ruby keyword args are the public contract.
- No duplication. Early returns. Max 2 indentation levels in control flow.
- Exception messages include the received value and expected shape
  (`VideoId::Invalid`, `CaptionTrack::Missing`, `PlayerPayload::Unplayable`,
  `CaptionCues::Invalid`, `ChannelBrowse::Missing`).

## Comments

- Keep intent/provenance. Do not strip them on refactor.
- Write WHY, not WHAT. Innertube constraints live in `lib/yt_md/innertube.rb`.
- Skip comments that restate the next line.

## Tests

- One command: `bundle exec rake test`. Quality gate: `npm run ci`.
- Every new function gets a test. Bugfix gets a regression test.
- HTTP is injected. Named fake: `FakeInnertube`. Factories on `YtMdTest`
  (`player_payload_json`, `videos_tab_lockup`, `json3_body`). No live YouTube.
- Faker (`Faker::Alphanumeric`, `Faker::Book.title`). F.I.R.S.T.
- Mirror: `lib/yt_md/foo.rb` ↔ `test/yt_md/foo_test.rb`.

## Dependencies

- Inject HTTP via `Cli.new(http:)`, `TranscriptFetch.new(http:)`,
  `ChannelBrowse.new(http:)`. `JsonHttp` is the production Net::HTTP wrapper.
- Innertube URLs, clients, and UAs live only in `YtMd::Innertube`.

## Structure

```
yt_md.rb              CLI entry (parse errors → stderr, exit 1)
lib/yt_md.rb          requires
lib/yt_md/innertube.rb
lib/yt_md/*.rb        one responsibility each
  comment_panel.rb    watch next → panel, title, channel, sort tokens
  comment_page.rb     one continuation page → Comment + reply token
  comment_fetch.rb    pages replies and threads; CommentThread meta
  markdown_comments.rb  comment threads → markdown
  json_comments.rb    comment threads → capture-shaped JSON
test/test_helper.rb   YtMdTest + factories
test/yt_md/fake_innertube.rb
test/yt_md/*_test.rb
tools/method_crap.rb  Ruby CRAP lever
tools/method_dry.rb   Ruby dryer lever
tools/method_mutate.rb &&/|| mutants
bin/crap bin/dry bin/mutate
```

## Formatting

- RuboCop (`bundle exec rubocop -A`) + Prettier + ESLint. Do not discuss style.
- `npm run ci` is the quality gate (format, lint, tests, CRAP, dry).
- Uncle Bob's crapper/dryer/mutator do not parse Ruby. Levers: `bin/crap`,
  `bin/dry`, `bin/mutate` (`tools/method_*.rb`). CRAP = CC² × (1 − cov)³ + CC.

## Logging

- Plain text on stdout for the CLI (`listed`, `ok`, `skip`). No JSON logger.

## Defensive programming

- Channel dump: `--sleep` between player fetches. Resume by skipping existing
  `{videoId}.md`. Missing captions log `skip` and continue.
- Do not add retries, 429 handling, circuit breakers, or extra rate limits.
